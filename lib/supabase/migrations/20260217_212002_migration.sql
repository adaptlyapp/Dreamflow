-- Add sign_meta column to tracker_entries table
-- This column stores cryptographic signing metadata as a JSONB object
ALTER TABLE tracker_entries
ADD COLUMN IF NOT EXISTS sign_meta JSONB;

-- Add an index on sign_meta for better query performance
CREATE INDEX IF NOT EXISTS idx_tracker_entries_sign_meta ON tracker_entries USING GIN (sign_meta);

-- Add a comment to document the column
COMMENT ON COLUMN tracker_entries.sign_meta IS 'Cryptographic signing metadata including signature, timestamp, and verification details';
