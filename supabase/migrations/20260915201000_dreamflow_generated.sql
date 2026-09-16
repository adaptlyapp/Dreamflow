-- Resources curated directory + provider directory search RPC
--
-- NOTE: Dreamflow's Supabase deploy UI appears to only list migrations that match
-- the `*_dreamflow_generated.sql` naming convention. This file intentionally uses
-- that pattern so it shows up as pending and can be deployed.
--
-- This migration is designed to be safe to run against projects that already
-- have an older `public.resources_curated` schema (schema drift). It ensures
-- all columns referenced by `public.search_provider_directory(...)` exist *before*
-- creating/replacing the SQL function (Postgres validates LANGUAGE sql functions
-- at CREATE time).

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1) Ensure `public.resources_curated` exists with a modern superset schema.
CREATE TABLE IF NOT EXISTS public.resources_curated (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL,

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

  specialty TEXT[] DEFAULT ARRAY[]::TEXT[],
  specialties TEXT[] DEFAULT ARRAY[]::TEXT[],

  provider_type TEXT,
  services_offered TEXT,
  service_area TEXT,
  service_area_radius_miles DOUBLE PRECISION,
  hours TEXT,
  availability TEXT DEFAULT 'Unknown',

  service_kinds TEXT[] DEFAULT ARRAY[]::TEXT[],
  capabilities TEXT[] DEFAULT ARRAY[]::TEXT[],
  populations_served TEXT[] DEFAULT ARRAY[]::TEXT[],
  conditions_served TEXT[] DEFAULT ARRAY[]::TEXT[],
  insurance_accepted TEXT[] DEFAULT ARRAY[]::TEXT[],

  does_repairs BOOLEAN DEFAULT FALSE,
  does_rentals BOOLEAN DEFAULT FALSE,
  does_sales BOOLEAN DEFAULT FALSE,
  does_crt_custom_wheelchairs BOOLEAN DEFAULT FALSE,
  does_wheelchair_evals_clinical BOOLEAN DEFAULT FALSE,
  does_seating_positioning BOOLEAN DEFAULT FALSE,
  does_home_modifications BOOLEAN DEFAULT FALSE,
  does_installation BOOLEAN DEFAULT FALSE,
  does_in_home_service BOOLEAN DEFAULT FALSE,
  does_insurance_coordination BOOLEAN DEFAULT FALSE,
  accepts_medicaid BOOLEAN,
  accepts_medicare BOOLEAN,

  geo_precision TEXT DEFAULT 'approximate',
  needs_verification BOOLEAN DEFAULT FALSE,
  verification_notes TEXT,
  last_verified_at TIMESTAMPTZ,

  rating DOUBLE PRECISION DEFAULT 0.0,
  review_count INTEGER DEFAULT 0,
  status TEXT DEFAULT 'approved',
  source TEXT,
  source_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2) Repair drift: add missing columns if the table already existed.
