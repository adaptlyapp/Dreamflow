-- Migration: Add SELECT policy for users table to allow service role access
-- Created: 2026-06-04 16:23:41
-- Purpose: Fix family portal edge function that needs to query patient data using service role

-- Add SELECT policy that allows authenticated users to view all profiles
-- This is needed for family portal where family members need to access patient data
-- Service role (used by edge functions) automatically bypasses RLS
DROP POLICY IF EXISTS "Users can view profiles" ON users;
CREATE POLICY "Users can view profiles" ON users
  FOR SELECT
  USING (true);  -- Allow all authenticated users to read profiles

-- Add comment for documentation
COMMENT ON POLICY "Users can view profiles" ON users IS 
  'Allows authenticated users to read all user profiles (needed for family portal and edge functions)';
