-- Add profile_id column to milestones and goals tables to support multi-profile accounts
-- This allows the same auth user to have separate milestones/goals for patient and family profiles

-- Add profile_id column to milestones table
ALTER TABLE milestones 
  ADD COLUMN IF NOT EXISTS profile_id UUID;

-- Add profile_id column to goals table  
ALTER TABLE goals 
  ADD COLUMN IF NOT EXISTS profile_id UUID;

-- Update existing records to use user_id as profile_id (for backwards compatibility)
-- This assumes user_id currently stores profile IDs for single-profile users
UPDATE milestones 
SET profile_id = user_id::uuid 
WHERE profile_id IS NULL AND user_id IS NOT NULL;

UPDATE goals 
SET profile_id = user_id::uuid 
WHERE profile_id IS NULL AND user_id IS NOT NULL;

-- Drop old RLS policies
DROP POLICY IF EXISTS "Users can view their own milestones" ON milestones;
DROP POLICY IF EXISTS "Users can insert their own milestones" ON milestones;
DROP POLICY IF EXISTS "Users can update their own milestones" ON milestones;
DROP POLICY IF EXISTS "Users can delete their own milestones" ON milestones;

DROP POLICY IF EXISTS "Users can view their own goals" ON goals;
DROP POLICY IF EXISTS "Users can insert their own goals" ON goals;
DROP POLICY IF EXISTS "Users can update their own goals" ON goals;
DROP POLICY IF EXISTS "Users can delete their own goals" ON goals;

-- Create new RLS policies that check profile_id
-- Users can access milestones/goals that match their auth AND have their profile_id

CREATE POLICY "Users can view milestones for their profiles"
  ON milestones FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id::uuid OR 
    profile_id IN (
      SELECT id FROM users WHERE users.id::text = auth.uid()::text
    )
  );

CREATE POLICY "Users can insert milestones for their profiles"
  ON milestones FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id::uuid OR
    profile_id IN (
      SELECT id FROM users WHERE users.id::text = auth.uid()::text
    )
  );

CREATE POLICY "Users can update milestones for their profiles"
  ON milestones FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = user_id::uuid OR
    profile_id IN (
      SELECT id FROM users WHERE users.id::text = auth.uid()::text
    )
  )
  WITH CHECK (
    auth.uid() = user_id::uuid OR
    profile_id IN (
      SELECT id FROM users WHERE users.id::text = auth.uid()::text
    )
  );

CREATE POLICY "Users can delete milestones for their profiles"
  ON milestones FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id::uuid OR
    profile_id IN (
      SELECT id FROM users WHERE users.id::text = auth.uid()::text
    )
  );

-- Same policies for goals table
CREATE POLICY "Users can view goals for their profiles"
  ON goals FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id::uuid OR
    profile_id IN (
      SELECT id FROM users WHERE users.id::text = auth.uid()::text
    )
  );

CREATE POLICY "Users can insert goals for their profiles"
  ON goals FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id::uuid OR
    profile_id IN (
      SELECT id FROM users WHERE users.id::text = auth.uid()::text
    )
  );

CREATE POLICY "Users can update goals for their profiles"
  ON goals FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = user_id::uuid OR
    profile_id IN (
      SELECT id FROM users WHERE users.id::text = auth.uid()::text
    )
  )
  WITH CHECK (
    auth.uid() = user_id::uuid OR
    profile_id IN (
      SELECT id FROM users WHERE users.id::text = auth.uid()::text
    )
  );

CREATE POLICY "Users can delete goals for their profiles"
  ON goals FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id::uuid OR
    profile_id IN (
      SELECT id FROM users WHERE users.id::text = auth.uid()::text
    )
  );

-- Add comments for documentation
COMMENT ON COLUMN milestones.profile_id IS 'References the user profile (from users table) that owns this milestone. Allows multi-profile support.';
COMMENT ON COLUMN goals.profile_id IS 'References the user profile (from users table) that owns this goal. Allows multi-profile support.';
