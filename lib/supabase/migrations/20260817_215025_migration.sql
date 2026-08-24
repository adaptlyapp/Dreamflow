-- Fix RLS policies for recovery_blueprints to allow family members to create blueprints for their connected patients

-- Drop existing INSERT policy if it exists
DROP POLICY IF EXISTS "Users can insert their own recovery blueprints" ON recovery_blueprints;
DROP POLICY IF EXISTS "recovery_blueprints_insert_policy" ON recovery_blueprints;

-- Create new INSERT policy that allows:
-- 1. Users to create their own blueprints (auth.uid() = user_id)
-- 2. Family members to create blueprints for connected patients
CREATE POLICY "recovery_blueprints_insert_policy" ON recovery_blueprints
  FOR INSERT
  WITH CHECK (
    auth.uid() = user_id  -- Users can insert their own blueprints
    OR
    -- Family members can insert blueprints for connected patients
    EXISTS (
      SELECT 1 FROM family_patient_links
      WHERE family_patient_links.family_member_id = auth.uid()
        AND family_patient_links.patient_id = user_id
    )
  );

-- Also update the SELECT policy to allow family members to view blueprints of connected patients
DROP POLICY IF EXISTS "Users can view their own recovery blueprints" ON recovery_blueprints;
DROP POLICY IF EXISTS "recovery_blueprints_select_policy" ON recovery_blueprints;

CREATE POLICY "recovery_blueprints_select_policy" ON recovery_blueprints
  FOR SELECT
  USING (
    auth.uid() = user_id  -- Users can view their own blueprints
    OR
    -- Family members can view blueprints of connected patients
    EXISTS (
      SELECT 1 FROM family_patient_links
      WHERE family_patient_links.family_member_id = auth.uid()
        AND family_patient_links.patient_id = user_id
    )
  );

-- Update the UPDATE policy to allow family members to update blueprints of connected patients
DROP POLICY IF EXISTS "Users can update their own recovery blueprints" ON recovery_blueprints;
DROP POLICY IF EXISTS "recovery_blueprints_update_policy" ON recovery_blueprints;

CREATE POLICY "recovery_blueprints_update_policy" ON recovery_blueprints
  FOR UPDATE
  USING (
    auth.uid() = user_id  -- Users can update their own blueprints
    OR
    -- Family members can update blueprints of connected patients
    EXISTS (
      SELECT 1 FROM family_patient_links
      WHERE family_patient_links.family_member_id = auth.uid()
        AND family_patient_links.patient_id = user_id
    )
  )
  WITH CHECK (
    auth.uid() = user_id  -- Users can update their own blueprints
    OR
    -- Family members can update blueprints of connected patients
    EXISTS (
      SELECT 1 FROM family_patient_links
      WHERE family_patient_links.family_member_id = auth.uid()
        AND family_patient_links.patient_id = user_id
    )
  );
