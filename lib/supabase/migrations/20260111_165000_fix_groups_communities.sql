-- Migration: Fix duplicate groups/communities tables
-- The previous migration failed because both 'groups' and 'communities' tables exist
-- This migration will consolidate the data and remove the duplicate 'groups' table

-- Step 1: Check if groups table exists and has data, migrate it to communities if needed
DO $$
BEGIN
  -- Only proceed if groups table exists
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'groups') THEN
    
    -- Merge any data from groups into communities (if groups has records not in communities)
    INSERT INTO communities (id, name, description, image_url, type, related_condition, member_count, privacy, owner_id, owner_name, created_at, updated_at)
    SELECT id, name, description, image_url, type, related_condition, member_count, privacy, owner_id, owner_name, created_at, updated_at
    FROM groups
    WHERE id NOT IN (SELECT id FROM communities)
    ON CONFLICT (id) DO NOTHING;
    
    -- Check if group_members table exists and migrate data to community_members
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'group_members') THEN
      -- First, ensure all required columns exist in community_members
      ALTER TABLE community_members 
        ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
        ADD COLUMN IF NOT EXISTS display_name TEXT DEFAULT 'Member';
      
      -- Migrate group_members data to community_members
      INSERT INTO community_members (id, community_id, user_id, status, joined_at, role, display_name)
      SELECT 
        id, 
        group_id as community_id, 
        user_id, 
        status, 
        joined_at,
        'member' as role,
        'Member' as display_name
      FROM group_members
      WHERE id NOT IN (SELECT id FROM community_members)
      ON CONFLICT (id) DO NOTHING;
      
      -- Drop old foreign key constraints from group_members
      ALTER TABLE group_members DROP CONSTRAINT IF EXISTS group_members_group_id_fkey1;
      ALTER TABLE group_members DROP CONSTRAINT IF EXISTS group_members_user_id_fkey1;
      
      -- Drop group_members table
      DROP TABLE IF EXISTS group_members CASCADE;
    END IF;
    
    -- Drop old foreign key constraints from groups
    ALTER TABLE groups DROP CONSTRAINT IF EXISTS groups_owner_id_fkey1;
    
    -- Drop the groups table
    DROP TABLE IF EXISTS groups CASCADE;
    
  END IF;
END $$;

-- Step 2: Ensure communities table has proper indexes
CREATE INDEX IF NOT EXISTS idx_communities_owner_id ON communities(owner_id);
CREATE INDEX IF NOT EXISTS idx_communities_type ON communities(type);
CREATE INDEX IF NOT EXISTS idx_community_members_user_id ON community_members(user_id);
CREATE INDEX IF NOT EXISTS idx_community_members_community_id ON community_members(community_id);

-- Step 3: Ensure RLS is enabled on both tables
ALTER TABLE communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_members ENABLE ROW LEVEL SECURITY;

-- Step 4: Drop any old/conflicting policies and create fresh ones
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
