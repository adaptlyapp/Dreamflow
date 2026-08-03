-- Add medications column to users table
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS medications JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN users.medications IS 'List of user medications with name, dosage, and scheduled times';
