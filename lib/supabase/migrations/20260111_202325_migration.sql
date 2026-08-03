-- Add approval_token column to resource_suggestions table
ALTER TABLE resource_suggestions 
ADD COLUMN approval_token TEXT;

-- Add indexes for commonly queried fields
CREATE INDEX IF NOT EXISTS idx_resource_suggestions_approval_token 
ON resource_suggestions(approval_token);

CREATE INDEX IF NOT EXISTS idx_resource_suggestions_status 
ON resource_suggestions(status);

-- Add columns for tracking who submitted and reviewed the suggestion
ALTER TABLE resource_suggestions 
ADD COLUMN IF NOT EXISTS submitted_by_uid UUID REFERENCES users(id),
ADD COLUMN IF NOT EXISTS submitted_by_email TEXT,
ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS rejected_by_uid UUID REFERENCES users(id),
ADD COLUMN IF NOT EXISTS rejected_reason TEXT,
ADD COLUMN IF NOT EXISTS approved_by_uid UUID REFERENCES users(id),
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;
