-- Migration: Fix RLS policies for multi-profile support (patient + family)
-- Date: 2026-05-29
-- 
-- Problem: The users table RLS policies use auth.uid() = id, which only works for patient-only
-- accounts where the profile ID matches the auth user ID. Family users have a different profile
-- ID (generated UUID), so they can't update their own profiles.
--
-- Solution: Update RLS policies to use auth_user_id instead of id for INSERT and UPDATE checks,
-- allowing all profiles belonging to the same auth user to be created and updated.

-- Drop and recreate the INSERT policy to check auth_user_id
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
CREATE POLICY "Users can insert own profile" ON users 
  FOR INSERT 
  WITH CHECK (auth.uid() = auth_user_id);

-- Drop and recreate the UPDATE policy to check auth_user_id
DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile" ON users 
  FOR UPDATE 
  USING (auth.uid() = auth_user_id) 
  WITH CHECK (auth.uid() = auth_user_id);

-- Keep DELETE policy as is (should also use auth_user_id for consistency)
DROP POLICY IF EXISTS "Users can delete own profile" ON users;
CREATE POLICY "Users can delete own profile" ON users 
  FOR DELETE 
  USING (auth.uid() = auth_user_id);
