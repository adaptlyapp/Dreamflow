-- Dreamflow generated migration (patched)
--
-- This file exists because Dreamflow/Supabase deployment was attempting to apply a
-- migration with this exact name and failing with:
--   ERROR: column s.city does not exist (SQLSTATE 42703)
--
-- Root cause: some remote projects already have a legacy `public.resources_curated`
-- table that predates the newer schema. Earlier migrations used
-- `CREATE TABLE IF NOT EXISTS`, which does NOT add missing columns on an existing
-- table. SQL-language functions validate referenced columns at CREATE time, so the
-- RPC below must only be created after ensuring the required columns exist.

-- 1) Safety-net schema drift fix -------------------------------------------------
-- Guarded so this migration is safe even on brand-new databases where the table
-- might not yet exist at the moment this runs.
DO $$
BEGIN
  IF to_regclass('public.resources_curated') IS NOT NULL THEN
    ALTER TABLE public.resources_curated
      ADD COLUMN IF NOT EXISTS address TEXT NOT NULL DEFAULT '',
      ADD COLUMN IF NOT EXISTS city TEXT,
      ADD COLUMN IF NOT EXISTS state TEXT,
      ADD COLUMN IF NOT EXISTS postal_code TEXT,
      ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION,
      ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION;
  END IF;
END$$;

-- 2) Geolocation + capability search RPC ----------------------------------------
-- Returns approved directory entries within `radius_miles` of the user, filtered
-- by optional provider types / required capability flags, ordered by distance.
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
      -- Haversine distance in miles
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
    s.id,
    s.name,
    s.provider_type,
    s.type,
    s.address,
    s.city,
    s.state,
    s.postal_code,
    s.lat,
    s.lng,
    s.dist_miles AS distance_miles,
    s.phone,
    s.contact_email,
    s.website,
    s.hours,
    s.availability,
    s.description,
    s.services_offered,
    s.service_area,
    s.service_kinds,
    s.capabilities,
    s.populations_served,
    s.conditions_served,
    s.insurance_accepted,
    s.does_repairs,
    s.does_rentals,
    s.does_sales,
    s.does_crt_custom_wheelchairs,
    s.does_wheelchair_evals_clinical,
    s.does_seating_positioning,
    s.does_home_modifications,
    s.does_installation,
    s.does_in_home_service,
    s.does_insurance_coordination,
    s.accepts_medicaid,
    s.accepts_medicare,
    s.geo_precision,
    s.needs_verification,
    s.last_verified_at
  FROM scoped s
  WHERE s.dist_miles <= radius_miles
    AND (provider_types IS NULL OR s.provider_type = ANY(provider_types))
    AND (NOT require_repairs OR COALESCE(s.does_repairs, FALSE) = TRUE)
    AND (NOT require_rentals OR COALESCE(s.does_rentals, FALSE) = TRUE)
    AND (NOT require_sales OR COALESCE(s.does_sales, FALSE) = TRUE)
    AND (NOT require_crt OR COALESCE(s.does_crt_custom_wheelchairs, FALSE) = TRUE)
    AND (NOT require_clinical_eval OR COALESCE(s.does_wheelchair_evals_clinical, FALSE) = TRUE)
    AND (NOT require_seating OR COALESCE(s.does_seating_positioning, FALSE) = TRUE)
    AND (NOT require_home_modifications OR COALESCE(s.does_home_modifications, FALSE) = TRUE)
    AND (NOT require_installation OR COALESCE(s.does_installation, FALSE) = TRUE)
    AND (NOT exclude_pediatric_only OR COALESCE(s.populations_served, ARRAY[]::TEXT[]) <> ARRAY['pediatric']::TEXT[])
  ORDER BY s.dist_miles ASC
  LIMIT max_results;
$$;
