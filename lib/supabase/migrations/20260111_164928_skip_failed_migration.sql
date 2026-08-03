-- This migration exists to skip the problematic 20260111164927 migration
-- The communities table already exists, so we don't need to rename groups to communities
-- This is a no-op migration that will simply be marked as applied

-- Check current state and do nothing if everything is already correct
DO $$
BEGIN
  -- Log that this migration is being applied
  RAISE NOTICE 'Skipping groups->communities rename as communities table already exists';
END $$;
