-- Add created_by_user_id to tracker_entries to track who created each entry
-- This distinguishes entries created by family members from those created by the patient

ALTER TABLE tracker_entries 
ADD COLUMN created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL;

-- Create index for faster lookups
CREATE INDEX idx_tracker_entries_created_by ON tracker_entries(created_by_user_id);

-- Backfill existing entries: set created_by_user_id = user_id (assume patient created their own entries)
UPDATE tracker_entries 
SET created_by_user_id = user_id 
WHERE created_by_user_id IS NULL;

-- Add comment for documentation
COMMENT ON COLUMN tracker_entries.created_by_user_id IS 'User who created this entry (may differ from user_id if a family member logged data for the patient)';
