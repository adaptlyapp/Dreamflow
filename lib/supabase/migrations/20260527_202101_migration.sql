-- Allow same email to have both patient and family profiles
-- Migration: allow_dual_role_accounts
-- Date: 2026-05-27
-- Strategy: 
-- - Add auth_user_id column to track the Supabase Auth user
-- - Keep id as unique primary key (UUID)
-- - Drop email unique constraint
-- - Add unique constraint on (auth_user_id, role) - one auth user can have max one profile per role

-- Step 1: Add auth_user_id column (nullable initially, we'll backfill it)
ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_user_id UUID;

-- Step 2: Backfill auth_user_id with the current id (since currently id = auth user id)
UPDATE users SET auth_user_id = id WHERE auth_user_id IS NULL;

-- Step 3: Make auth_user_id NOT NULL and add foreign key to auth.users
ALTER TABLE users ALTER COLUMN auth_user_id SET NOT NULL;
ALTER TABLE users ADD CONSTRAINT fk_users_auth_user 
  FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Step 4: Drop the unique constraint on email (if it exists)
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

-- Step 5: Add unique constraint on (auth_user_id, role) 
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

-- Step 6: Create indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_users_email_role ON users(email, role);

COMMENT ON COLUMN users.auth_user_id IS 'Reference to Supabase Auth user - same auth user can have multiple profiles (one per role)';
COMMENT ON CONSTRAINT users_auth_user_role_unique ON users IS 'Allows same auth user to have both patient and family profiles';
COMMENT ON TABLE users IS 'User profiles - each profile has unique id, auth_user_id links to auth.users';
