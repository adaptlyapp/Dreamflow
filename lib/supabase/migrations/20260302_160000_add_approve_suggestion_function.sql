-- First, create the resources_curated table if it doesn't exist
CREATE TABLE IF NOT EXISTS resources_curated (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  specialty TEXT[] DEFAULT ARRAY[]::TEXT[],
  location TEXT NOT NULL,
  address TEXT NOT NULL,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  contact_phone TEXT,
  contact_email TEXT,
  website TEXT,
  availability TEXT DEFAULT 'Unknown',
  rating DOUBLE PRECISION DEFAULT 0.0,
  review_count INTEGER DEFAULT 0,
  status TEXT DEFAULT 'approved',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for status filtering
CREATE INDEX IF NOT EXISTS idx_resources_curated_status ON resources_curated(status);

-- Create index for location-based queries
CREATE INDEX IF NOT EXISTS idx_resources_curated_location ON resources_curated(lat, lng);

-- Create RPC function to approve resource suggestion and publish to resources_curated table
-- This function atomically:
-- 1. Inserts the approved resource into the resources_curated table
-- 2. Updates the suggestion status to 'approved'
-- 3. Links the suggestion to the published resource

CREATE OR REPLACE FUNCTION approve_suggestion_and_publish(
  suggestion_id UUID,
  curated_resource JSONB,
  approved_by_uid UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_resource_id UUID;
BEGIN
  -- Insert the curated resource into the resources_curated table
  INSERT INTO resources_curated (
    name,
    type,
    address,
    location,
    lat,
    lng,
    contact_phone,
    contact_email,
    website,
    availability,
    specialty,
    rating,
    review_count,
    status,
    created_at,
    updated_at
  )
  VALUES (
    (curated_resource->>'name')::TEXT,
    (curated_resource->>'type')::TEXT,
    COALESCE((curated_resource->>'address')::TEXT, ''),
    COALESCE((curated_resource->>'location')::TEXT, ''),
    (curated_resource->>'lat')::DOUBLE PRECISION,
    (curated_resource->>'lng')::DOUBLE PRECISION,
    (curated_resource->>'contactPhone')::TEXT,
    (curated_resource->>'contactEmail')::TEXT,
    (curated_resource->>'website')::TEXT,
    COALESCE((curated_resource->>'availability')::TEXT, 'Unknown'),
    CASE 
      WHEN curated_resource->'specialty' IS NOT NULL 
      THEN ARRAY(SELECT jsonb_array_elements_text(curated_resource->'specialty'))
      ELSE ARRAY[]::TEXT[]
    END,
    0.0,
    0,
    'approved',
    NOW(),
    NOW()
  )
  RETURNING id INTO new_resource_id;

  -- Update the suggestion status and link to published resource
  UPDATE resource_suggestions
  SET 
    status = 'approved',
    updated_at = NOW(),
    approved_at = NOW(),
    approved_by_uid = approve_suggestion_and_publish.approved_by_uid,
    published_resource_id = new_resource_id
  WHERE id = suggestion_id;

  -- Return the new resource ID
  RETURN new_resource_id;
END;
$$;

-- Add missing columns to resource_suggestions if they don't exist
ALTER TABLE resource_suggestions 
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS approved_by UUID,
ADD COLUMN IF NOT EXISTS published_resource_id UUID,
ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS rejected_by_uid UUID,
ADD COLUMN IF NOT EXISTS rejected_reason TEXT,
ADD COLUMN IF NOT EXISTS approval_token TEXT,
ADD COLUMN IF NOT EXISTS submitted_by_uid UUID,
ADD COLUMN IF NOT EXISTS submitted_by_email TEXT;

-- Drop any existing foreign key constraints that might be wrong
DO $$ 
BEGIN
  -- Drop constraint on published_resource_id if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'resource_suggestions_published_resource_id_fkey' 
    AND table_name = 'resource_suggestions'
  ) THEN
    ALTER TABLE resource_suggestions DROP CONSTRAINT resource_suggestions_published_resource_id_fkey;
  END IF;
  
  -- Drop constraint on approved_by if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'resource_suggestions_approved_by_fkey' 
    AND table_name = 'resource_suggestions'
  ) THEN
    ALTER TABLE resource_suggestions DROP CONSTRAINT resource_suggestions_approved_by_fkey;
  END IF;
  
  -- Drop constraint on rejected_by_uid if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'resource_suggestions_rejected_by_uid_fkey' 
    AND table_name = 'resource_suggestions'
  ) THEN
    ALTER TABLE resource_suggestions DROP CONSTRAINT resource_suggestions_rejected_by_uid_fkey;
  END IF;
  
  -- Drop constraint on submitted_by_uid if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'resource_suggestions_submitted_by_uid_fkey' 
    AND table_name = 'resource_suggestions'
  ) THEN
    ALTER TABLE resource_suggestions DROP CONSTRAINT resource_suggestions_submitted_by_uid_fkey;
  END IF;
END $$;

-- Clear any invalid published_resource_id references that point to non-existent resources
-- This is safe because these are orphaned references from previous failed migrations
UPDATE resource_suggestions 
SET published_resource_id = NULL 
WHERE published_resource_id IS NOT NULL 
AND NOT EXISTS (
  SELECT 1 FROM resources_curated WHERE id = resource_suggestions.published_resource_id
);

-- Now add the correct foreign key constraints
DO $$
BEGIN
  -- Add constraint on approved_by if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'resource_suggestions_approved_by_fkey' 
    AND table_name = 'resource_suggestions'
  ) THEN
    ALTER TABLE resource_suggestions 
    ADD CONSTRAINT resource_suggestions_approved_by_fkey 
    FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL;
  END IF;

  -- Add constraint on published_resource_id if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'resource_suggestions_published_resource_id_fkey' 
    AND table_name = 'resource_suggestions'
  ) THEN
    ALTER TABLE resource_suggestions 
    ADD CONSTRAINT resource_suggestions_published_resource_id_fkey 
    FOREIGN KEY (published_resource_id) REFERENCES resources_curated(id) ON DELETE SET NULL;
  END IF;

  -- Add constraint on rejected_by_uid if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'resource_suggestions_rejected_by_uid_fkey' 
    AND table_name = 'resource_suggestions'
  ) THEN
    ALTER TABLE resource_suggestions 
    ADD CONSTRAINT resource_suggestions_rejected_by_uid_fkey 
    FOREIGN KEY (rejected_by_uid) REFERENCES users(id) ON DELETE SET NULL;
  END IF;

  -- Add constraint on submitted_by_uid if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'resource_suggestions_submitted_by_uid_fkey' 
    AND table_name = 'resource_suggestions'
  ) THEN
    ALTER TABLE resource_suggestions 
    ADD CONSTRAINT resource_suggestions_submitted_by_uid_fkey 
    FOREIGN KEY (submitted_by_uid) REFERENCES users(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_resource_suggestions_approved_by 
ON resource_suggestions(approved_by);

CREATE INDEX IF NOT EXISTS idx_resource_suggestions_published_resource 
ON resource_suggestions(published_resource_id);

CREATE INDEX IF NOT EXISTS idx_resource_suggestions_submitted_by 
ON resource_suggestions(submitted_by_uid);

-- Add comment to document the function
COMMENT ON FUNCTION approve_suggestion_and_publish IS 'Atomically approves a resource suggestion and publishes it to the resources table';
