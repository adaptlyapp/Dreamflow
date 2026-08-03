-- Migration: Remove foreign key constraint from users.id to allow multiple profiles per auth user
-- Date: 2026-05-29
-- 
-- Problem: The users.id column has a foreign key constraint to auth.users(id), which prevents
-- creating multiple profiles (patient + family) for the same auth user since we need unique IDs
-- for each profile.
--
-- Solution: Drop the foreign key constraint on users.id. The auth_user_id column already properly
-- references auth.users(id), so we don't lose the relationship to the auth user.

-- Step 1: Drop the foreign key constraint on users.id if it exists
DO $$
BEGIN
  -- Check if the constraint exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'users_id_fkey' AND conrelid = 'users'::regclass
  ) THEN
    -- Drop the constraint
    ALTER TABLE users DROP CONSTRAINT users_id_fkey;
    RAISE NOTICE 'Dropped foreign key constraint users_id_fkey';
  ELSE
    RAISE NOTICE 'Constraint users_id_fkey does not exist, skipping';
  END IF;
END $$;

-- Step 2: Ensure id column has a default for new rows (if not already set)
-- This allows the database to auto-generate UUIDs for new profiles
DO $$
BEGIN
  -- Check if the column already has a default
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' 
    AND column_name = 'id' 
    AND column_default IS NOT NULL
  ) THEN
    ALTER TABLE users ALTER COLUMN id SET DEFAULT gen_random_uuid();
    RAISE NOTICE 'Set default gen_random_uuid() for users.id';
  ELSE
    RAISE NOTICE 'Column users.id already has a default, skipping';
  END IF;
END $$;

-- Step 3: Add comment to document the change
COMMENT ON COLUMN users.id IS 'Unique profile ID (UUID). Each profile has its own ID. Use auth_user_id to link profiles to the same auth user.';
