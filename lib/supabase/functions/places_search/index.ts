// Supabase Edge Function: places_search
// Uses Google Places API (new v1) to search nearby services and return enriched details.

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

type PlacesSearchRequest = {
  userLat?: number;
  userLng?: number;
  preferredLocationText?: string;
  query?: string;
  type?: string;
  includeGoogleTypes?: string[];
  maxDistanceMiles?: number;
  openNow?: boolean;
  minRating?: number;
  minUserRatings?: number;
  language?: string;
  region?: string;
  sortByRating?: boolean;
  mode?: string;
  /**
   * Hint to Google about how to rank results.
   * - "relevance" (default): best match for query
   * - "distance": closest first
   */
  rankPreference?: "relevance" | "distance";
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

function toNumber(v: unknown): number | null {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string") {
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

function haversineMiles(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const R = 3958.8; // miles
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function clamp(n: number, min: number, max: number) {
  return Math.max(min, Math.min(max, n));
}

function normalizeTextQuery(req: PlacesSearchRequest): string {
  // Prefer an explicit query; fallback to a type-ish phrase.
  const q = (req.query ?? "").trim();
  if (q.length > 0) return q;
  const t = (req.type ?? "").trim();
  return t.length > 0 ? t : "disability services";
}

function pickIncludedType(req: PlacesSearchRequest): string | undefined {
  // Google Places v1 uses a single includedType. If a list is provided, we pick the first.
  const list = Array.isArray(req.includeGoogleTypes) ? req.includeGoogleTypes.filter((s) => typeof s === "string" && s.trim().length > 0) : [];
  if (list.length > 0) return list[0].trim();
  // Some callers pass a loose "type" like therapist/center; we avoid sending those as includedType.
  const t = (req.type ?? "").trim().toLowerCase();
  if (t === "hospital") return "hospital";
  if (t === "pharmacy") return "pharmacy";
  return undefined;
}

function mapPriceLevel(v: unknown): number | null {
  // Google v1 priceLevel enum: PRICE_LEVEL_UNSPECIFIED, PRICE_LEVEL_FREE, PRICE_LEVEL_INEXPENSIVE, PRICE_LEVEL_MODERATE, PRICE_LEVEL_EXPENSIVE, PRICE_LEVEL_VERY_EXPENSIVE
  if (typeof v !== "string") return null;
  switch (v) {
    case "PRICE_LEVEL_FREE":
      return 0;
    case "PRICE_LEVEL_INEXPENSIVE":
      return 1;
    case "PRICE_LEVEL_MODERATE":
      return 2;
    case "PRICE_LEVEL_EXPENSIVE":
      return 3;
    case "PRICE_LEVEL_VERY_EXPENSIVE":
      return 4;
    default:
      return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return jsonResponse({ error: { message: "Method not allowed" } }, 405);

  const apiKey = Deno.env.get("GOOGLE_PLACES_API_KEY") ?? Deno.env.get("GOOGLE_MAPS_API_KEY");
  if (!apiKey) return jsonResponse({ error: { message: "Missing GOOGLE_PLACES_API_KEY secret" } }, 500);

  let body: PlacesSearchRequest;
  try {
    body = (await req.json()) as PlacesSearchRequest;
  } catch {
    return jsonResponse({ error: { message: "Invalid JSON body" } }, 400);
  }

  const userLat = toNumber(body.userLat);
  const userLng = toNumber(body.userLng);
  const preferredLocationText = typeof body.preferredLocationText === "string" ? body.preferredLocationText.trim() : "";
  const hasCoords = userLat != null && userLng != null;
  if (!hasCoords && preferredLocationText.length === 0) {
    return jsonResponse({ error: { message: "Provide userLat/userLng or preferredLocationText" } }, 400);
  }

  const maxMiles = clamp(toNumber(body.maxDistanceMiles) ?? 20, 1, 100);
  const radiusMeters = Math.round(maxMiles * 1609.34);

  let textQuery = normalizeTextQuery(body);
  if (!hasCoords && preferredLocationText.length > 0) {
    // Best-effort: include the preferred location in the text query so results are anchored.
    textQuery = `${textQuery} near ${preferredLocationText}`;
  }
  const includedType = pickIncludedType(body);

  const rankPreference = (body.rankPreference ?? "relevance") === "distance" ? "DISTANCE" : "RELEVANCE";

  const payload: Record<string, unknown> = {
    textQuery,
    // Prefer relevance unless the caller explicitly wants distance-first.
    rankPreference,
    ...(typeof body.region === "string" && body.region.trim().length > 0 ? { regionCode: body.region.trim() } : {}),
    ...(typeof body.language === "string" && body.language.trim().length > 0 ? { languageCode: body.language.trim() } : {}),
    ...(hasCoords ? {
      locationBias: {
        circle: {
          center: { latitude: userLat, longitude: userLng },
          radius: radiusMeters,
        },
      },
    } : {}),
    // Smallish result set; caller will rank/score locally.
    maxResultCount: 20,
  };
  if (includedType) payload["includedType"] = includedType;
  // NOTE: openNow is only supported in some NearbySearch flows; we keep it as a hint for future.

  const fieldMask = [
    "places.id",
    "places.displayName",
    "places.formattedAddress",
    "places.location",
    "places.types",
    "places.rating",
    "places.userRatingCount",
    "places.priceLevel",
    "places.regularOpeningHours.weekdayDescriptions",
    "places.nationalPhoneNumber",
    "places.websiteUri",
    "places.googleMapsUri",
    "places.accessibilityOptions",
    "places.reviews",
  ].join(",");

  let apiRes: Response;
  let apiText = "";
  try {
    apiRes = await fetch("https://places.googleapis.com/v1/places:searchText", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": fieldMask,
        ...(body.language ? { "Accept-Language": body.language } : {}),
      },
      body: JSON.stringify(payload),
    });
    apiText = await apiRes.text();
  } catch (e) {
    return jsonResponse({ error: { message: `Google Places request failed: ${String(e)}` } }, 502);
  }

  if (!apiRes.ok) {
    return jsonResponse({ error: { message: `Google Places error (${apiRes.status})`, details: apiText.slice(0, 1000) } }, 502);
  }

  let decoded: any;
  try {
    decoded = JSON.parse(apiText);
  } catch {
    return jsonResponse({ error: { message: "Google Places returned non-JSON" } }, 502);
  }

  const places = Array.isArray(decoded?.places) ? decoded.places : [];

  const minRating = toNumber(body.minRating);
  const minUserRatings = toNumber(body.minUserRatings);

  const results = places.map((p: any) => {
    const pid = String(p?.id ?? "").trim();
    const loc = p?.location;
    const lat = toNumber(loc?.latitude);
    const lng = toNumber(loc?.longitude);
    if (!pid || lat == null || lng == null) return null;

    const distanceMiles = hasCoords ? haversineMiles(userLat!, userLng!, lat, lng) : null;

    const name = String(p?.displayName?.text ?? "").trim();
    const address = String(p?.formattedAddress ?? "").trim();
    const rating = toNumber(p?.rating) ?? 0;
    const reviewCount = Math.max(0, Math.floor(toNumber(p?.userRatingCount) ?? 0));
    const priceLevel = mapPriceLevel(p?.priceLevel);

    const hoursList = Array.isArray(p?.regularOpeningHours?.weekdayDescriptions)
      ? p.regularOpeningHours.weekdayDescriptions.map((s: any) => String(s)).filter((s: string) => s.trim().length > 0)
      : [];
    const hours = hoursList.length > 0 ? hoursList.join(" | ") : null;

    const reviews = Array.isArray(p?.reviews) ? p.reviews.slice(0, 4).map((r: any) => {
      const text = String(r?.text?.text ?? "").trim();
      return {
        rating: toNumber(r?.rating),
        text: text.length > 0 ? text.slice(0, 420) : null,
        relativePublishTimeDescription: r?.relativePublishTimeDescription ?? null,
        authorName: r?.authorAttribution?.displayName ?? null,
      };
    }) : [];

    const types = Array.isArray(p?.types) ? p.types.map((t: any) => String(t)).filter((t: string) => t.trim().length > 0) : [];

    return {
      id: `gpl_${pid}`,
      name,
      type: (body.type ?? "service"),
      address,
      location: address,
      distanceMiles,
      lat,
      lng,
      contactPhone: p?.nationalPhoneNumber ?? null,
      website: p?.websiteUri ?? null,
      googleMapsUrl: p?.googleMapsUri ?? null,
      rating,
      reviewCount,
      priceLevel,
      placeTypes: types,
      hours,
      accessibilityOptions: p?.accessibilityOptions ?? null,
      reviews,
    };
  }).filter(Boolean);

  let filtered = results as any[];
  if (hasCoords) filtered = filtered.filter((r) => (r.distanceMiles ?? 999999) <= maxMiles);
  if (minRating != null) filtered = filtered.filter((r) => (r.rating ?? 0) >= minRating);
  if (minUserRatings != null) filtered = filtered.filter((r) => (r.reviewCount ?? 0) >= minUserRatings);

  if (!hasCoords) {
    filtered.sort((a, b) => (b.rating - a.rating) || (b.reviewCount - a.reviewCount));
  } else if (body.sortByRating) {
    filtered.sort((a, b) => (b.rating - a.rating) || (a.distanceMiles - b.distanceMiles));
  } else {
    filtered.sort((a, b) => (a.distanceMiles - b.distanceMiles) || (b.rating - a.rating));
  }

  return jsonResponse({ results: filtered, meta: { maxMiles, includedType: includedType ?? null, query: textQuery, hasCoords } });
});
