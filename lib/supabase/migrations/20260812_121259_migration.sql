-- Migration: Create plan_timelines table for saving multiple plan versions
-- Description: Adds the plan_timelines table to allow users to save, switch, and restore different versions of their recovery plans

-- =====================================================
-- PLAN_TIMELINES TABLE
-- =====================================================
-- This table stores snapshots of recovery plans (collections of milestones) 
-- allowing users to save different versions, switch between them, and track plan evolution

CREATE TABLE IF NOT EXISTS plan_timelines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  condition_id TEXT NOT NULL REFERENCES conditions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  is_current BOOLEAN DEFAULT false,
  milestones JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_plan_timelines_user_id ON plan_timelines(user_id);
CREATE INDEX IF NOT EXISTS idx_plan_timelines_condition_id ON plan_timelines(condition_id);
CREATE INDEX IF NOT EXISTS idx_plan_timelines_is_current ON plan_timelines(is_current);
CREATE INDEX IF NOT EXISTS idx_plan_timelines_user_condition ON plan_timelines(user_id, condition_id);

-- Partial unique index to ensure only one timeline can be current per user/condition
-- This only applies when is_current = true, allowing multiple non-current timelines
CREATE UNIQUE INDEX IF NOT EXISTS idx_plan_timelines_unique_current 
  ON plan_timelines(user_id, condition_id) 
  WHERE is_current = true;

-- =====================================================
-- ROW-LEVEL SECURITY POLICIES
-- =====================================================

ALTER TABLE plan_timelines ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own plan timelines" ON plan_timelines;
DROP POLICY IF EXISTS "Users can insert their own plan timelines" ON plan_timelines;
DROP POLICY IF EXISTS "Users can update their own plan timelines" ON plan_timelines;
DROP POLICY IF EXISTS "Users can delete their own plan timelines" ON plan_timelines;

-- Create policies - users can only access their own plan timelines
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

-- Add documentation
COMMENT ON TABLE plan_timelines IS 'Stores versioned snapshots of recovery plans for each condition';
COMMENT ON COLUMN plan_timelines.milestones IS 'JSONB array of milestone objects representing a plan snapshot';
COMMENT ON COLUMN plan_timelines.is_current IS 'Flag indicating if this timeline is currently active for the user';
COMMENT ON INDEX idx_plan_timelines_unique_current IS 'Ensures only one timeline per user/condition can be marked as current';
