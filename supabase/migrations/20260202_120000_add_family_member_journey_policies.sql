-- Migration: Add RLS policies for family members to manage their own milestones and goals
-- This allows family members to have their own separate journey with milestones and goals

-- Enable RLS on milestones table (if not already enabled)
ALTER TABLE milestones ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own milestones" ON milestones;
DROP POLICY IF EXISTS "Users can insert their own milestones" ON milestones;
DROP POLICY IF EXISTS "Users can update their own milestones" ON milestones;
DROP POLICY IF EXISTS "Users can delete their own milestones" ON milestones;
DROP POLICY IF EXISTS "Family members can view patient milestones" ON milestones;

-- Allow users (patients and family members) to view their own milestones
CREATE POLICY "Users can view their own milestones"
ON milestones FOR SELECT
USING (
  auth.uid() IS NOT NULL 
  AND user_id IN (
    SELECT id FROM users WHERE auth_user_id = auth.uid()
  )
);

-- Allow users to insert their own milestones
CREATE POLICY "Users can insert their own milestones"
ON milestones FOR INSERT
WITH CHECK (
  auth.uid() IS NOT NULL 
  AND user_id IN (
    SELECT id FROM users WHERE auth_user_id = auth.uid()
  )
);

-- Allow users to update their own milestones
CREATE POLICY "Users can update their own milestones"
ON milestones FOR UPDATE
USING (
  auth.uid() IS NOT NULL 
  AND user_id IN (
    SELECT id FROM users WHERE auth_user_id = auth.uid()
  )
);

-- Allow users to delete their own milestones
CREATE POLICY "Users can delete their own milestones"
ON milestones FOR DELETE
USING (
  auth.uid() IS NOT NULL 
  AND user_id IN (
    SELECT id FROM users WHERE auth_user_id = auth.uid()
  )
);

-- Enable RLS on goals table (if not already enabled)
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own goals" ON goals;
DROP POLICY IF EXISTS "Users can insert their own goals" ON goals;
DROP POLICY IF EXISTS "Users can update their own goals" ON goals;
DROP POLICY IF EXISTS "Users can delete their own goals" ON goals;
DROP POLICY IF EXISTS "Family members can view patient goals" ON goals;

-- Allow users (patients and family members) to view their own goals
CREATE POLICY "Users can view their own goals"
ON goals FOR SELECT
USING (
  auth.uid() IS NOT NULL 
  AND user_id IN (
    SELECT id FROM users WHERE auth_user_id = auth.uid()
  )
);

-- Allow users to insert their own goals
CREATE POLICY "Users can insert their own goals"
ON goals FOR INSERT
WITH CHECK (
  auth.uid() IS NOT NULL 
  AND user_id IN (
    SELECT id FROM users WHERE auth_user_id = auth.uid()
  )
);

-- Allow users to update their own goals
CREATE POLICY "Users can update their own goals"
ON goals FOR UPDATE
USING (
  auth.uid() IS NOT NULL 
  AND user_id IN (
    SELECT id FROM users WHERE auth_user_id = auth.uid()
  )
);

-- Allow users to delete their own goals
CREATE POLICY "Users can delete their own goals"
ON goals FOR DELETE
USING (
  auth.uid() IS NOT NULL 
  AND user_id IN (
    SELECT id FROM users WHERE auth_user_id = auth.uid()
  )
);
