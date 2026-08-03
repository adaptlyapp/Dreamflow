-- Fix achievement_id column type from UUID to TEXT
-- The achievement_id should store string identifiers like "first_entry", "first_goal"
-- not UUIDs

-- First, drop the foreign key constraint if it exists
ALTER TABLE user_achievements
DROP CONSTRAINT IF EXISTS user_achievements_achievement_id_fkey;

-- Drop the achievements table since we don't need it
-- (achievements are defined in the Flutter code, not database)
DROP TABLE IF EXISTS achievements CASCADE;

-- Change achievement_id column type from UUID to TEXT
ALTER TABLE user_achievements
ALTER COLUMN achievement_id TYPE text USING achievement_id::text;

-- Delete any corrupt records that might exist
-- (records with UUIDs instead of string identifiers)
DELETE FROM user_achievements 
WHERE achievement_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