DO $do$
BEGIN
  IF to_regclass('public.resources_curated') IS NOT NULL THEN
    ALTER TABLE public.resources_curated
      ADD COLUMN IF NOT EXISTS address TEXT NOT NULL DEFAULT '',
      ADD COLUMN IF NOT EXISTS city TEXT,
      ADD COLUMN IF NOT EXISTS state TEXT,
      ADD COLUMN IF NOT EXISTS postal_code TEXT,
      ADD COLUMN IF NOT EXISTS country TEXT,
      ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION,
      ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION,
      ADD COLUMN IF NOT EXISTS phone TEXT,
      ADD COLUMN IF NOT EXISTS contact_email TEXT,
      ADD COLUMN IF NOT EXISTS website TEXT,
      ADD COLUMN IF NOT EXISTS description TEXT,
      ADD COLUMN IF NOT EXISTS specialty TEXT[] DEFAULT ARRAY[]::TEXT[],
      ADD COLUMN IF NOT EXISTS specialties TEXT[] DEFAULT ARRAY[]::TEXT[],
      ADD COLUMN IF NOT EXISTS provider_type TEXT,
      ADD COLUMN IF NOT EXISTS services_offered TEXT,
      ADD COLUMN IF NOT EXISTS service_area TEXT,
      ADD COLUMN IF NOT EXISTS service_area_radius_miles DOUBLE PRECISION,
      ADD COLUMN IF NOT EXISTS hours TEXT,
      ADD COLUMN IF NOT EXISTS availability TEXT DEFAULT 'Unknown',
      ADD COLUMN IF NOT EXISTS service_kinds TEXT[] DEFAULT ARRAY[]::TEXT[],
      ADD COLUMN IF NOT EXISTS capabilities TEXT[] DEFAULT ARRAY[]::TEXT[],
      ADD COLUMN IF NOT EXISTS populations_served TEXT[] DEFAULT ARRAY[]::TEXT[],
      ADD COLUMN IF NOT EXISTS conditions_served TEXT[] DEFAULT ARRAY[]::TEXT[],
      ADD COLUMN IF NOT EXISTS insurance_accepted TEXT[] DEFAULT ARRAY[]::TEXT[],
      ADD COLUMN IF NOT EXISTS does_repairs BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS does_rentals BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS does_sales BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS does_crt_custom_wheelchairs BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS does_wheelchair_evals_clinical BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS does_seating_positioning BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS does_home_modifications BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS does_installation BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS does_in_home_service BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS does_insurance_coordination BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS accepts_medicaid BOOLEAN,
      ADD COLUMN IF NOT EXISTS accepts_medicare BOOLEAN,
      ADD COLUMN IF NOT EXISTS geo_precision TEXT DEFAULT 'approximate',
      ADD COLUMN IF NOT EXISTS needs_verification BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS verification_notes TEXT,
      ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS rating DOUBLE PRECISION DEFAULT 0.0,
      ADD COLUMN IF NOT EXISTS review_count INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'approved',
      ADD COLUMN IF NOT EXISTS source TEXT,
      ADD COLUMN IF NOT EXISTS source_id TEXT,
      ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
      ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
END
$$;

-- Helpful indexes (idempotent)
CREATE INDEX IF NOT EXISTS idx_resources_curated_status ON public.resources_curated(status);
CREATE INDEX IF NOT EXISTS idx_resources_curated_location ON public.resources_curated(lat, lng);
CREATE INDEX IF NOT EXISTS idx_resources_curated_type ON public.resources_curated(type);
CREATE INDEX IF NOT EXISTS idx_resources_curated_provider_type ON public.resources_curated(provider_type);
CREATE INDEX IF NOT EXISTS idx_resources_curated_service_kinds ON public.resources_curated USING GIN (service_kinds);
CREATE INDEX IF NOT EXISTS idx_resources_curated_capabilities ON public.resources_curated USING GIN (capabilities);
CREATE INDEX IF NOT EXISTS idx_resources_curated_populations ON public.resources_curated USING GIN (populations_served);

-- Stable upsert key for seed data (source, source_id).
-- Remove pre-existing duplicates so a unique index can be built.
DROP INDEX IF EXISTS public.uq_resources_curated_source;
DELETE FROM public.resources_curated r
USING public.resources_curated keeper
WHERE r.source IS NOT NULL
  AND r.source_id IS NOT NULL
  AND keeper.source = r.source
  AND keeper.source_id = r.source_id
  AND keeper.ctid < r.ctid;

CREATE UNIQUE INDEX IF NOT EXISTS uq_resources_curated_source
  ON public.resources_curated(source, source_id);

-- 3) RLS: public read of approved entries
ALTER TABLE public.resources_curated ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read approved curated resources" ON public.resources_curated;
CREATE POLICY "Anyone can read approved curated resources"
  ON public.resources_curated
  FOR SELECT
  USING (status = 'approved');

