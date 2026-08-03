-- Migration: Add recovery_blueprints table
-- Created: 2026-06-08 18:30:06
-- Purpose: Create table for storing patient recovery blueprints with care plans

-- Create the recovery_blueprints table
CREATE TABLE IF NOT EXISTS recovery_blueprints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  patient_profile JSONB NOT NULL DEFAULT '{}'::jsonb,
  care_team JSONB NOT NULL DEFAULT '[]'::jsonb,
  independence_assessment JSONB NOT NULL DEFAULT '{}'::jsonb,
  home_readiness JSONB NOT NULL DEFAULT '{}'::jsonb,
  daily_routines JSONB NOT NULL DEFAULT '[]'::jsonb,
  equipment JSONB NOT NULL DEFAULT '[]'::jsonb,
  supplies JSONB NOT NULL DEFAULT '[]'::jsonb,
  roadmap JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_recovery_blueprints_user_id ON recovery_blueprints(user_id);

-- Enable RLS
ALTER TABLE recovery_blueprints ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (drop first to avoid conflicts)
DROP POLICY IF EXISTS "Users can view their own recovery blueprints" ON recovery_blueprints;
CREATE POLICY "Users can view their own recovery blueprints" 
  ON recovery_blueprints FOR SELECT 
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own recovery blueprints" ON recovery_blueprints;
CREATE POLICY "Users can insert their own recovery blueprints" 
  ON recovery_blueprints FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own recovery blueprints" ON recovery_blueprints;
CREATE POLICY "Users can update their own recovery blueprints" 
  ON recovery_blueprints FOR UPDATE 
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own recovery blueprints" ON recovery_blueprints;
CREATE POLICY "Users can delete their own recovery blueprints" 
  ON recovery_blueprints FOR DELETE 
  USING (auth.uid() = user_id);

-- Add comments for documentation
COMMENT ON TABLE recovery_blueprints IS 'Stores patient recovery blueprints with care plans, team info, and daily routines';
COMMENT ON COLUMN recovery_blueprints.patient_profile IS 'Patient diagnosis, recovery phase, goals, and restrictions (JSONB)';
COMMENT ON COLUMN recovery_blueprints.care_team IS 'Array of care team members with roles and availability (JSONB)';
COMMENT ON COLUMN recovery_blueprints.independence_assessment IS 'Cognitive and physical independence levels (JSONB)';
COMMENT ON COLUMN recovery_blueprints.home_readiness IS 'Home modifications checklist and action items (JSONB)';
COMMENT ON COLUMN recovery_blueprints.daily_routines IS 'Daily care routines (bowel, bladder, therapy, etc.) (JSONB)';
COMMENT ON COLUMN recovery_blueprints.equipment IS 'Durable medical equipment inventory (JSONB)';
COMMENT ON COLUMN recovery_blueprints.supplies IS 'Medical supplies inventory with reorder tracking (JSONB)';
COMMENT ON COLUMN recovery_blueprints.roadmap IS 'Generated recovery roadmap with priorities and warnings (JSONB)';
