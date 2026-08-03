-- Fix: Allow same email to have both patient and family profiles (idempotent version)
-- Migration: fix_dual_role_accounts
-- Date: 2026-05-27
-- This migration safely handles the case where previous migration was partially applied

-- Step 1: Add auth_user_id column (IF NOT EXISTS handles if already created)
ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_user_id UUID;

-- Step 2: Backfill auth_user_id with the current id (only for rows where it's NULL)
UPDATE users SET auth_user_id = id WHERE auth_user_id IS NULL;

-- Step 3: Make auth_user_id NOT NULL (safe to run multiple times)
DO $$
BEGIN
  ALTER TABLE users ALTER COLUMN auth_user_id SET NOT NULL;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Column auth_user_id already NOT NULL or error: %', SQLERRM;
END $$;

-- Step 4: Add foreign key constraint (with existence check)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_users_auth_user'
  ) THEN
    ALTER TABLE users ADD CONSTRAINT fk_users_auth_user 
      FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    RAISE NOTICE 'Created foreign key constraint fk_users_auth_user';
  ELSE
    RAISE NOTICE 'Constraint fk_users_auth_user already exists, skipping';
  END IF;
END $$;

-- Step 5: Drop the unique constraint on email (if it exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_email_key'
  ) THEN
    ALTER TABLE users DROP CONSTRAINT users_email_key;
    RAISE NOTICE 'Dropped unique constraint users_email_key';
  ELSE
    RAISE NOTICE 'Constraint users_email_key does not exist, skipping';
  END IF;
END $$;

-- Step 6: Add unique constraint on (auth_user_id, role) 
-- This ensures one auth user can have at most one patient profile and one family profile
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_auth_user_role_unique'
  ) THEN
    ALTER TABLE users 
    ADD CONSTRAINT users_auth_user_role_unique UNIQUE (auth_user_id, role);
    RAISE NOTICE 'Created composite unique constraint users_auth_user_role_unique';
  ELSE
    RAISE NOTICE 'Constraint users_auth_user_role_unique already exists, skipping';
  END IF;
END $$;

-- Step 7: Create indexes for efficient lookups (IF NOT EXISTS is safe)
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_users_email_role ON users(email, role);

-- Step 8: Add comments
COMMENT ON COLUMN users.auth_user_id IS 'Reference to Supabase Auth user - same auth user can have multiple profiles (one per role)';
