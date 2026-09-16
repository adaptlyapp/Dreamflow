-- Repair migration: align legacy `public.resources_curated` with the provider directory RPC.
--
-- Why this exists
-- Some remote DBs already had an older `resources_curated` table before
-- `20260915_120000_curated_resources_directory.sql` landed.
-- Because that earlier migration uses `CREATE TABLE IF NOT EXISTS`, the newer
-- columns (e.g. `city`) were never added, and later migrations fail when
-- compiling `public.search_provider_directory()` (SQL functions validate column
-- references at CREATE time).
--
-- NOTE: This file is intentionally timestamped to run *before* any migration
-- bundle that creates/updates `search_provider_directory`.

-- Ensure base table exists.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.resources_curated (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL DEFAULT '',
  type TEXT NOT NULL DEFAULT 'service'
);

-- Add/repair all columns referenced by provider-directory RPCs & seed data.
ALTER TABLE public.resources_curated
  -- Base address / geo
  ADD COLUMN IF NOT EXISTS address TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS state TEXT,
  ADD COLUMN IF NOT EXISTS postal_code TEXT,
  ADD COLUMN IF NOT EXISTS country TEXT,
  ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION,

  -- Contact
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS contact_email TEXT,
  ADD COLUMN IF NOT EXISTS website TEXT,
  ADD COLUMN IF NOT EXISTS hours TEXT,

  -- Directory metadata
  ADD COLUMN IF NOT EXISTS availability TEXT DEFAULT 'Unknown',
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS provider_type TEXT,
  ADD COLUMN IF NOT EXISTS services_offered TEXT,
  ADD COLUMN IF NOT EXISTS service_area TEXT,
  ADD COLUMN IF NOT EXISTS service_area_radius_miles DOUBLE PRECISION,

  -- Tagging / facets
  ADD COLUMN IF NOT EXISTS specialty TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS specialties TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS service_kinds TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS capabilities TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS insurance_accepted TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS populations_served TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS conditions_served TEXT[] DEFAULT ARRAY[]::TEXT[],

  -- Capability flags
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

  -- Verification
  ADD COLUMN IF NOT EXISTS geo_precision TEXT DEFAULT 'approximate',
  ADD COLUMN IF NOT EXISTS needs_verification BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS verification_notes TEXT,
  ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ,

  -- Source / timestamps
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS source TEXT,
  ADD COLUMN IF NOT EXISTS source_id TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Indexes used by lookups / RPC filters.
CREATE INDEX IF NOT EXISTS idx_resources_curated_status ON public.resources_curated(status);
CREATE INDEX IF NOT EXISTS idx_resources_curated_location ON public.resources_curated(lat, lng);
CREATE INDEX IF NOT EXISTS idx_resources_curated_type ON public.resources_curated(type);
CREATE INDEX IF NOT EXISTS idx_resources_curated_provider_type ON public.resources_curated(provider_type);

-- GIN indexes for array filters.
CREATE INDEX IF NOT EXISTS idx_resources_curated_service_kinds ON public.resources_curated USING GIN (service_kinds);
CREATE INDEX IF NOT EXISTS idx_resources_curated_capabilities ON public.resources_curated USING GIN (capabilities);
CREATE INDEX IF NOT EXISTS idx_resources_curated_populations ON public.resources_curated USING GIN (populations_served);

-- Stable upsert key for curated seed data.
DROP INDEX IF EXISTS public.uq_resources_curated_source;

-- If duplicates exist (same non-null source+source_id), keep one deterministically.
DELETE FROM public.resources_curated r
USING public.resources_curated keeper
WHERE r.source IS NOT NULL
  AND r.source_id IS NOT NULL
  AND keeper.source = r.source
  AND keeper.source_id = r.source_id
  AND keeper.ctid < r.ctid;

CREATE UNIQUE INDEX IF NOT EXISTS uq_resources_curated_source ON public.resources_curated(source, source_id);
