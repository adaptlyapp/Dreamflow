-- Fix recovery_blueprints visibility regression caused by recursive RLS.
--
-- The previous migration (20260618_183424) defined SELECT/UPDATE policies on
-- recovery_blueprints and blueprint_collaborators that each query
-- blueprint_collaborators. Postgres detects this as infinite recursion at
-- query time, so the patient's own getByUserId() returns NULL ("blueprint
-- disappeared"). We replace those policies with non-recursive SECURITY DEFINER
-- helper functions.

-- 1. Helper: is the current auth user a collaborator on this blueprint?
CREATE OR REPLACE FUNCTION public.is_blueprint_collaborator(bp_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.blueprint_collaborators
    WHERE blueprint_id = bp_id AND user_id = auth.uid()
  );
$$;

-- 2. Helper: is the current auth user an editor/owner on this blueprint?
CREATE OR REPLACE FUNCTION public.is_blueprint_editor(bp_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.blueprint_collaborators
    WHERE blueprint_id = bp_id
      AND user_id = auth.uid()
      AND role IN ('owner','editor')
  );
$$;

-- 3. Helper: is the current auth user the owner on this blueprint?
CREATE OR REPLACE FUNCTION public.is_blueprint_owner(bp_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.blueprint_collaborators
    WHERE blueprint_id = bp_id
      AND user_id = auth.uid()
      AND role = 'owner'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_blueprint_collaborator(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_blueprint_editor(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_blueprint_owner(uuid) TO authenticated;

-- 4. Rewrite recovery_blueprints policies using the helpers (no recursion).
DROP POLICY IF EXISTS "view blueprint as owner or collaborator" ON recovery_blueprints;
CREATE POLICY "view blueprint as owner or collaborator"
  ON recovery_blueprints FOR SELECT
  USING (
    auth.uid() = user_id
    OR public.is_blueprint_collaborator(id)
  );

DROP POLICY IF EXISTS "update blueprint as owner or editor" ON recovery_blueprints;
CREATE POLICY "update blueprint as owner or editor"
  ON recovery_blueprints FOR UPDATE
  USING (
    auth.uid() = user_id
    OR public.is_blueprint_editor(id)
  )
  WITH CHECK (
    auth.uid() = user_id
    OR public.is_blueprint_editor(id)
  );

-- Make sure owner can still INSERT / DELETE their own blueprint.
DROP POLICY IF EXISTS "Users can insert their own recovery blueprints" ON recovery_blueprints;
CREATE POLICY "Users can insert their own recovery blueprints"
  ON recovery_blueprints FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own recovery blueprints" ON recovery_blueprints;
CREATE POLICY "Users can delete their own recovery blueprints"
  ON recovery_blueprints FOR DELETE
  USING (auth.uid() = user_id);

-- 5. Rewrite blueprint_collaborators policies (also recursive previously).
DROP POLICY IF EXISTS "view collaborators on shared blueprints" ON blueprint_collaborators;
CREATE POLICY "view collaborators on shared blueprints"
  ON blueprint_collaborators FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_blueprint_collaborator(blueprint_id)
  );

DROP POLICY IF EXISTS "owner manages collaborators" ON blueprint_collaborators;
CREATE POLICY "owner manages collaborators"
  ON blueprint_collaborators FOR INSERT
  WITH CHECK (
    public.is_blueprint_owner(blueprint_id)
    OR user_id = auth.uid()  -- self-add (family auto-link)
  );

DROP POLICY IF EXISTS "owner updates collaborators" ON blueprint_collaborators;
CREATE POLICY "owner updates collaborators"
  ON blueprint_collaborators FOR UPDATE
  USING (public.is_blueprint_owner(blueprint_id));

DROP POLICY IF EXISTS "owner removes collaborators" ON blueprint_collaborators;
CREATE POLICY "owner removes collaborators"
  ON blueprint_collaborators FOR DELETE
  USING (
    public.is_blueprint_owner(blueprint_id)
    OR user_id = auth.uid()
  );
