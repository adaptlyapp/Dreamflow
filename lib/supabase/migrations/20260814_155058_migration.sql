-- Add help_type column to milestones for Goal Breakdown Engine
ALTER TABLE milestones
  ADD COLUMN IF NOT EXISTS help_type TEXT;
