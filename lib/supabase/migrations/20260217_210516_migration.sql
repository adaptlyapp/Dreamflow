-- Add pain_map column to tracker_entries table
-- This column stores detailed pain location mapping as a JSON array
ALTER TABLE tracker_entries
ADD COLUMN IF NOT EXISTS pain_map JSONB;

-- Add an index on pain_map for better query performance
CREATE INDEX IF NOT EXISTS idx_tracker_entries_pain_map ON tracker_entries USING GIN (pain_map);

-- Add a comment to document the column
COMMENT ON COLUMN tracker_entries.pain_map IS 'Array of pain details with area, type, intensity, and optional notes';
