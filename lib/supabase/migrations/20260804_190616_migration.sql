-- Migration: Add 5-layer journey system tables for ARIE-generated personalized recovery pathways
-- Created: 2026-08-04

-- ══════════════════════════════════════════════════════════════════════════════
-- RECOVERY DOMAINS TABLE (Track patient progress across 12 standardized domains)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS recovery_domains (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- mobility, selfCare, bowelBladder, skinIntegrity, etc.
  completed_phases INTEGER DEFAULT 0,
  total_phases INTEGER DEFAULT 0,
  last_activity_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, type)
);

CREATE INDEX IF NOT EXISTS idx_recovery_domains_user_id ON recovery_domains(user_id);
CREATE INDEX IF NOT EXISTS idx_recovery_domains_type ON recovery_domains(type);

-- ══════════════════════════════════════════════════════════════════════════════
-- JOURNEYS TABLE (Top-level: Complete recovery pathway for a condition/domain)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS journeys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  condition_id TEXT NOT NULL, -- Slugified condition name (e.g., 'adhd', 'multiple-sclerosis')
  title TEXT NOT NULL,
  description TEXT,
  domain_type TEXT NOT NULL, -- mobility, bowelBladder, etc.
  status TEXT NOT NULL DEFAULT 'notStarted', -- notStarted, inProgress, completed, skipped, blocked
  "order" INTEGER DEFAULT 0,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_journeys_user_id ON journeys(user_id);
CREATE INDEX IF NOT EXISTS idx_journeys_condition_id ON journeys(condition_id);
CREATE INDEX IF NOT EXISTS idx_journeys_domain_type ON journeys(domain_type);
CREATE INDEX IF NOT EXISTS idx_journeys_status ON journeys(status);

-- ══════════════════════════════════════════════════════════════════════════════
-- PHASES TABLE (Second level: Hospital, Post-Discharge, Outpatient, Long-Term)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS phases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  journey_id UUID NOT NULL REFERENCES journeys(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  "order" INTEGER DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'notStarted',
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_phases_journey_id ON phases(journey_id);
CREATE INDEX IF NOT EXISTS idx_phases_user_id ON phases(user_id);
CREATE INDEX IF NOT EXISTS idx_phases_status ON phases(status);

-- ══════════════════════════════════════════════════════════════════════════════
-- JOURNEY MILESTONES TABLE (Third level: Major checkpoints with education)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS journey_milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phase_id UUID NOT NULL REFERENCES phases(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  "order" INTEGER DEFAULT 0,
  priority TEXT DEFAULT 'medium', -- critical, high, medium, low
  status TEXT NOT NULL DEFAULT 'notStarted',
  due_date TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  education_content TEXT, -- Rich text/markdown educational content
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_journey_milestones_phase_id ON journey_milestones(phase_id);
CREATE INDEX IF NOT EXISTS idx_journey_milestones_user_id ON journey_milestones(user_id);
CREATE INDEX IF NOT EXISTS idx_journey_milestones_status ON journey_milestones(status);
CREATE INDEX IF NOT EXISTS idx_journey_milestones_priority ON journey_milestones(priority);
CREATE INDEX IF NOT EXISTS idx_journey_milestones_due_date ON journey_milestones(due_date);

-- ══════════════════════════════════════════════════════════════════════════════
-- JOURNEY GOALS TABLE (Fourth level: Measurable outcomes within milestones)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS journey_goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id UUID NOT NULL REFERENCES journey_milestones(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  "order" INTEGER DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'notStarted',
  target_value INTEGER DEFAULT 1,
  current_value INTEGER DEFAULT 0,
  unit TEXT, -- 'times', 'minutes', 'days', etc.
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_journey_goals_milestone_id ON journey_goals(milestone_id);
CREATE INDEX IF NOT EXISTS idx_journey_goals_user_id ON journey_goals(user_id);
CREATE INDEX IF NOT EXISTS idx_journey_goals_status ON journey_goals(status);

-- ══════════════════════════════════════════════════════════════════════════════
-- JOURNEY TASKS TABLE (Fifth level: Actionable steps within goals)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS journey_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id UUID NOT NULL REFERENCES journey_goals(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  "order" INTEGER DEFAULT 0,
  completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  due_date TIMESTAMPTZ,
  assigned_to UUID, -- CareTeamMember ID (optional)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_journey_tasks_goal_id ON journey_tasks(goal_id);
CREATE INDEX IF NOT EXISTS idx_journey_tasks_user_id ON journey_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_journey_tasks_completed ON journey_tasks(completed);
CREATE INDEX IF NOT EXISTS idx_journey_tasks_due_date ON journey_tasks(due_date);

-- ══════════════════════════════════════════════════════════════════════════════
-- ROW-LEVEL SECURITY POLICIES
-- ══════════════════════════════════════════════════════════════════════════════

-- Recovery Domains Policies
ALTER TABLE recovery_domains ENABLE ROW LEVEL SECURITY;

CREATE POLICY recovery_domains_select_policy ON recovery_domains
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = recovery_domains.user_id 
    AND family_member_id = auth.uid()
  ));

CREATE POLICY recovery_domains_insert_policy ON recovery_domains
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY recovery_domains_update_policy ON recovery_domains
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = recovery_domains.user_id 
    AND family_member_id = auth.uid()
  ))
  WITH CHECK (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = recovery_domains.user_id 
    AND family_member_id = auth.uid()
  ));

