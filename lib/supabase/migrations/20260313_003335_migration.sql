-- Fix missing RLS policies for milestones, tracker_entries, and goals tables
-- This migration ensures users can access their own data when RLS is enabled

-- =====================================================
-- MILESTONES TABLE RLS POLICIES
-- =====================================================

-- Enable RLS on milestones if not already enabled
ALTER TABLE milestones ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own milestones" ON milestones;
DROP POLICY IF EXISTS "Users can insert their own milestones" ON milestones;
DROP POLICY IF EXISTS "Users can update their own milestones" ON milestones;
DROP POLICY IF EXISTS "Users can delete their own milestones" ON milestones;

-- Create policies for milestones - users can only access their own data
CREATE POLICY "Users can view their own milestones"
  ON milestones FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own milestones"
  ON milestones FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own milestones"
  ON milestones FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own milestones"
  ON milestones FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- =====================================================
-- TRACKER_ENTRIES TABLE RLS POLICIES
-- =====================================================

-- Enable RLS on tracker_entries if not already enabled
ALTER TABLE tracker_entries ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own tracker entries" ON tracker_entries;
DROP POLICY IF EXISTS "Users can insert their own tracker entries" ON tracker_entries;
DROP POLICY IF EXISTS "Users can update their own tracker entries" ON tracker_entries;
DROP POLICY IF EXISTS "Users can delete their own tracker entries" ON tracker_entries;

-- Create policies for tracker_entries - users can only access their own data
CREATE POLICY "Users can view their own tracker entries"
  ON tracker_entries FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tracker entries"
  ON tracker_entries FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tracker entries"
  ON tracker_entries FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tracker entries"
  ON tracker_entries FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- =====================================================
-- GOALS TABLE RLS POLICIES
-- =====================================================

-- Enable RLS on goals if not already enabled
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own goals" ON goals;
DROP POLICY IF EXISTS "Users can insert their own goals" ON goals;
DROP POLICY IF EXISTS "Users can update their own goals" ON goals;
DROP POLICY IF EXISTS "Users can delete their own goals" ON goals;

-- Create policies for goals - users can only access their own data
CREATE POLICY "Users can view their own goals"
  ON goals FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own goals"
  ON goals FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own goals"
  ON goals FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own goals"
  ON goals FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- =====================================================
-- PLAN_TIMELINES TABLE RLS POLICIES (if missing)
-- =====================================================

-- Enable RLS on plan_timelines if not already enabled
ALTER TABLE plan_timelines ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own plan timelines" ON plan_timelines;
DROP POLICY IF EXISTS "Users can insert their own plan timelines" ON plan_timelines;
DROP POLICY IF EXISTS "Users can update their own plan timelines" ON plan_timelines;
DROP POLICY IF EXISTS "Users can delete their own plan timelines" ON plan_timelines;

-- Create policies for plan_timelines - users can only access their own data
CREATE POLICY "Users can view their own plan timelines"
  ON plan_timelines FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own plan timelines"
  ON plan_timelines FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own plan timelines"
  ON plan_timelines FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own plan timelines"
  ON plan_timelines FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Add comments for documentation
COMMENT ON POLICY "Users can view their own milestones" ON milestones IS 'Allow users to read their own milestones';
COMMENT ON POLICY "Users can view their own tracker entries" ON tracker_entries IS 'Allow users to read their own health tracking data';
COMMENT ON POLICY "Users can view their own goals" ON goals IS 'Allow users to read their own goals';
COMMENT ON POLICY "Users can view their own plan timelines" ON plan_timelines IS 'Allow users to read their own plan timelines';
