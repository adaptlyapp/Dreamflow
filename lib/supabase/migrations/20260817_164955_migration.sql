-- Migration: Fix users table trigger that references non-existent full_name column
-- Created: 2026-08-17 16:49:55
-- Purpose: Remove or fix any triggers that reference the full_name field which doesn't exist in the users table schema

-- Drop any triggers on users table that might be causing the "full_name" error
-- We'll drop all custom triggers and recreate only the ones we need
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT trigger_name 
        FROM information_schema.triggers 
        WHERE event_object_table = 'users' 
        AND trigger_schema = 'public'
    LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON users CASCADE';
        RAISE NOTICE 'Dropped trigger: %', r.trigger_name;
    END LOOP;
END $$;

-- Drop any functions that might be associated with those triggers
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS sync_user_metadata() CASCADE;
DROP FUNCTION IF EXISTS update_user_full_name() CASCADE;

-- Add a comment to document the fix
COMMENT ON TABLE users IS 'Users table - triggers referencing non-existent full_name column have been removed';
