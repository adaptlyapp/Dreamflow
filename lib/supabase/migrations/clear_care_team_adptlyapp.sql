UPDATE recovery_blueprints SET care_team = '[]'::jsonb, updated_at = NOW() WHERE user_id = (SELECT auth_user_id FROM users WHERE email = 'adptlyapp@gmail.com' AND role = 'patient' LIMIT 1);
