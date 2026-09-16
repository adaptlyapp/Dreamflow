-- NOTE: This is a one-off, environment-specific maintenance script.
-- It is intentionally NOT placed in lib/supabase/migrations so it will not
-- be applied automatically on deployment.

UPDATE recovery_blueprints
SET care_team = '[]'::jsonb, updated_at = NOW()
WHERE user_id = (
  SELECT auth_user_id FROM users
  WHERE email = 'adptlyapp@gmail.com' AND role = 'patient'
  LIMIT 1
);