CREATE POLICY recovery_domains_delete_policy ON recovery_domains
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Journeys Policies
ALTER TABLE journeys ENABLE ROW LEVEL SECURITY;

CREATE POLICY journeys_select_policy ON journeys
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = journeys.user_id 
    AND family_member_id = auth.uid()
  ));

CREATE POLICY journeys_insert_policy ON journeys
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY journeys_update_policy ON journeys
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = journeys.user_id 
    AND family_member_id = auth.uid()
  ))
  WITH CHECK (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = journeys.user_id 
    AND family_member_id = auth.uid()
  ));

CREATE POLICY journeys_delete_policy ON journeys
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Phases Policies
ALTER TABLE phases ENABLE ROW LEVEL SECURITY;

CREATE POLICY phases_select_policy ON phases
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = phases.user_id 
    AND family_member_id = auth.uid()
  ));

CREATE POLICY phases_insert_policy ON phases
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY phases_update_policy ON phases
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = phases.user_id 
    AND family_member_id = auth.uid()
  ))
  WITH CHECK (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = phases.user_id 
    AND family_member_id = auth.uid()
  ));

CREATE POLICY phases_delete_policy ON phases
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Journey Milestones Policies
ALTER TABLE journey_milestones ENABLE ROW LEVEL SECURITY;

CREATE POLICY journey_milestones_select_policy ON journey_milestones
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = journey_milestones.user_id 
    AND family_member_id = auth.uid()
  ));

CREATE POLICY journey_milestones_insert_policy ON journey_milestones
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY journey_milestones_update_policy ON journey_milestones
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = journey_milestones.user_id 
    AND family_member_id = auth.uid()
  ))
  WITH CHECK (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = journey_milestones.user_id 
    AND family_member_id = auth.uid()
  ));

CREATE POLICY journey_milestones_delete_policy ON journey_milestones
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Journey Goals Policies
ALTER TABLE journey_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY journey_goals_select_policy ON journey_goals
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = journey_goals.user_id 
    AND family_member_id = auth.uid()
  ));

CREATE POLICY journey_goals_insert_policy ON journey_goals
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY journey_goals_update_policy ON journey_goals
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = journey_goals.user_id 
    AND family_member_id = auth.uid()
  ))
  WITH CHECK (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = journey_goals.user_id 
    AND family_member_id = auth.uid()
  ));

CREATE POLICY journey_goals_delete_policy ON journey_goals
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Journey Tasks Policies
ALTER TABLE journey_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY journey_tasks_select_policy ON journey_tasks
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = journey_tasks.user_id 
    AND family_member_id = auth.uid()
  ));

CREATE POLICY journey_tasks_insert_policy ON journey_tasks
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY journey_tasks_update_policy ON journey_tasks
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = journey_tasks.user_id 
    AND family_member_id = auth.uid()
  ))
  WITH CHECK (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM family_patient_links 
    WHERE patient_id = journey_tasks.user_id 
    AND family_member_id = auth.uid()
  ));

CREATE POLICY journey_tasks_delete_policy ON journey_tasks
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- ══════════════════════════════════════════════════════════════════════════════
-- NOTES:
-- 1. All tables cascade delete when user is deleted
-- 2. Family members can view all journey data via family_patient_links
-- 3. Only the patient (user_id) can create/delete their own journey items
-- 4. Both patient and family members can update journey progress
-- 5. "order" column is quoted because it's a reserved keyword in PostgreSQL
-- ══════════════════════════════════════════════════════════════════════════════
