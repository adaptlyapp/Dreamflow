-- Collaborative Recovery Blueprint (Option 2)
-- Adds blueprint_collaborators join table, updated_by column, and RLS so
-- collaborators (editor/viewer) can access blueprints they were invited to.

-- 1. Add updated_by to recovery_blueprints to support last-write-wins UI.
ALTER TABLE recovery_blueprints
  ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- 2. Collaborators join table.
CREATE TABLE IF NOT EXISTS blueprint_collaborators (
  blueprint_id UUID NOT NULL REFERENCES recovery_blueprints(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('owner','editor','viewer')),
  added_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blueprint_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_blueprint_collaborators_user_id
  ON blueprint_collaborators(user_id);
CREATE INDEX IF NOT EXISTS idx_blueprint_collaborators_blueprint_id
  ON blueprint_collaborators(blueprint_id);

ALTER TABLE blueprint_collaborators ENABLE ROW LEVEL SECURITY;

-- 3. Backfill: every existing blueprint owner becomes an 'owner' collaborator.
INSERT INTO blueprint_collaborators (blueprint_id, user_id, role, added_by)
SELECT id, user_id, 'owner', user_id
FROM recovery_blueprints
ON CONFLICT (blueprint_id, user_id) DO NOTHING;

-- 4. blueprint_collaborators RLS
DROP POLICY IF EXISTS "view collaborators on shared blueprints" ON blueprint_collaborators;
CREATE POLICY "view collaborators on shared blueprints"
  ON blueprint_collaborators FOR SELECT
  USING (
    user_id = auth.uid()
    OR blueprint_id IN (
      SELECT blueprint_id FROM blueprint_collaborators WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "owner manages collaborators" ON blueprint_collaborators;
CREATE POLICY "owner manages collaborators"
  ON blueprint_collaborators FOR INSERT
  WITH CHECK (
    -- Owner of the blueprint can add anyone
    EXISTS (
      SELECT 1 FROM blueprint_collaborators c
      WHERE c.blueprint_id = blueprint_collaborators.blueprint_id
        AND c.user_id = auth.uid()
        AND c.role = 'owner'
    )
    -- OR a user adding themselves (e.g. family auto-link via patient code)
    OR user_id = auth.uid()
  );

DROP POLICY IF EXISTS "owner updates collaborators" ON blueprint_collaborators;
CREATE POLICY "owner updates collaborators"
  ON blueprint_collaborators FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM blueprint_collaborators c
      WHERE c.blueprint_id = blueprint_collaborators.blueprint_id
        AND c.user_id = auth.uid()
        AND c.role = 'owner'
    )
  );

DROP POLICY IF EXISTS "owner removes collaborators" ON blueprint_collaborators;
CREATE POLICY "owner removes collaborators"
  ON blueprint_collaborators FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM blueprint_collaborators c
      WHERE c.blueprint_id = blueprint_collaborators.blueprint_id
        AND c.user_id = auth.uid()
        AND c.role = 'owner'
    )
    OR user_id = auth.uid()  -- a collaborator can remove themselves
  );

-- 5. Replace recovery_blueprints RLS so collaborators (editor/viewer) can access.
DROP POLICY IF EXISTS "Users can view their own recovery blueprints" ON recovery_blueprints;
CREATE POLICY "view blueprint as owner or collaborator"
  ON recovery_blueprints FOR SELECT
  USING (
    auth.uid() = user_id
    OR id IN (
      SELECT blueprint_id FROM blueprint_collaborators WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update their own recovery blueprints" ON recovery_blueprints;
CREATE POLICY "update blueprint as owner or editor"
  ON recovery_blueprints FOR UPDATE
  USING (
    auth.uid() = user_id
    OR id IN (
      SELECT blueprint_id FROM blueprint_collaborators
      WHERE user_id = auth.uid() AND role IN ('owner','editor')
    )
  )
  WITH CHECK (
    auth.uid() = user_id
    OR id IN (
      SELECT blueprint_id FROM blueprint_collaborators
      WHERE user_id = auth.uid() AND role IN ('owner','editor')
    )
  );
-- INSERT and DELETE policies for recovery_blueprints remain owner-only.

-- 6. Realtime: ensure the table is included in the supabase_realtime publication.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'recovery_blueprints'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE recovery_blueprints';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'blueprint_collaborators'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE blueprint_collaborators';
  END IF;
END $$;
