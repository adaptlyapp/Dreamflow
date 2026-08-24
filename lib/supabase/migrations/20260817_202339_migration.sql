-- Migration: Fix family_patient_links foreign key constraints
-- This migration completely rebuilds the family_patient_links table with correct constraints

-- Step 1: Drop the entire table (this will cascade and remove all constraints)
DROP TABLE IF EXISTS family_patient_links CASCADE;

-- Step 2: Recreate the table with correct foreign keys to auth.users
CREATE TABLE family_patient_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_member_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  patient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  patient_name text NOT NULL,
  relationship text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(family_member_id, patient_id)
);

-- Step 3: Enable RLS on the table
ALTER TABLE family_patient_links ENABLE ROW LEVEL SECURITY;

-- Step 4: Create RLS policies
CREATE POLICY "family_patient_links_select_policy" 
  ON family_patient_links FOR SELECT 
  USING (auth.uid() = family_member_id OR auth.uid() = patient_id);

CREATE POLICY "family_patient_links_insert_policy" 
  ON family_patient_links FOR INSERT 
  WITH CHECK (auth.uid() = family_member_id);

CREATE POLICY "family_patient_links_update_policy" 
  ON family_patient_links FOR UPDATE 
  USING (auth.uid() = family_member_id OR auth.uid() = patient_id);

CREATE POLICY "family_patient_links_delete_policy" 
  ON family_patient_links FOR DELETE 
  USING (auth.uid() = family_member_id OR auth.uid() = patient_id);

-- Step 5: Create indexes for performance
CREATE INDEX idx_family_patient_links_family_member_id ON family_patient_links(family_member_id);
CREATE INDEX idx_family_patient_links_patient_id ON family_patient_links(patient_id);
