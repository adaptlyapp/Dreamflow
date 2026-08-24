-- Migration: Fix family_patient_links table triggers that reference non-existent full_name column
-- Created: 2026-08-17 19:57:44
-- Purpose: Remove triggers on family_patient_links table that are causing "record 'new' has no field 'full_name'" error

-- Drop all triggers on family_patient_links table
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT trigger_name 
        FROM information_schema.triggers 
        WHERE event_object_table = 'family_patient_links' 
        AND trigger_schema = 'public'
    LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON family_patient_links CASCADE';
        RAISE NOTICE 'Dropped trigger on family_patient_links: %', r.trigger_name;
    END LOOP;
END $$;

-- Drop all triggers on family_members table (might also have the same issue)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT trigger_name 
        FROM information_schema.triggers 
        WHERE event_object_table = 'family_members' 
        AND trigger_schema = 'public'
    LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON family_members CASCADE';
        RAISE NOTICE 'Dropped trigger on family_members: %', r.trigger_name;
    END LOOP;
END $$;

-- Drop any functions that might be causing the issue
DROP FUNCTION IF EXISTS sync_family_patient_link_metadata() CASCADE;
DROP FUNCTION IF EXISTS update_family_link_full_name() CASCADE;
DROP FUNCTION IF EXISTS handle_family_link_insert() CASCADE;

-- Add comments to document the fix
COMMENT ON TABLE family_patient_links IS 'Links between family members and patients - triggers with full_name references removed';
COMMENT ON TABLE family_members IS 'Family member records - triggers with full_name references removed';
