-- Add missing health tracking fields to tracker_entries table
-- Migration: add_tracker_entry_fields
-- Date: 2026-01-11

ALTER TABLE tracker_entries
  ADD COLUMN IF NOT EXISTS weight DECIMAL(5, 2),
  ADD COLUMN IF NOT EXISTS temperature DECIMAL(4, 1),
  ADD COLUMN IF NOT EXISTS medications TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS symptoms TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS triggers TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS activities TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS custom_fields JSONB DEFAULT '{}';

COMMENT ON COLUMN tracker_entries.weight IS 'User weight in kg';
COMMENT ON COLUMN tracker_entries.temperature IS 'Body temperature in celsius';
COMMENT ON COLUMN tracker_entries.medications IS 'List of medications taken';
COMMENT ON COLUMN tracker_entries.symptoms IS 'List of symptoms experienced';
COMMENT ON COLUMN tracker_entries.triggers IS 'List of identified triggers';
COMMENT ON COLUMN tracker_entries.activities IS 'List of activities performed';
COMMENT ON COLUMN tracker_entries.custom_fields IS 'Additional custom tracking fields';
