import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { beforeUserCreated, beforeUserSignedIn } from 'firebase-functions/v2/identity';
import geoip from 'geoip-lite';
import * as crypto from 'crypto';
import {KeyManagementServiceClient} from '@google-cloud/kms';
import { Resend } from 'resend';

admin.initializeApp();
const db = admin.firestore();

// =============================================================================
// Identity blocking functions: Restrict sign-in to US only (no business hours, no SMS)
// =============================================================================

function isUsIp(ip: string | null | undefined): boolean {
  const ipStr = (ip || '').trim();
  if (!ipStr) return true; // allow when unknown to prevent accidental lockouts; tighten later if desired
  try {
    const hit = geoip.lookup(ipStr as any);
    const country = (hit && (hit as any).country) as string | undefined;
    return country === 'US';
  } catch {
    return true; // fail open on lookup errors
  }
}

export const usOnlyBeforeCreate = beforeUserCreated({ region: 'us-central1' }, async (event) => {
  const ip = (event as any)?.clientIpAddress || (event as any)?.context?.ipAddress || null;
  if (!isUsIp(ip)) {
    // Throwing blocks account creation/sign-in.
    throw new Error('Access restricted to the United States.');
  }
});

export const usOnlyBeforeSignIn = beforeUserSignedIn({ region: 'us-central1' }, async (event) => {
  const ip = (event as any)?.clientIpAddress || (event as any)?.context?.ipAddress || null;
  if (!isUsIp(ip)) {
    throw new Error('Access restricted to the United States.');
  }
  // Optionally: you can set custom claims here if needed
  return; // allow
});

