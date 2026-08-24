-- Fix recovery_blueprints.user_id to reference users.id instead of auth.users.id
-- This allows recovery_blueprints to store the patient profile ID rather than auth user ID
-- Created: 2026-08-24

-- Step 1: Drop the old foreign key constraint
ALTER TABLE recovery_blueprints 
  DROP CONSTRAINT IF EXISTS recovery_blueprints_user_id_fkey;

-- Step 2: Add new foreign key constraint to users table
ALTER TABLE recovery_blueprints
  ADD CONSTRAINT recovery_blueprints_user_id_fkey 
  FOREIGN KEY (user_id) 
  REFERENCES users(id) 
  ON DELETE CASCADE;

-- Step 3: Update RLS policies to work with the new schema
-- The policies need to check if the authenticated user owns the profile referenced by user_id

DROP POLICY IF EXISTS "recovery_blueprints_insert_policy" ON recovery_blueprints;
CREATE POLICY "recovery_blueprints_insert_policy" ON recovery_blueprints
  FOR INSERT
  WITH CHECK (
    -- Users can insert blueprints for their own profiles
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = user_id
        AND users.auth_user_id = auth.uid()
    )
    OR
    -- Family members can insert blueprints for connected patients
    EXISTS (
      SELECT 1 FROM family_patient_links
      WHERE family_patient_links.family_member_id = auth.uid()
        AND family_patient_links.patient_id = user_id
    )
  );

DROP POLICY IF EXISTS "recovery_blueprints_select_policy" ON recovery_blueprints;
CREATE POLICY "recovery_blueprints_select_policy" ON recovery_blueprints
  FOR SELECT
  USING (
    -- Users can view blueprints for their own profiles
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = user_id
        AND users.auth_user_id = auth.uid()
    )
    OR
    -- Family members can view blueprints of connected patients
    EXISTS (
      SELECT 1 FROM family_patient_links
      WHERE family_patient_links.family_member_id = auth.uid()
        AND family_patient_links.patient_id = user_id
    )
  );

DROP POLICY IF EXISTS "recovery_blueprints_update_policy" ON recovery_blueprints;
CREATE POLICY "recovery_blueprints_update_policy" ON recovery_blueprints
  FOR UPDATE
  USING (
    -- Users can update blueprints for their own profiles
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = user_id
        AND users.auth_user_id = auth.uid()
    )
    OR
    -- Family members can update blueprints of connected patients
    EXISTS (
      SELECT 1 FROM family_patient_links
      WHERE family_patient_links.family_member_id = auth.uid()
        AND family_patient_links.patient_id = user_id
    )
  )
  WITH CHECK (
    -- Same check for the new values
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = user_id
        AND users.auth_user_id = auth.uid()
    )
    OR
    EXISTS (
      SELECT 1 FROM family_patient_links
      WHERE family_patient_links.family_member_id = auth.uid()
        AND family_patient_links.patient_id = user_id
    )
  );

DROP POLICY IF EXISTS "Users can delete their own recovery blueprints" ON recovery_blueprints;
CREATE POLICY "recovery_blueprints_delete_policy" ON recovery_blueprints
  FOR DELETE
  USING (
    -- Only users can delete blueprints for their own profiles
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = user_id
        AND users.auth_user_id = auth.uid()
    )
  );

-- Add helpful comment
COMMENT ON COLUMN recovery_blueprints.user_id IS 'References users.id (patient profile ID), not auth.users.id';
