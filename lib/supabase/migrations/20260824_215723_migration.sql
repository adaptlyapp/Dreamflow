-- Migration: Allow family members to create tracker entries for patients they're linked to
-- This fixes the RLS policy that was preventing family members from logging health data for patients

-- Drop the existing INSERT policy for tracker_entries
DROP POLICY IF EXISTS "Users can create own tracker entries" ON tracker_entries;

-- Create a new INSERT policy that allows:
-- 1. Users to create their own tracker entries (auth.uid() = user_id)
-- 2. Family members to create tracker entries for patients they're linked to
CREATE POLICY "Users and linked family can create tracker entries" 
  ON tracker_entries 
  FOR INSERT 
  WITH CHECK (
    -- Allow users to create their own entries
    auth.uid() = user_id
    OR
    -- Allow family members to create entries for patients they're linked to
    EXISTS (
      SELECT 1 
      FROM family_patient_links 
      WHERE family_patient_links.family_member_id = auth.uid() 
        AND family_patient_links.patient_id = user_id
    )
  );

-- Also update the SELECT policy to allow family members to view patient entries
DROP POLICY IF EXISTS "Users can view own tracker entries" ON tracker_entries;

CREATE POLICY "Users and linked family can view tracker entries" 
  ON tracker_entries 
  FOR SELECT 
  USING (
    -- Allow users to view their own entries
    auth.uid() = user_id
    OR
    -- Allow family members to view entries for patients they're linked to
    EXISTS (
      SELECT 1 
      FROM family_patient_links 
      WHERE family_patient_links.family_member_id = auth.uid() 
        AND family_patient_links.patient_id = user_id
    )
  );

-- Also update the UPDATE policy to allow family members to edit patient entries
DROP POLICY IF EXISTS "Users can update own tracker entries" ON tracker_entries;

CREATE POLICY "Users and linked family can update tracker entries" 
  ON tracker_entries 
  FOR UPDATE 
  USING (
    -- Allow users to update their own entries
    auth.uid() = user_id
    OR
    -- Allow family members to update entries for patients they're linked to
    EXISTS (
      SELECT 1 
      FROM family_patient_links 
      WHERE family_patient_links.family_member_id = auth.uid() 
        AND family_patient_links.patient_id = user_id
    )
  );

-- Also update the DELETE policy to allow family members to delete patient entries
DROP POLICY IF EXISTS "Users can delete own tracker entries" ON tracker_entries;

CREATE POLICY "Users and linked family can delete tracker entries" 
  ON tracker_entries 
  FOR DELETE 
  USING (
    -- Allow users to delete their own entries
    auth.uid() = user_id
    OR
    -- Allow family members to delete entries for patients they're linked to
    EXISTS (
      SELECT 1 
      FROM family_patient_links 
      WHERE family_patient_links.family_member_id = auth.uid() 
        AND family_patient_links.patient_id = user_id
    )
  );
