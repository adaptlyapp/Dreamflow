-- Curated Resources Directory (geolocation-based)
--
-- Why this migration exists:
-- The Flutter app queries a Supabase table named `resources_curated` to merge
-- manually-curated directory entries with Google Places results.
-- Some older deployments used `specialty` (singular) while the app expects
-- `specialties` (plural). We keep compatibility by supporting both.

-- Enable UUID generator
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1) Curated directory entries
CREATE TABLE IF NOT EXISTS public.resources_curated (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  -- Address fields are intentionally flexible; app uses `address` + optional city/state.
  address TEXT NOT NULL DEFAULT '',
  city TEXT,
  state TEXT,
  postal_code TEXT,
  country TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  phone TEXT,
  contact_email TEXT,
  website TEXT,
  description TEXT,

  -- Compatibility:
  -- - `specialty` existed in earlier SQL; some code paths use `specialties`.
  specialty TEXT[] DEFAULT ARRAY[]::TEXT[],
  specialties TEXT[] DEFAULT ARRAY[]::TEXT[],

  -- Directory-specific tagging (optional)
  -- Examples:
  --   service_kinds: ['crt_vendor','seating_eval','repair','retail_dme','home_accessibility']
  --   capabilities: ['wheelchair_evaluation','custom_seating','repairs','rentals','ramps']
  service_kinds TEXT[] DEFAULT ARRAY[]::TEXT[],
  capabilities TEXT[] DEFAULT ARRAY[]::TEXT[],

  availability TEXT DEFAULT 'Unknown',
  rating DOUBLE PRECISION DEFAULT 0.0,
  review_count INTEGER DEFAULT 0,
  status TEXT DEFAULT 'approved',
  source TEXT,
  source_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_resources_curated_status ON public.resources_curated(status);
CREATE INDEX IF NOT EXISTS idx_resources_curated_location ON public.resources_curated(lat, lng);
CREATE INDEX IF NOT EXISTS idx_resources_curated_type ON public.resources_curated(type);

-- 2) Ensure resource_suggestions has the linkage fields used by approval workflow
ALTER TABLE public.resource_suggestions
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS approved_by_uid UUID,
  ADD COLUMN IF NOT EXISTS published_resource_id UUID;

-- 3) FK from suggestions -> curated when published
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_name = 'resource_suggestions_published_resource_id_fkey'
      AND table_schema = 'public'
      AND table_name = 'resource_suggestions'
  ) THEN
    ALTER TABLE public.resource_suggestions
      ADD CONSTRAINT resource_suggestions_published_resource_id_fkey
      FOREIGN KEY (published_resource_id) REFERENCES public.resources_curated(id) ON DELETE SET NULL;
  END IF;
END$$;

-- 4) Atomic approval RPC (used by app admin flow)
CREATE OR REPLACE FUNCTION public.approve_suggestion_and_publish(
  suggestion_id UUID,
  curated_resource JSONB,
  approved_by_uid UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_resource_id UUID;
  in_specialties TEXT[];
BEGIN
  -- Pull specialties from either key name (back-compat)
  in_specialties := CASE
    WHEN curated_resource ? 'specialties' THEN ARRAY(SELECT jsonb_array_elements_text(curated_resource->'specialties'))
    WHEN curated_resource ? 'specialty' THEN ARRAY(SELECT jsonb_array_elements_text(curated_resource->'specialty'))
    ELSE ARRAY[]::TEXT[]
  END;

  INSERT INTO public.resources_curated (
    name,
    type,
    address,
    city,
    state,
    postal_code,
    country,
    lat,
    lng,
    phone,
    contact_email,
    website,
    description,
    specialty,
    specialties,
    service_kinds,
    capabilities,
    availability,
    rating,
    review_count,
    status,
    source,
    source_id,
    created_at,
    updated_at
  )
  VALUES (
    COALESCE((curated_resource->>'name')::TEXT, ''),
    COALESCE((curated_resource->>'type')::TEXT, 'service'),
    COALESCE((curated_resource->>'address')::TEXT, ''),
    NULLIF((curated_resource->>'city')::TEXT, ''),
    NULLIF((curated_resource->>'state')::TEXT, ''),
    NULLIF((curated_resource->>'postal_code')::TEXT, ''),
    NULLIF((curated_resource->>'country')::TEXT, ''),
    (curated_resource->>'lat')::DOUBLE PRECISION,
    (curated_resource->>'lng')::DOUBLE PRECISION,
    NULLIF((curated_resource->>'phone')::TEXT, ''),
    NULLIF((curated_resource->>'contact_email')::TEXT, ''),
    NULLIF((curated_resource->>'website')::TEXT, ''),
    NULLIF((curated_resource->>'description')::TEXT, ''),
    in_specialties,
    in_specialties,
    CASE WHEN curated_resource ? 'service_kinds' THEN ARRAY(SELECT jsonb_array_elements_text(curated_resource->'service_kinds')) ELSE ARRAY[]::TEXT[] END,
    CASE WHEN curated_resource ? 'capabilities' THEN ARRAY(SELECT jsonb_array_elements_text(curated_resource->'capabilities')) ELSE ARRAY[]::TEXT[] END,
    COALESCE(NULLIF((curated_resource->>'availability')::TEXT, ''), 'Unknown'),
    0.0,
    0,
    'approved',
    COALESCE(NULLIF((curated_resource->>'source')::TEXT, ''), 'suggestion'),
    NULLIF((curated_resource->>'source_id')::TEXT, ''),
    NOW(),
    NOW()
  )
  RETURNING id INTO new_resource_id;

  UPDATE public.resource_suggestions
  SET
    status = 'approved',
    updated_at = NOW(),
    approved_at = NOW(),
    approved_by_uid = approve_suggestion_and_publish.approved_by_uid,
    published_resource_id = new_resource_id
  WHERE id = suggestion_id;

  RETURN new_resource_id;
END;
$$;

-- 5) RLS: allow everyone to read approved curated entries; keep writes server-side.
ALTER TABLE public.resources_curated ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read approved curated resources" ON public.resources_curated;
CREATE POLICY "Anyone can read approved curated resources"
  ON public.resources_curated
  FOR SELECT
  USING (status = 'approved');