// Callable: fetchGooglePlaceRating
// Input: { placeId: string }
// Behavior: Uses Google Places Details API to get rating + user_ratings_total
// Then writes to resource_ratings/gpl_<placeId> with avgGoogle, countGoogle, avgCombined/countCombined
export const fetchGooglePlaceRating = functions.region('us-central1').https.onCall(async (data, context) => {
  const placeId: string = data?.placeId;
  if (!placeId || typeof placeId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'placeId is required');
  }

  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (!apiKey) {
    throw new functions.https.HttpsError('failed-precondition', 'GOOGLE_MAPS_API_KEY not set');
  }

  const url = new URL('https://maps.googleapis.com/maps/api/place/details/json');
  url.searchParams.set('place_id', placeId);
  url.searchParams.set('fields', 'rating,user_ratings_total');
  url.searchParams.set('key', apiKey);

  const resp = await fetch(url.toString());
  if (!resp.ok) {
    const text = await resp.text();
    throw new functions.https.HttpsError('internal', `Places API error: ${resp.status} ${text}`);
  }
  const json = await resp.json();
  if (json.status !== 'OK') {
    throw new functions.https.HttpsError('internal', `Places API status ${json.status}: ${json.error_message || ''}`);
  }
  const result = json.result || {};
  const avgGoogle = typeof result.rating === 'number' ? result.rating : 0;
  const countGoogle = typeof result.user_ratings_total === 'number' ? result.user_ratings_total : 0;

  const docRef = db.collection('resource_ratings').doc(`gpl_${placeId}`);
  const docSnap = await docRef.get();
  const dataExisting = docSnap.exists ? docSnap.data() || {} : {};
  const avgApp = typeof dataExisting.avgApp === 'number' ? dataExisting.avgApp : 0;
  const countApp = typeof dataExisting.countApp === 'number' ? dataExisting.countApp : 0;
  const countCombined = (countGoogle || 0) + (countApp || 0);
  const avgCombined = countCombined > 0 ? (((avgGoogle || 0) * (countGoogle || 0)) + ((avgApp || 0) * (countApp || 0))) / countCombined : 0;

  await docRef.set({
    avgGoogle,
    countGoogle,
    avgApp,
    countApp,
    avgCombined,
    countCombined,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return { avgGoogle, countGoogle, avgCombined, countCombined };
});

// Trigger: recompute in-app and combined ratings when a review is created/updated/deleted
export const onReviewWrite = functions.region('us-central1').firestore
  .document('resource_ratings/{resourceId}/reviews/{uid}')
  .onWrite(async (change, context) => {
    const resourceId = context.params.resourceId as string;
    const parentRef = db.collection('resource_ratings').doc(resourceId);

    // Recompute app ratings from all reviews
    const reviewsSnap = await parentRef.collection('reviews').get();
    let countApp = 0;
    let sumApp = 0;
    for (const doc of reviewsSnap.docs) {
      const d = doc.data() as any;
      const r = typeof d.rating === 'number' ? d.rating : parseInt(d.rating, 10);
      if (!isNaN(r)) {
        countApp += 1;
        sumApp += r;
      }
    }
    const avgApp = countApp > 0 ? sumApp / countApp : 0;

    // Load Google rating fields
    const parentSnap = await parentRef.get();
    const p = parentSnap.exists ? (parentSnap.data() || {}) : {};
    const avgGoogle = typeof p.avgGoogle === 'number' ? p.avgGoogle : 0;
    const countGoogle = typeof p.countGoogle === 'number' ? p.countGoogle : 0;

    const countCombined = (countGoogle || 0) + countApp;
    const avgCombined = countCombined > 0
      ? (((avgGoogle || 0) * (countGoogle || 0)) + (avgApp * countApp)) / countCombined
      : 0;

    await parentRef.set({
      avgApp,
      countApp,
      avgCombined,
      countCombined,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });

// =============================================================================
// AES-256-GCM envelope encryption for tracker entry notes
// =============================================================================

type NotesCipher = {
  alg: 'AES-256-GCM';
  c: string; // base64 ciphertext
  iv: string; // base64 12-byte IV
  tag: string; // base64 16-byte auth tag
  dekWrapped: string; // base64 KMS-wrapped 32-byte DEK
  aad: string; // AAD used for GCM
  kmsKey: string; // symmetric KMS key name
};

function buildNotesAad(userId: string, entryId: string): string {
  return `users/${userId}/tracker_entries/${entryId}#notes`;
}

/**
 * Callable: encryptTrackerEntryNotes
 * Input: { userId: string, entryId: string, notes: string }
 * Output: { notesEnc: NotesCipher }
 *
 * Generates a random 256-bit DEK, encrypts notes with AES-256-GCM using a random 96-bit IV
 * and AAD bound to the record path, then wraps the DEK with Cloud KMS symmetric key.
 */
export const encryptTrackerEntryNotes = functions.region('us-central1').https.onCall(async (data, context) => {
  const auth = context.auth;
  if (!auth?.uid) throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  const userId = String(data?.userId || '');
  const entryId = String(data?.entryId || '');
  const notes = String(data?.notes || '');
  if (!userId || !entryId) throw new functions.https.HttpsError('invalid-argument', 'userId and entryId are required');
  if (userId !== auth.uid && !(auth.token as any)?.admin) throw new functions.https.HttpsError('permission-denied', 'Cannot encrypt for another user');
  if (!notes || notes.trim().length === 0) throw new functions.https.HttpsError('invalid-argument', 'notes is required');

  const kmsKey = (process.env.KMS_SYMMETRIC_KEY_NAME || '').trim();
  if (!kmsKey) throw new functions.https.HttpsError('failed-precondition', 'KMS_SYMMETRIC_KEY_NAME env var not set');

  // Generate DEK and IV
  const dek = crypto.randomBytes(32); // 256-bit
  const iv = crypto.randomBytes(12); // 96-bit
  const aad = buildNotesAad(userId, entryId);

  // Encrypt with AES-256-GCM
  const cipher = crypto.createCipheriv('aes-256-gcm', dek, iv);
  cipher.setAAD(Buffer.from(aad, 'utf8'));
  const enc1 = cipher.update(Buffer.from(notes, 'utf8'));
  const enc2 = cipher.final();
  const ciphertext = Buffer.concat([enc1, enc2]);
  const tag = cipher.getAuthTag();

  // Wrap DEK with KMS (symmetric encrypt)
  const [wrapResp] = await kmsClient.encrypt({ name: kmsKey, plaintext: dek });
  const dekWrapped = wrapResp.ciphertext as Buffer | Uint8Array | string | undefined;
  if (!dekWrapped) throw new functions.https.HttpsError('internal', 'KMS did not return wrapped key');

  const notesEnc: NotesCipher = {
    alg: 'AES-256-GCM',
    c: Buffer.from(ciphertext).toString('base64'),
    iv: Buffer.from(iv).toString('base64'),
    tag: Buffer.from(tag).toString('base64'),
    dekWrapped: Buffer.from(dekWrapped as any).toString('base64'),
    aad,
    kmsKey,
  };

  return { notesEnc };
});

/**
 * Callable: decryptTrackerEntryNotes
 * Input: { userId: string, entryId: string }
 * Output: { notes: string | null }
 *
 * Loads metadata from users/{uid}/tracker_entries/{entryId}.notesEnc and decrypts using KMS to unwrap the DEK.
 */
export const decryptTrackerEntryNotesImpl = functions.region('us-central1').https.onCall(async (data, context) => {
  const auth = context.auth;
  if (!auth?.uid) throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  const userId = String(data?.userId || '');
  const entryId = String(data?.entryId || '');
  if (!userId || !entryId) throw new functions.https.HttpsError('invalid-argument', 'userId and entryId are required');
  if (userId !== auth.uid && !(auth.token as any)?.admin) throw new functions.https.HttpsError('permission-denied', 'Cannot decrypt another user\'s record');

  const ref = db.collection('users').doc(userId).collection('tracker_entries').doc(entryId);
  const snap = await ref.get();
  if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Entry not found');
  const d = snap.data() as any;
  const enc = d?.notesEnc as NotesCipher | undefined;
  if (!enc || !enc.c) return { notes: null };

  const aad = buildNotesAad(userId, entryId);
  if (enc.aad !== aad) {
    // AAD mismatch indicates record path mismatch; refuse to decrypt
    throw new functions.https.HttpsError('failed-precondition', 'AAD mismatch');
  }

  const kmsKey = (process.env.KMS_SYMMETRIC_KEY_NAME || '').trim();
  if (!kmsKey) throw new functions.https.HttpsError('failed-precondition', 'KMS_SYMMETRIC_KEY_NAME env var not set');
  if (enc.kmsKey !== kmsKey) throw new functions.https.HttpsError('failed-precondition', 'KMS key mismatch');

  const dekWrapped = Buffer.from(enc.dekWrapped, 'base64');
  const [decResp] = await kmsClient.decrypt({ name: kmsKey, ciphertext: dekWrapped });
  const dek = decResp.plaintext as Buffer | Uint8Array | string | undefined;
  if (!dek) throw new functions.https.HttpsError('internal', 'KMS did not return DEK');

  const key = Buffer.from(dek as any);
  const iv = Buffer.from(enc.iv, 'base64');
  const tag = Buffer.from(enc.tag, 'base64');
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAAD(Buffer.from(aad, 'utf8'));
  decipher.setAuthTag(tag);
  const ct = Buffer.from(enc.c, 'base64');
  const p1 = decipher.update(ct);
  const p2 = decipher.final();
  const plaintext = Buffer.concat([p1, p2]).toString('utf8');
  return { notes: plaintext };
});

// Haversine distance in miles
function haversineMiles(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const toRad = (deg: number) => deg * Math.PI / 180;
  const R = 3958.7613; // miles
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Callable: searchNearbyOverpass — CORS-safe Overpass search for web clients
// Input: { lat: number, lng: number, query?: string, type?: string, radiusMiles?: number }
// Output: { items: Array<ResourceLike> }
// ResourceLike: { id, name, type, location, address, lat, lng, distance, phone?, website?, availability }
export const searchNearbyOverpass = functions.region('us-central1').https.onCall(async (data, context) => {
  const lat = Number(data?.lat);
  const lng = Number(data?.lng);
  if (!isFinite(lat) || !isFinite(lng)) {
    throw new functions.https.HttpsError('invalid-argument', 'lat and lng are required');
  }
  const query = typeof data?.query === 'string' ? data.query.trim() : '';
  const type: string | undefined = typeof data?.type === 'string' && data.type ? data.type : undefined;
  const radiusMiles = Math.max(1, Math.min(50, Number(data?.radiusMiles) || 5));

  // Build Overpass body (similar to client)
  const amenities = ['hospital', 'clinic', 'doctors', 'pharmacy', 'social_facility'];
  const healthcare = ['physiotherapist', 'psychotherapist', 'counselling', 'occupational_therapist'];

  let filteredAmenities = [...amenities];
  let filteredHealthcare = [...healthcare];
  if (type && type !== 'all') {
    if (type === 'therapist') {
      filteredAmenities = ['doctors'];
      filteredHealthcare = healthcare;
    } else if (type === 'center') {
      filteredAmenities = ['hospital', 'clinic'];
      filteredHealthcare = [];
    } else if (type === 'hospital') {
      filteredAmenities = ['hospital'];
      filteredHealthcare = [];
    } else if (type === 'service') {
      filteredAmenities = ['pharmacy', 'social_facility'];
      filteredHealthcare = [];
    } else if (type === 'pharmacy') {
      filteredAmenities = ['pharmacy'];
      filteredHealthcare = [];
    }
  }

  const nameFilter = query ? `["name"~"${query.replaceAll('"', '')}",i]` : '';
  const amenityRegex = filteredAmenities.length ? filteredAmenities.join('|') : '';
  const healthcareRegex = filteredHealthcare.length ? filteredHealthcare.join('|') : '';

  const radiusMeters = Math.round(radiusMiles * 1609.344);

  const lines: string[] = [];
  lines.push('[out:json][timeout:25];');
  lines.push('(');
  if (amenityRegex) {
    for (const kind of ['node', 'way', 'relation']) {
      lines.push(`  ${kind}["amenity"~"(${amenityRegex})"]${nameFilter}(around:${radiusMeters},${lat},${lng});`);
    }
  }
  if (healthcareRegex) {
    for (const kind of ['node', 'way', 'relation']) {
      lines.push(`  ${kind}["healthcare"~"(${healthcareRegex})"]${nameFilter}(around:${radiusMeters},${lat},${lng});`);
    }
  }
  lines.push(');');
  lines.push('out center tags 120;');
  const body = lines.join('\n');

  const endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.openstreetmap.ru/api/interpreter',
  ];

  let lastErr: any;
  let json: any = null;
  for (const url of endpoints) {
    try {
      const resp = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
        body: new URLSearchParams({ data: body }).toString(),
      });
      if (!resp.ok) {
        lastErr = new Error(`Overpass status ${resp.status}`);
        continue;
      }
      json = await resp.json();
      break;
    } catch (e) {
      lastErr = e;
    }
  }
  if (!json) {
    throw new functions.https.HttpsError('unavailable', `Overpass request failed: ${lastErr}`);
  }

  const elements: any[] = Array.isArray(json?.elements) ? json.elements : [];
  const items: any[] = [];
  for (const el of elements) {
    const tags = el?.tags || {};
    let elLat: number | null = (typeof el?.lat === 'number') ? el.lat : null;
    let elLon: number | null = (typeof el?.lon === 'number') ? el.lon : null;
    if (elLat == null || elLon == null) {
      const c = el?.center;
      if (c && typeof c.lat === 'number' && typeof c.lon === 'number') {
        elLat = c.lat; elLon = c.lon;
      }
    }
    if (elLat == null || elLon == null) continue;

    const amenity = (tags['amenity'] || '').toString().toLowerCase();
    const healthcareKind = (tags['healthcare'] || '').toString().toLowerCase();
    let mappedType = 'service';
    if (amenity === 'hospital' || amenity === 'clinic') {
      mappedType = amenity === 'hospital' ? 'hospital' : 'center';
    } else if (amenity === 'pharmacy') {
      mappedType = 'pharmacy';
    } else if (amenity === 'doctors' || (healthcare.includes(healthcareKind))) {
      mappedType = 'therapist';
    }

    const name: string = (tags['name'] || '').toString().trim();
    if (!name) continue;

    const house = (tags['addr:housenumber'] || '').toString();
    const street = (tags['addr:street'] || '').toString();
    const city = (tags['addr:city'] || '').toString();
    const suburb = (tags['addr:suburb'] || '').toString();
    const neigh = (tags['addr:neighbourhood'] || '').toString();
    const address = [house, street].filter(s => s.trim().length > 0).join(' ').trim() || (city || '');
    const location = suburb || neigh || city || 'Nearby';
    const phone = (tags['phone'] || tags['contact:phone'] || '').toString();
    const website = (tags['website'] || tags['contact:website'] || '').toString();
    const opening = (tags['opening_hours'] || '').toString();
    const availability = opening ? opening : 'Hours not available';
    const distance = haversineMiles(lat, lng, elLat, elLon);

    items.push({
      id: `osm_${el?.type}_${el?.id}`,
      name,
      type: mappedType,
      location,
      address,
      lat: elLat,
      lng: elLon,
      distance,
      phone: phone || undefined,
      website: website || undefined,
      availability,
    });
  }

  items.sort((a, b) => a.distance - b.distance);
  return { items };
});

// =============================================================================
// Resource suggestions: submit + moderate via email links
// =============================================================================

// Email sending uses RESEND via env var if present. No secret binding required.

type SuggestionInput = {
  name: string;
  type: string;
  address: string;
  city?: string;
  state?: string;
  postalCode?: string;
  country?: string;
  lat?: number;
  lng?: number;
  phone?: string;
  website?: string;
  contactEmail?: string;
  description?: string;
  specialties?: string[];
};

function required<T>(val: any, name: string): T {
  if (val == null) throw new functions.https.HttpsError('invalid-argument', `${name} is required`);
  return val as T;
}

async function geocodeIfNeeded(s: SuggestionInput): Promise<{ lat?: number; lng?: number; formatted?: string }> {
  if (typeof s.lat === 'number' && typeof s.lng === 'number') return { lat: s.lat, lng: s.lng };
  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (!apiKey) return {};
  const parts = [s.address, s.city, s.state, s.postalCode, s.country].filter(Boolean).join(', ');
  const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
  url.searchParams.set('address', parts);
  url.searchParams.set('key', apiKey);
  const resp = await fetch(url.toString());
  if (!resp.ok) return {};
  const json = await resp.json();
  if (json?.status !== 'OK') return {};
  const first = json.results?.[0];
  const loc = first?.geometry?.location;
  if (typeof loc?.lat === 'number' && typeof loc?.lng === 'number') {
    return { lat: loc.lat, lng: loc.lng, formatted: first?.formatted_address };
  }
  return {};
}

// removed SMTP transport (switching to Resend)

function approvalLinks(id: string, token: string) {
  const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || 'unknown';
  const region = 'us-central1';
  const base = `https://${region}-${projectId}.cloudfunctions.net/moderateResourceSuggestion`;
  const approve = `${base}?id=${encodeURIComponent(id)}&token=${encodeURIComponent(token)}&action=approve`;
  const reject = `${base}?id=${encodeURIComponent(id)}&token=${encodeURIComponent(token)}&action=reject`;
  return { approve, reject };
}

export const submitResourceSuggestion = functions.region('us-central1').https.onCall(async (data, context) => {
  const s: SuggestionInput = {
    name: required<string>(data?.name, 'name'),
    type: (data?.type || 'service').toString(),
    address: required<string>(data?.address, 'address'),
    city: data?.city,
    state: data?.state,
    postalCode: data?.postalCode,
    country: data?.country,
    lat: typeof data?.lat === 'number' ? data.lat : undefined,
    lng: typeof data?.lng === 'number' ? data.lng : undefined,
    phone: data?.phone,
    website: data?.website,
    contactEmail: data?.contactEmail,
    description: data?.description,
    specialties: Array.isArray(data?.specialties) ? data.specialties.map((x: any) => String(x)) : undefined,
  };

  const { lat, lng, formatted } = await geocodeIfNeeded(s);
  const token = (Math.random().toString(36).slice(2) + Math.random().toString(36).slice(2));
  const createdAt = admin.firestore.FieldValue.serverTimestamp();
  const createdBy = context.auth?.uid || null;
  const createdByEmail = context.auth?.token?.email || null;
  const docRef = await db.collection('resource_suggestions').add({
    ...s,
    ...(lat && lng ? { lat, lng } : {}),
    ...(formatted ? { address: formatted } : {}),
    status: 'pending',
    approvalToken: token,
    createdBy,
    createdByEmail,
    createdAt,
    updatedAt: createdAt,
  });

  // Send email via Resend
  const to = 'adaptlyapp@gmail.com';
  const { approve, reject } = approvalLinks(docRef.id, token);
  const subject = `New resource suggestion: ${s.name}`;
  const html = `
    <div style="font-family:Inter,Arial,sans-serif;font-size:14px;color:#111">
      <h2>New resource suggestion</h2>
      <p><b>Name:</b> ${s.name}</p>
      <p><b>Type:</b> ${s.type}</p>
      <p><b>Address:</b> ${formatted || s.address}</p>
      ${s.city ? `<p><b>City:</b> ${s.city}</p>` : ''}
      ${s.state ? `<p><b>State:</b> ${s.state}</p>` : ''}
      ${s.postalCode ? `<p><b>Postal:</b> ${s.postalCode}</p>` : ''}
      ${s.country ? `<p><b>Country:</b> ${s.country}</p>` : ''}
      ${s.phone ? `<p><b>Phone:</b> ${s.phone}</p>` : ''}
      ${s.website ? `<p><b>Website:</b> ${s.website}</p>` : ''}
      ${s.contactEmail ? `<p><b>Contact Email:</b> ${s.contactEmail}</p>` : ''}
      ${s.description ? `<p><b>Notes:</b> ${s.description}</p>` : ''}
      ${Array.isArray(s.specialties) && s.specialties!.length ? `<p><b>Specialties:</b> ${s.specialties!.join(', ')}</p>` : ''}
      <hr>
      <p>Moderate:</p>
      <p>
        <a href="${approve}" style="background:#16a34a;color:white;padding:10px 14px;border-radius:8px;text-decoration:none">Approve & Publish</a>
        &nbsp;&nbsp;
        <a href="${reject}" style="background:#dc2626;color:white;padding:10px 14px;border-radius:8px;text-decoration:none">Reject</a>
      </p>
    </div>
  `;
  try {
    const resendKey = (process.env.RESEND_API_KEY || '').trim();
    if (!resendKey) {
      console.warn('RESEND_API_KEY not set; skipping email send');
    } else {
      const resend = new Resend(resendKey);
      const from = (process.env.RESEND_FROM || 'Adaptly <onboarding@resend.dev>');
      const result = await resend.emails.send({ from, to, subject, html });
      if ((result as any)?.error) console.error('Resend error:', (result as any).error);
    }
  } catch (e) {
    console.error('Failed to send suggestion email via Resend (non-fatal)', e);
  }

  return { id: docRef.id };
});

export const moderateResourceSuggestion = functions.region('us-central1').https.onRequest(async (req, res) => {
  try {
    const id = (req.query.id || '').toString();
    const token = (req.query.token || '').toString();
    const action = (req.query.action || '').toString(); // approve | reject
    if (!id || !token || !action) {
      res.status(400).send('Missing id, token, or action');
      return;
    }
    const docRef = db.collection('resource_suggestions').doc(id);
    const snap = await docRef.get();
    if (!snap.exists) {
      res.status(404).send('Suggestion not found');
      return;
    }
    const data = snap.data() as any;
    if (!data || data.approvalToken !== token) {
      res.status(403).send('Invalid token');
      return;
    }
    if (action === 'reject') {
      await docRef.set({ status: 'rejected', updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      res.status(200).send('Suggestion rejected.');
      return;
    }
    // Approve -> create curated resource
    const payload: any = {
      name: data.name,
      type: data.type || 'service',
      address: data.address,
      city: data.city || null,
      state: data.state || null,
      postalCode: data.postalCode || null,
      country: data.country || null,
      lat: typeof data.lat === 'number' ? data.lat : null,
      lng: typeof data.lng === 'number' ? data.lng : null,
      phone: data.phone || null,
      website: data.website || null,
      contactEmail: data.contactEmail || null,
      availability: 'Hours not available',
      specialties: Array.isArray(data.specialties) ? data.specialties : [],
      status: 'approved',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (payload.lat == null || payload.lng == null) {
      try {
        const { lat, lng, formatted } = await geocodeIfNeeded({
          name: payload.name,
          type: payload.type,
          address: payload.address,
          city: payload.city || undefined,
          state: payload.state || undefined,
          postalCode: payload.postalCode || undefined,
          country: payload.country || undefined,
        });
 
// =============================================================================
// Digital signatures for medical records (tracker entries)
// =============================================================================

const kmsClient = new KeyManagementServiceClient();

type Canonical = string;

function stableStringify(obj: any): Canonical {
  if (obj === null || typeof obj !== 'object') return JSON.stringify(obj);
  if (Array.isArray(obj)) return '[' + obj.map(stableStringify).join(',') + ']';
  const keys = Object.keys(obj).sort();
  const parts: string[] = [];
  for (const k of keys) {
    parts.push(JSON.stringify(k) + ':' + stableStringify(obj[k]));
  }
  return '{' + parts.join(',') + '}';
}

function pickTrackerEntryFields(data: any, docId: string, userId: string) {
  // Only include stable, user-provided fields. Exclude server timestamps and any signature/meta fields.
  return {
    _collection: 'users/{uid}/tracker_entries',
    _docId: docId,
    userId,
    date: data?.date instanceof admin.firestore.Timestamp ? (data.date as admin.firestore.Timestamp).toDate().toISOString() : (typeof data?.date === 'string' ? data.date : null),
    painLevel: isFinite(Number(data?.painLevel)) ? Number(data.painLevel) : null,
    mood: typeof data?.mood === 'string' ? data.mood : null,
    spasmFrequency: isFinite(Number(data?.spasmFrequency)) ? Number(data.spasmFrequency) : null,
    bladderSuccess: typeof data?.bladderSuccess === 'boolean' ? data.bladderSuccess : null,
    bowelProgram: typeof data?.bowelProgram === 'boolean' ? data.bowelProgram : null,
    sleepQuality: isFinite(Number(data?.sleepQuality)) ? Number(data.sleepQuality) : null,
    energyLevel: isFinite(Number(data?.energyLevel)) ? Number(data.energyLevel) : null,
    systolicBP: isFinite(Number(data?.systolicBP)) ? Number(data.systolicBP) : null,
    diastolicBP: isFinite(Number(data?.diastolicBP)) ? Number(data.diastolicBP) : null,
    heartRate: isFinite(Number(data?.heartRate)) ? Number(data.heartRate) : null,
    steps: isFinite(Number(data?.steps)) ? Number(data.steps) : null,
    notes: typeof data?.notes === 'string' ? data.notes : null,
  };
}

export const signTrackerEntry = functions.region('us-central1').https.onCall(async (data, context) => {
  const auth = context.auth;
  if (!auth?.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  const userId = (data?.userId || '').toString();
  const entryId = (data?.entryId || '').toString();
  if (!userId || !entryId) {
    throw new functions.https.HttpsError('invalid-argument', 'userId and entryId are required');
  }
  if (userId !== auth.uid && !(auth.token as any)?.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Cannot sign another user\'s record');
  }

  const keyVersion = (process.env.KMS_KEY_VERSION_NAME || '').trim();
  if (!keyVersion) {
    throw new functions.https.HttpsError('failed-precondition', 'KMS_KEY_VERSION_NAME env var not set');
  }

  const ref = db.collection('users').doc(userId).collection('tracker_entries').doc(entryId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('not-found', 'Entry not found');
  }
  const d = snap.data() as any;
  if ((d?.signMeta?.signed) === true) {
    throw new functions.https.HttpsError('failed-precondition', 'Entry already signed');
  }

  const payload = pickTrackerEntryFields(d, entryId, userId);
  const canonical = stableStringify(payload);
  const hash = crypto.createHash('sha256').update(Buffer.from(canonical, 'utf8')).digest();

  // KMS asymmetric sign
  const [resp] = await kmsClient.asymmetricSign({ name: keyVersion, digest: { sha256: hash } });
  const signature = resp.signature as Buffer | Uint8Array | string | undefined;
  if (!signature) {
    throw new functions.https.HttpsError('internal', 'KMS did not return a signature');
  }
  const signatureBase64 = Buffer.from(signature as any).toString('base64');
  const hashBase64 = Buffer.from(hash).toString('base64');

  const signMeta = {
    signed: true,
    signedAt: admin.firestore.FieldValue.serverTimestamp(),
    signerUid: auth.uid,
    alg: 'RSASSA-PKCS1-v1_5',
    hashAlg: 'SHA256',
    hashBase64,
    signatureBase64,
    kmsKeyVersion: keyVersion,
    schema: 'trackerEntryV1',
  };

  await ref.set({ signMeta }, { merge: true });

  return { ok: true, signMeta };
});
        if (lat && lng) { payload.lat = lat; payload.lng = lng; }
        if (formatted) { payload.address = formatted; }
      } catch {}
    }
    const curatedRef = await db.collection('resources_curated').add(payload);
    await docRef.set({ status: 'approved', approvedResourceId: curatedRef.id, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    res.status(200).send('Suggestion approved and published.');
  } catch (e) {
    console.error(e);
    res.status(500).send('Internal error');
  }
});

// =============================================================================
// Automatic digital signatures for user condition lists
// =============================================================================

/**
 * Extract a stable payload from a user doc focused on the conditions list only.
 * We sort and dedupe the list to make the canonical form stable.
 */
function pickUserConditionsFields(data: any, userId: string) {
  const raw = Array.isArray(data?.conditions) ? data.conditions : [];
  const arr = raw.map((x: any) => String(x)).filter(x => x.trim().length > 0);
  const uniqSorted = Array.from(new Set(arr)).sort();
  return {
    _collection: 'users',
    _docId: userId,
    userId,
    conditions: uniqSorted,
    schema: 'userConditionsV1',
  };
}

/**
 * Firestore trigger that automatically signs users/{uid}.conditions whenever it changes.
 * - Computes a SHA-256 hash over a stable canonical JSON of the relevant fields
 * - Signs with Cloud KMS (KMS_KEY_VERSION_NAME)
 * - Writes to users/{uid}.conditionsSign with metadata { signedAt, hashBase64, signatureBase64, ... }
 *
 * It is idempotent: if the computed hash matches conditionsSign.hashBase64, no-op.
 */
export const autoSignUserConditions = functions.region('us-central1').firestore
  .document('users/{uid}')
  .onWrite(async (change, context) => {
    try {
      const after = change.after.exists ? change.after.data() as any : null;
      if (!after) return;

      const userId = context.params.uid as string;
      const payload = pickUserConditionsFields(after, userId);
      const canonical = stableStringify(payload);
      const hash = crypto.createHash('sha256').update(Buffer.from(canonical, 'utf8')).digest();
      const hashBase64 = Buffer.from(hash).toString('base64');

      const existing = (after?.conditionsSign || {}) as any;
      if (existing?.hashBase64 === hashBase64 && existing?.signatureBase64) {
        // Already signed for current conditions; nothing to do.
        return;
      }

      const keyVersion = (process.env.KMS_KEY_VERSION_NAME || '').trim();
      if (!keyVersion) {
        console.warn('KMS_KEY_VERSION_NAME not set; skipping autoSignUserConditions');
        return;
      }

      // KMS asymmetric sign
      const [resp] = await kmsClient.asymmetricSign({ name: keyVersion, digest: { sha256: hash } });
      const signature = resp.signature as Buffer | Uint8Array | string | undefined;
      if (!signature) {
        console.error('autoSignUserConditions: KMS did not return a signature');
        return;
      }
      const signatureBase64 = Buffer.from(signature as any).toString('base64');

      const signMeta = {
        signed: true,
        signedAt: admin.firestore.FieldValue.serverTimestamp(),
        alg: 'RSASSA-PKCS1-v1_5',
        hashAlg: 'SHA256',
        hashBase64,
        signatureBase64,
        kmsKeyVersion: keyVersion,
        schema: 'userConditionsV1',
      };

      const ref = change.after.ref;
      await ref.set({ conditionsSign: signMeta }, { merge: true });
    } catch (e) {
      console.error('autoSignUserConditions error', e);
    }
  });

// =============================================================================
// Immutable, KMS-signed audit logs (append-only, tamper-evident)
// =============================================================================

type AuditAction = 'read'|'decrypt'|'create'|'update'|'delete';

const AUDIT_SCHEMA = 'auditLogV1';

function getForwardedIp(raw: any): string | null {
  try {
    const xf = raw?.headers?.['x-forwarded-for'] as string | undefined;
    if (!xf) return null;
    return xf.split(',')[0].trim();
  } catch { return null; }
}

function getUserAgent(raw: any): string | null {
  try { return (raw?.headers?.['user-agent'] as string) || null; } catch { return null; }
}

async function appendAuditLog(opts: {
  subjectUid: string;
  action: AuditAction;
  resource: string;          // e.g., users/{uid}/tracker_entries/{entryId}
  resourceType: string;      // e.g., tracker_entry
  actorUid: string | null;   // caller uid if available
  actorEmail?: string | null;
  userAgent?: string | null;
  ip?: string | null;
}): Promise<void> {
  const keyVersion = (process.env.KMS_KEY_VERSION_NAME || '').trim();
  if (!keyVersion) {
    console.warn('KMS_KEY_VERSION_NAME not set; appendAuditLog is disabled');
    return;
  }

  const heads = db.collection('audit_heads').doc(opts.subjectUid);
  const logs = db.collection('audit_logs');

  await db.runTransaction(async tx => {
    const headSnap = await tx.get(heads);
    const headData = headSnap.exists ? (headSnap.data() as any) : null;
    const prevHashBase64: string | null = headData?.lastHashBase64 || null;
    const seq: number = (typeof headData?.seq === 'number' ? headData.seq : 0) + 1;

    const core = {
      schema: AUDIT_SCHEMA,
      subjectUid: opts.subjectUid,
      actorUid: opts.actorUid,
      action: opts.action,
      resource: opts.resource,
      resourceType: opts.resourceType,
      userAgent: opts.userAgent || null,
      ip: opts.ip || null,
      seq,
      prevHashBase64,
    };

    // Compute canonical hash over core (exclude createdAt/signature fields)
    const canonical = stableStringify(core);
    const hash = crypto.createHash('sha256').update(Buffer.from(canonical, 'utf8')).digest();
    const [resp] = await kmsClient.asymmetricSign({ name: keyVersion, digest: { sha256: hash } });
    const signature = resp.signature as Buffer | Uint8Array | string | undefined;
    if (!signature) throw new Error('appendAuditLog: KMS did not return a signature');
    const hashBase64 = Buffer.from(hash).toString('base64');
    const signatureBase64 = Buffer.from(signature as any).toString('base64');

    const logDoc = {
      ...core,
      hashBase64,
      signatureBase64,
      kmsKeyVersion: keyVersion,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const logRef = logs.doc();
    tx.set(logRef, logDoc);
    tx.set(heads, { seq, lastHashBase64: hashBase64, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  });
}

export const recordAuditLog = functions.region('us-central1').https.onCall(async (data, context) => {
  const auth = context.auth;
  if (!auth?.uid) throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  const actionIn = (data?.action || 'read').toString();
  const action: AuditAction = (['read','decrypt','create','update','delete'] as const).includes(actionIn as any) ? (actionIn as AuditAction) : 'read';
  // Only allow clients to submit read/decrypt; write ops should be logged server-side as well.
  if (action !== 'read' && action !== 'decrypt' && action !== 'create' && action !== 'update' && action !== 'delete') {
    throw new functions.https.HttpsError('invalid-argument', 'Unsupported action');
  }
  const subjectUid = (data?.subjectUid || '').toString();
  const resource = (data?.resource || '').toString();
  const resourceType = (data?.resourceType || '').toString();
  if (!subjectUid || !resource || !resourceType) {
    throw new functions.https.HttpsError('invalid-argument', 'subjectUid, resource, and resourceType are required');
  }
  // Basic guard to prevent arbitrary external targets
  if (!resource.startsWith(`users/${subjectUid}/`)) {
    throw new functions.https.HttpsError('permission-denied', 'Invalid resource path');
  }

  const ip = getForwardedIp((context as any).rawRequest);
  const ua = getUserAgent((context as any).rawRequest);
  await appendAuditLog({
    subjectUid,
    action,
    resource,
    resourceType,
    actorUid: auth.uid,
    actorEmail: (auth.token as any)?.email || null,
    userAgent: ua,
    ip,
  });
  return { ok: true };
});

// Firestore triggers: log PHI modifications for tracker entries
export const auditTrackerEntryWrite = functions.region('us-central1').firestore
  .document('users/{uid}/tracker_entries/{entryId}')
  .onWrite(async (change, context) => {
    try {
      const uid = context.params.uid as string;
      const entryId = context.params.entryId as string;
      const resource = `users/${uid}/tracker_entries/${entryId}`;
      let action: AuditAction;
      if (!change.before.exists && change.after.exists) action = 'create';
      else if (change.before.exists && change.after.exists) action = 'update';
      else action = 'delete';
      await appendAuditLog({
        subjectUid: uid,
        action,
        resource,
        resourceType: 'tracker_entry',
        actorUid: null, // unknown in trigger context
        actorEmail: null,
        userAgent: null,
        ip: null,
      });
    } catch (e) {
      console.error('auditTrackerEntryWrite error', e);
    }
  });

// Wrap decrypt callable with audit log on successful decrypt
// Replace export with wrapper
export const decryptTrackerEntryNotes = functions.region('us-central1').https.onCall(async (data, context) => {
  const result = await (async () => {
    const auth = context.auth;
    if (!auth?.uid) throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    const userId = String(data?.userId || '');
    const entryId = String(data?.entryId || '');
    if (!userId || !entryId) throw new functions.https.HttpsError('invalid-argument', 'userId and entryId are required');
    // Reuse the original logic by calling the implementation above directly
    const res = await decryptTrackerEntryNotesImpl(data, context);
    return res;
  })();
  try {
    const userId = String(data?.userId || '');
    const entryId = String(data?.entryId || '');
    const ip = getForwardedIp((context as any).rawRequest);
    const ua = getUserAgent((context as any).rawRequest);
    await appendAuditLog({
      subjectUid: userId,
      action: 'decrypt',
      resource: `users/${userId}/tracker_entries/${entryId}`,
      resourceType: 'tracker_entry_notes',
      actorUid: context.auth?.uid || null,
      actorEmail: (context.auth?.token as any)?.email || null,
      ip,
      userAgent: ua,
    });
  } catch (e) {
    console.error('audit decryptTrackerEntryNotes error', e);
  }
  return result;
});

// =============================================================================
// One-time maintenance: Backfill/repair patient codes for all users
// =============================================================================

function composePatientCodeTS(uid: string, hospitalId: string): string {
  const parts = hospitalId.split(/[_\s-]+/).filter(p => p.trim().length > 0);
  let prefix: string;
  if (parts.length > 0) {
    const letters = parts.slice(0, 3).map(p => p[0].toUpperCase()).join('');
    prefix = (letters + 'XXX').slice(0, 3);
  } else {
    const clean = hospitalId.replace(/[^A-Za-z0-9]/g, '').toUpperCase();
    prefix = (clean ? clean.slice(0, 3) : 'HSP').padEnd(3, 'X');
  }
  const cleanedUid = uid.replace(/[^A-Za-z0-9]/g, '');
  const tail = (cleanedUid.length >= 6 ? cleanedUid.slice(-6) : cleanedUid.padStart(6, '0')).toUpperCase();
  return `${prefix}-${tail}`;
}

export const backfillPatientCodes = functions.region('us-central1').https.onCall(async (data, context) => {
  // Require auth; further restriction to admins can be added via custom claims.
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  const stats: Record<string, number> = {
    scanned: 0,
    updated: 0,
    unchanged: 0,
    skipped_no_hospital: 0,
    errors: 0,
  };
  try {
    const col = db.collection('users');
    let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
    const batchSize = Math.max(50, Math.min(500, Number(data?.batchSize) || 300));
    while (true) {
      const q = col.orderBy(admin.firestore.FieldPath.documentId()).limit(batchSize);
      const snap = lastDoc ? await q.startAfter(lastDoc.id).get() : await q.get();
      if (snap.empty) break;

      const batch = db.batch();
      for (const d of snap.docs) {
        try {
          stats.scanned += 1;
          const docData = d.data() as any;
          const prefs = (docData?.preferences && typeof docData.preferences === 'object') ? docData.preferences : {};
          const hospitalId = (prefs?.hospitalId || '').toString().trim();
          if (!hospitalId) {
            stats.skipped_no_hospital += 1;
            continue;
          }
          const computed = composePatientCodeTS(d.id, hospitalId);
          const existing = (docData?.patientCode || '').toString().trim();
          if (!existing || existing !== computed) {
            batch.set(d.ref, {
              patientCode: computed,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              preferences: { hospitalId },
            }, { merge: true });
            stats.updated += 1;
          } else {
            stats.unchanged += 1;
          }
        } catch (e) {
          console.error('backfillPatientCodes item error for', d.id, e);
          stats.errors += 1;
        }
      }
      try {
        await batch.commit();
      } catch (e) {
        console.error('backfillPatientCodes batch commit error', e);
        // If the batch fails, count the updates as errors for transparency
        stats.errors += 1;
      }
      lastDoc = snap.docs[snap.docs.length - 1];
      // brief pause to avoid write bursts
      await new Promise(res => setTimeout(res, 25));
    }
  } catch (e) {
    console.error('backfillPatientCodes fatal error', e);
    stats.errors += 1;
  }
  return stats;
});
