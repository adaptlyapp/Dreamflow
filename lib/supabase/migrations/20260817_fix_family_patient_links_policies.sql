-- Migration to fix RLS policies for family_patient_links access
-- The previous migration incorrectly referenced non-existent 'patients' table
-- This fixes policies to properly work with the actual schema structure

-- Drop all broken policies
DROP POLICY IF EXISTS recovery_domains_select_policy ON recovery_domains;
DROP POLICY IF EXISTS recovery_domains_update_policy ON recovery_domains;
DROP POLICY IF EXISTS journeys_select_policy ON journeys;
DROP POLICY IF EXISTS journeys_update_policy ON journeys;
DROP POLICY IF EXISTS phases_select_policy ON phases;
DROP POLICY IF EXISTS phases_update_policy ON phases;
DROP POLICY IF EXISTS journey_milestones_select_policy ON journey_milestones;
DROP POLICY IF EXISTS journey_milestones_update_policy ON journey_milestones;
DROP POLICY IF EXISTS journey_goals_select_policy ON journey_goals;
DROP POLICY IF EXISTS journey_goals_update_policy ON journey_goals;
DROP POLICY IF EXISTS journey_tasks_select_policy ON journey_tasks;
DROP POLICY IF EXISTS journey_tasks_update_policy ON journey_tasks;

-- Recreate correct policies
-- Note: family_patient_links structure is:
--   - family_member_id references family_members(id)
--   - patient_id references users(id) where role='patient'
--   - Need to join through family_members to get auth_user_id

-- Recovery Domains Policies
CREATE POLICY recovery_domains_select_policy ON recovery_domains
  FOR SELECT TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = recovery_domains.user_id
      AND fm.auth_user_id = auth.uid()
    )
  );

CREATE POLICY recovery_domains_update_policy ON recovery_domains
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = recovery_domains.user_id
      AND fm.auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = recovery_domains.user_id
      AND fm.auth_user_id = auth.uid()
    )
  );

-- Journeys Policies
CREATE POLICY journeys_select_policy ON journeys
  FOR SELECT TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = journeys.user_id
      AND fm.auth_user_id = auth.uid()
    )
  );

CREATE POLICY journeys_update_policy ON journeys
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = journeys.user_id
      AND fm.auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = journeys.user_id
      AND fm.auth_user_id = auth.uid()
    )
  );

-- Phases Policies
CREATE POLICY phases_select_policy ON phases
  FOR SELECT TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = phases.user_id
      AND fm.auth_user_id = auth.uid()
    )
  );

CREATE POLICY phases_update_policy ON phases
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = phases.user_id
      AND fm.auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = phases.user_id
      AND fm.auth_user_id = auth.uid()
    )
  );

-- Journey Milestones Policies
CREATE POLICY journey_milestones_select_policy ON journey_milestones
  FOR SELECT TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = journey_milestones.user_id
      AND fm.auth_user_id = auth.uid()
    )
  );

CREATE POLICY journey_milestones_update_policy ON journey_milestones
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = journey_milestones.user_id
      AND fm.auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = journey_milestones.user_id
      AND fm.auth_user_id = auth.uid()
    )
  );

-- Journey Goals Policies
CREATE POLICY journey_goals_select_policy ON journey_goals
  FOR SELECT TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = journey_goals.user_id
      AND fm.auth_user_id = auth.uid()
    )
  );

CREATE POLICY journey_goals_update_policy ON journey_goals
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = journey_goals.user_id
      AND fm.auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = journey_goals.user_id
      AND fm.auth_user_id = auth.uid()
    )
  );

-- Journey Tasks Policies
CREATE POLICY journey_tasks_select_policy ON journey_tasks
  FOR SELECT TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = journey_tasks.user_id
      AND fm.auth_user_id = auth.uid()
    )
  );

CREATE POLICY journey_tasks_update_policy ON journey_tasks
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = journey_tasks.user_id
      AND fm.auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM family_patient_links fpl
      JOIN family_members fm ON fpl.family_member_id = fm.id
      JOIN users u ON fpl.patient_id = u.id
      WHERE u.auth_user_id = journey_tasks.user_id
      AND fm.auth_user_id = auth.uid()
    )
  );
