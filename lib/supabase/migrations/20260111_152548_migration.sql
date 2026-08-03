-- Migration: Rename groups table to communities and update related references
-- This migration is now a no-op because the communities table already exists
-- The actual cleanup will be done by a later migration (20260111_165000)

DO $$
BEGIN
  -- Check if both tables exist
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'groups') 
     AND EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'communities') THEN
    RAISE NOTICE 'Both groups and communities tables exist - skipping rename, will be handled by cleanup migration';
    -- Do nothing, let the cleanup migration handle this
  ELSIF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'groups') 
     AND NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'communities') THEN
    -- Only groups exists, safe to rename
    ALTER TABLE groups RENAME TO communities;
    
    -- Rename the members table
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'group_members') THEN
      ALTER TABLE group_members RENAME TO community_members;
      
      -- Add missing columns
      ALTER TABLE community_members 
        ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
        ADD COLUMN IF NOT EXISTS display_name TEXT DEFAULT 'Member';
      
      -- Rename foreign key column
      ALTER TABLE community_members RENAME COLUMN group_id TO community_id;
    END IF;
    
    RAISE NOTICE 'Successfully renamed groups to communities';
  ELSE
    RAISE NOTICE 'Communities table already exists - nothing to do';
  END IF;
END $$;

-- Ensure RLS is enabled
ALTER TABLE communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_members ENABLE ROW LEVEL SECURITY;

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_community_members_user_id ON community_members(user_id);
CREATE INDEX IF NOT EXISTS idx_community_members_community_id ON community_members(community_id);
CREATE INDEX IF NOT EXISTS idx_communities_owner_id ON communities(owner_id);
CREATE INDEX IF NOT EXISTS idx_communities_type ON communities(type);

-- Drop any old/conflicting policies and create fresh ones
DROP POLICY IF EXISTS "Anyone can view communities" ON communities;
DROP POLICY IF EXISTS "Authenticated users can create communities" ON communities;
DROP POLICY IF EXISTS "Community owners can update their communities" ON communities;
DROP POLICY IF EXISTS "Community owners can delete their communities" ON communities;
DROP POLICY IF EXISTS "Anyone can view community members" ON community_members;
DROP POLICY IF EXISTS "Authenticated users can join communities" ON community_members;
DROP POLICY IF EXISTS "Users can update community membership" ON community_members;
DROP POLICY IF EXISTS "Users can leave communities" ON community_members;

-- Create policies for communities
CREATE POLICY "Anyone can view communities" ON communities 
  FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create communities" ON communities 
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Community owners can update their communities" ON communities 
  FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "Community owners can delete their communities" ON communities 
  FOR DELETE USING (auth.uid() = owner_id);

-- Create policies for community_members
CREATE POLICY "Anyone can view community members" ON community_members 
  FOR SELECT USING (true);

CREATE POLICY "Authenticated users can join communities" ON community_members 
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update community membership" ON community_members 
  FOR UPDATE USING (auth.uid() = user_id OR auth.uid() IN (
    SELECT owner_id FROM communities WHERE id = community_id
  ));

CREATE POLICY "Users can leave communities" ON community_members 
  FOR DELETE USING (auth.uid() = user_id);
