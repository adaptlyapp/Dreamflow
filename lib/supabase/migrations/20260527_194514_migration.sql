-- Add role column to users table to support patient and family portal separation

-- Add role column with default value 'patient' (for existing users)
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'patient' NOT NULL;

-- Create index for efficient role-based queries
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Update RLS policies to handle both patient and family roles
-- (Existing policies continue to work - this is just documentation that role is now supported)
