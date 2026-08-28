// supabase/functions/food_search/index.ts

const CORS_HEADERS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

type FoodResult = {
  name: string;
  brand?: string;
  source: "usda" | "openfoodfacts";
  per100g?: {
    calories?: number;
    protein_g?: number;
    carbs_g?: number;
    fats_g?: number;
    fiber_g?: number;
    sugar_g?: number;
    sodium_mg?: number;
  };
};

function json(resBody: unknown, status = 200): Response {
  return new Response(JSON.stringify(resBody), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json; charset=utf-8" },
  });
}

function toNum(v: unknown): number | undefined {
  if (v === null || v === undefined) return undefined;
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : undefined;
}

function normKey(name: string, brand?: string) {
  return `${name.trim().toLowerCase()}|${(brand ?? "").trim().toLowerCase()}`;
}

async function searchOpenFoodFacts(query: string, page: number, pageSize: number): Promise<FoodResult[]> {
  const url = new URL("https://world.openfoodfacts.org/cgi/search.pl");
  url.searchParams.set("search_terms", query);
  url.searchParams.set("search_simple", "1");
  url.searchParams.set("action", "process");
  url.searchParams.set("json", "1");
  url.searchParams.set("page", String(page));
  url.searchParams.set("page_size", String(pageSize));

  const resp = await fetch(url.toString(), { headers: { "user-agent": "wellspring/1.0" } });
  if (!resp.ok) return [];
  const data = await resp.json();
  const products = Array.isArray(data?.products) ? data.products : [];

  const results: FoodResult[] = [];
  for (const p of products) {
    if (!p || typeof p !== "object") continue;
    const name = String((p as any).product_name ?? (p as any).generic_name ?? "").trim();
    if (!name) continue;

    const nutr = (p as any).nutriments;
    const nm = nutr && typeof nutr === "object" ? nutr : {};

    const kcal100 = toNum((nm as any)["energy-kcal_100g"]);
    const kcal = kcal100 !== undefined ? Math.round(kcal100) : undefined;
    const protein = toNum((nm as any)["proteins_100g"]);
    const carbs = toNum((nm as any)["carbohydrates_100g"]);
    const fats = toNum((nm as any)["fat_100g"]);
    const fiber = toNum((nm as any)["fiber_100g"]);
    const sugar = toNum((nm as any)["sugars_100g"]);
    const sodiumG = toNum((nm as any)["sodium_100g"]);
    const sodiumMg = sodiumG !== undefined ? Math.round(sodiumG * 1000) : undefined;

    // Only include results that have something useful to autofill.
    if (kcal === undefined && protein === undefined && carbs === undefined && fats === undefined) continue;

    results.push({
      name,
      brand: String((p as any).brands ?? "").trim() || undefined,
      source: "openfoodfacts",
      per100g: {
        calories: kcal,
        protein_g: protein,
        carbs_g: carbs,
        fats_g: fats,
        fiber_g: fiber,
        sugar_g: sugar,
        sodium_mg: sodiumMg,
      },
    });
  }
  return results;
}

async function searchUSDA(query: string, limit: number): Promise<FoodResult[]> {
  const apiKey = Deno.env.get("USDA_API_KEY") ?? "";
  if (!apiKey) return [];

  const url = new URL("https://api.nal.usda.gov/fdc/v1/foods/search");
  url.searchParams.set("api_key", apiKey);
  url.searchParams.set("query", query);
  url.searchParams.set("pageSize", String(Math.min(Math.max(limit, 1), 200)));
  url.searchParams.set("dataType", "Branded,SR Legacy");

  const resp = await fetch(url.toString());
  if (!resp.ok) return [];
  const data = await resp.json();
  const foods = Array.isArray(data?.foods) ? data.foods : [];

  const results: FoodResult[] = [];
  for (const item of foods) {
    if (!item || typeof item !== "object") continue;
    const name = String((item as any).description ?? "").trim();
    if (!name) continue;

    const brand = String((item as any).brandOwner ?? (item as any).brandName ?? "USDA").trim();
    const nutrients = Array.isArray((item as any).foodNutrients) ? (item as any).foodNutrients : [];

    let calories: number | undefined;
    let protein_g: number | undefined;
    let carbs_g: number | undefined;
    let fats_g: number | undefined;
    let fiber_g: number | undefined;
    let sugar_g: number | undefined;
    let sodium_mg: number | undefined;

    for (const n of nutrients) {
      const nn = String((n as any).nutrientName ?? "").toLowerCase();
      const v = toNum((n as any).value);
      if (v === undefined) continue;
      if (nn.includes("energy") || nn.includes("calories")) calories = Math.round(v);
      else if (nn.includes("protein")) protein_g = v;
      else if (nn.includes("carbohydrate")) carbs_g = v;
      else if (nn.includes("total lipid") || nn.includes("fat")) fats_g = v;
      else if (nn.includes("fiber")) fiber_g = v;
      else if (nn.includes("sugars")) sugar_g = v;
      else if (nn.includes("sodium")) sodium_mg = Math.round(v);
    }

    if (calories === undefined && protein_g === undefined && carbs_g === undefined && fats_g === undefined) continue;

    results.push({
      name,
      brand,
      source: "usda",
      per100g: { calories, protein_g, carbs_g, fats_g, fiber_g, sugar_g, sodium_mg },
    });
  }
  return results;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });

  try {
    if (req.method !== "POST") return json({ error: "Use POST" }, 405);

    const body = await req.json().catch(() => ({}));
    const query = String(body?.query ?? "").trim();
    const limit = Math.min(Math.max(Number(body?.limit ?? 24), 1), 50);
    const page = Math.min(Math.max(Number(body?.page ?? 1), 1), 20);

    if (!query) return json({ query, page, limit, results: [] });

    // Run sources in parallel.
    const [usda, off] = await Promise.all([
      searchUSDA(query, limit),
      searchOpenFoodFacts(query, page, limit),
    ]);

    const merged: FoodResult[] = [];
    const seen = new Set<string>();
    for (const r of [...usda, ...off]) {
      const key = normKey(r.name, r.brand);
      if (seen.has(key)) continue;
      seen.add(key);
      merged.push(r);
      if (merged.length >= limit) break;
    }

    return json({ query, page, limit, results: merged });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
