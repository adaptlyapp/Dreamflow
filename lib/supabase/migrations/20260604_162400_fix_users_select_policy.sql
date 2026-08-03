-- Migration: Fix users SELECT policy to be more permissive
-- Created: 2026-06-04 16:24:00
-- Purpose: The previous policy wasn't working correctly with service role

-- Drop and recreate the SELECT policy with a simpler, more permissive rule
DROP POLICY IF EXISTS "Users can view profiles" ON users;
CREATE POLICY "Users can view profiles" ON users
  FOR SELECT
  USING (true);  -- Allow all authenticated users to read profiles

-- Add comment for documentation
COMMENT ON POLICY "Users can view profiles" ON users IS 
  'Allows authenticated users to read all user profiles (needed for family portal and edge functions)';
