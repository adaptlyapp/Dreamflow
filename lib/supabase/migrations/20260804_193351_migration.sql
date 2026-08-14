-- Migration to fix condition_id column type from UUID to TEXT
-- This allows using slugified condition names (e.g., 'adhd', 'multiple-sclerosis')

-- Step 1: Drop existing RLS policies
DROP POLICY IF EXISTS recovery_domains_select_policy ON recovery_domains;
DROP POLICY IF EXISTS recovery_domains_insert_policy ON recovery_domains;
DROP POLICY IF EXISTS recovery_domains_update_policy ON recovery_domains;
DROP POLICY IF EXISTS recovery_domains_delete_policy ON recovery_domains;

DROP POLICY IF EXISTS journeys_select_policy ON journeys;
DROP POLICY IF EXISTS journeys_insert_policy ON journeys;
DROP POLICY IF EXISTS journeys_update_policy ON journeys;
DROP POLICY IF EXISTS journeys_delete_policy ON journeys;

DROP POLICY IF EXISTS phases_select_policy ON phases;
DROP POLICY IF EXISTS phases_insert_policy ON phases;
DROP POLICY IF EXISTS phases_update_policy ON phases;
DROP POLICY IF EXISTS phases_delete_policy ON phases;

DROP POLICY IF EXISTS journey_milestones_select_policy ON journey_milestones;
DROP POLICY IF EXISTS journey_milestones_insert_policy ON journey_milestones;
DROP POLICY IF EXISTS journey_milestones_update_policy ON journey_milestones;
DROP POLICY IF EXISTS journey_milestones_delete_policy ON journey_milestones;

DROP POLICY IF EXISTS journey_goals_select_policy ON journey_goals;
DROP POLICY IF EXISTS journey_goals_insert_policy ON journey_goals;
DROP POLICY IF EXISTS journey_goals_update_policy ON journey_goals;
DROP POLICY IF EXISTS journey_goals_delete_policy ON journey_goals;

DROP POLICY IF EXISTS journey_tasks_select_policy ON journey_tasks;
DROP POLICY IF EXISTS journey_tasks_insert_policy ON journey_tasks;
DROP POLICY IF EXISTS journey_tasks_update_policy ON journey_tasks;
DROP POLICY IF EXISTS journey_tasks_delete_policy ON journey_tasks;

-- Step 2: Alter the journeys table to change condition_id from UUID to TEXT
ALTER TABLE journeys ALTER COLUMN condition_id TYPE TEXT;

-- Step 3: Recreate RLS policies

-- Recovery Domains Policies
CREATE POLICY recovery_domains_select_policy ON recovery_domains
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM family_patient_links
      JOIN patients ON family_patient_links.patient_id = patients.id
      JOIN family_members ON family_patient_links.family_member_id = family_members.id
      WHERE patients.user_id = recovery_domains.user_id
      AND family_members.auth_user_id = auth.uid()
    )
  );

CREATE POLICY recovery_domains_insert_policy ON recovery_domains
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY recovery_domains_update_policy ON recovery_domains
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY recovery_domains_delete_policy ON recovery_domains
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Journeys Policies
CREATE POLICY journeys_select_policy ON journeys
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM family_patient_links
      JOIN patients ON family_patient_links.patient_id = patients.id
      JOIN family_members ON family_patient_links.family_member_id = family_members.id
      WHERE patients.user_id = journeys.user_id
      AND family_members.auth_user_id = auth.uid()
    )
  );

CREATE POLICY journeys_insert_policy ON journeys
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY journeys_update_policy ON journeys
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY journeys_delete_policy ON journeys
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Phases Policies
CREATE POLICY phases_select_policy ON phases
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM family_patient_links
      JOIN patients ON family_patient_links.patient_id = patients.id
      JOIN family_members ON family_patient_links.family_member_id = family_members.id
      WHERE patients.user_id = phases.user_id
      AND family_members.auth_user_id = auth.uid()
    )
  );

CREATE POLICY phases_insert_policy ON phases
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY phases_update_policy ON phases
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY phases_delete_policy ON phases
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Journey Milestones Policies
CREATE POLICY journey_milestones_select_policy ON journey_milestones
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM family_patient_links
      JOIN patients ON family_patient_links.patient_id = patients.id
      JOIN family_members ON family_patient_links.family_member_id = family_members.id
      WHERE patients.user_id = journey_milestones.user_id
      AND family_members.auth_user_id = auth.uid()
    )
  );

CREATE POLICY journey_milestones_insert_policy ON journey_milestones
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY journey_milestones_update_policy ON journey_milestones
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY journey_milestones_delete_policy ON journey_milestones
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Journey Goals Policies
CREATE POLICY journey_goals_select_policy ON journey_goals
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM family_patient_links
      JOIN patients ON family_patient_links.patient_id = patients.id
      JOIN family_members ON family_patient_links.family_member_id = family_members.id
      WHERE patients.user_id = journey_goals.user_id
      AND family_members.auth_user_id = auth.uid()
    )
  );

CREATE POLICY journey_goals_insert_policy ON journey_goals
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY journey_goals_update_policy ON journey_goals
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY journey_goals_delete_policy ON journey_goals
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Journey Tasks Policies
CREATE POLICY journey_tasks_select_policy ON journey_tasks
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM family_patient_links
      JOIN patients ON family_patient_links.patient_id = patients.id
      JOIN family_members ON family_patient_links.family_member_id = family_members.id
      WHERE patients.user_id = journey_tasks.user_id
      AND family_members.auth_user_id = auth.uid()
    )
  );

CREATE POLICY journey_tasks_insert_policy ON journey_tasks
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY journey_tasks_update_policy ON journey_tasks
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY journey_tasks_delete_policy ON journey_tasks
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());