-- 4) RPC: public.search_provider_directory(...)
CREATE OR REPLACE FUNCTION public.search_provider_directory(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  radius_miles DOUBLE PRECISION DEFAULT 40,
  provider_types TEXT[] DEFAULT NULL,
  require_repairs BOOLEAN DEFAULT FALSE,
  require_rentals BOOLEAN DEFAULT FALSE,
  require_sales BOOLEAN DEFAULT FALSE,
  require_crt BOOLEAN DEFAULT FALSE,
  require_clinical_eval BOOLEAN DEFAULT FALSE,
  require_seating BOOLEAN DEFAULT FALSE,
  require_home_modifications BOOLEAN DEFAULT FALSE,
  require_installation BOOLEAN DEFAULT FALSE,
  exclude_pediatric_only BOOLEAN DEFAULT FALSE,
  max_results INTEGER DEFAULT 25
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  provider_type TEXT,
  type TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  postal_code TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  distance_miles DOUBLE PRECISION,
  phone TEXT,
  contact_email TEXT,
  website TEXT,
  hours TEXT,
  availability TEXT,
  description TEXT,
  services_offered TEXT,
  service_area TEXT,
  service_kinds TEXT[],
  capabilities TEXT[],
  populations_served TEXT[],
  conditions_served TEXT[],
  insurance_accepted TEXT[],
  does_repairs BOOLEAN,
  does_rentals BOOLEAN,
  does_sales BOOLEAN,
  does_crt_custom_wheelchairs BOOLEAN,
  does_wheelchair_evals_clinical BOOLEAN,
  does_seating_positioning BOOLEAN,
  does_home_modifications BOOLEAN,
  does_installation BOOLEAN,
  does_in_home_service BOOLEAN,
  does_insurance_coordination BOOLEAN,
  accepts_medicaid BOOLEAN,
  accepts_medicare BOOLEAN,
  geo_precision TEXT,
  needs_verification BOOLEAN,
  last_verified_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  WITH scoped AS (
    SELECT
      r.*,
      3958.7559 * 2 * ASIN(
        LEAST(1, SQRT(
          POWER(SIN(RADIANS(r.lat - user_lat) / 2), 2) +
          COS(RADIANS(user_lat)) * COS(RADIANS(r.lat)) *
          POWER(SIN(RADIANS(r.lng - user_lng) / 2), 2)
        ))
      ) AS dist_miles
    FROM public.resources_curated r
    WHERE r.status = 'approved'
      AND r.lat IS NOT NULL
      AND r.lng IS NOT NULL
  )
  SELECT
    s.id, s.name, s.provider_type, s.type, s.address, s.city, s.state, s.postal_code,
    s.lat, s.lng, s.dist_miles AS distance_miles,
    s.phone, s.contact_email, s.website, s.hours, s.availability, s.description,
    s.services_offered, s.service_area,
    s.service_kinds, s.capabilities, s.populations_served, s.conditions_served, s.insurance_accepted,
    s.does_repairs, s.does_rentals, s.does_sales, s.does_crt_custom_wheelchairs,
    s.does_wheelchair_evals_clinical, s.does_seating_positioning,
    s.does_home_modifications, s.does_installation, s.does_in_home_service,
    s.does_insurance_coordination, s.accepts_medicaid, s.accepts_medicare,
    s.geo_precision, s.needs_verification, s.last_verified_at
  FROM scoped s
  WHERE (
      s.dist_miles <= radius_miles
      OR (s.service_area_radius_miles IS NOT NULL AND s.dist_miles <= s.service_area_radius_miles)
    )
    AND (provider_types IS NULL OR array_length(provider_types, 1) IS NULL OR s.provider_type = ANY(provider_types))
    AND (NOT require_repairs OR COALESCE(s.does_repairs, FALSE))
    AND (NOT require_rentals OR COALESCE(s.does_rentals, FALSE))
    AND (NOT require_sales OR COALESCE(s.does_sales, FALSE))
    AND (NOT require_crt OR COALESCE(s.does_crt_custom_wheelchairs, FALSE))
    AND (NOT require_clinical_eval OR COALESCE(s.does_wheelchair_evals_clinical, FALSE))
    AND (NOT require_seating OR COALESCE(s.does_seating_positioning, FALSE))
    AND (NOT require_home_modifications OR COALESCE(s.does_home_modifications, FALSE))
    AND (NOT require_installation OR COALESCE(s.does_installation, FALSE))
    AND (
      NOT exclude_pediatric_only
      OR s.populations_served IS NULL
      OR array_length(s.populations_served, 1) IS NULL
      OR NOT (s.populations_served = ARRAY['pediatric']::TEXT[])
    )
  ORDER BY s.dist_miles ASC
  LIMIT GREATEST(1, COALESCE(max_results, 25));
$$;

GRANT EXECUTE ON FUNCTION public.search_provider_directory(
  DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT[],
  BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, INTEGER
) TO anon, authenticated;
