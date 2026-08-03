-- Wellspring Health App - Row Level Security Policies
-- This file documents the existing deployed RLS policies

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospitals ENABLE ROW LEVEL SECURITY;
ALTER TABLE conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE resource_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE resource_suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE resource_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracker_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Users policies
DROP POLICY IF EXISTS "Users can view all profiles" ON users;
CREATE POLICY "Users can view all profiles" ON users FOR SELECT USING (true);
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
CREATE POLICY "Users can insert own profile" ON users FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id) WITH CHECK (true);
DROP POLICY IF EXISTS "Users can delete own profile" ON users;
CREATE POLICY "Users can delete own profile" ON users FOR DELETE USING (auth.uid() = id);

-- Hospitals policies (public read, admin write)
DROP POLICY IF EXISTS "Anyone can view hospitals" ON hospitals;
CREATE POLICY "Anyone can view hospitals" ON hospitals FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users can manage hospitals" ON hospitals;
CREATE POLICY "Authenticated users can manage hospitals" ON hospitals FOR ALL USING (auth.role() = 'authenticated');

-- Conditions policies (public read, admin write)
DROP POLICY IF EXISTS "Anyone can view conditions" ON conditions;
CREATE POLICY "Anyone can view conditions" ON conditions FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users can manage conditions" ON conditions;
CREATE POLICY "Authenticated users can manage conditions" ON conditions FOR ALL USING (auth.role() = 'authenticated');

-- Groups policies
DROP POLICY IF EXISTS "Anyone can view groups" ON groups;
CREATE POLICY "Anyone can view groups" ON groups FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users can create groups" ON groups;
CREATE POLICY "Authenticated users can create groups" ON groups FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Group owners can update their groups" ON groups;
CREATE POLICY "Group owners can update their groups" ON groups FOR UPDATE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Group owners can delete their groups" ON groups;
CREATE POLICY "Group owners can delete their groups" ON groups FOR DELETE USING (auth.uid() = owner_id);

-- Group members policies
DROP POLICY IF EXISTS "Anyone can view group members" ON group_members;
CREATE POLICY "Anyone can view group members" ON group_members FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users can join groups" ON group_members;
CREATE POLICY "Authenticated users can join groups" ON group_members FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Users can leave groups" ON group_members;
CREATE POLICY "Users can leave groups" ON group_members FOR DELETE USING (auth.uid() = user_id);

-- Posts policies
DROP POLICY IF EXISTS "Anyone can view posts" ON posts;
CREATE POLICY "Anyone can view posts" ON posts FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users can create posts" ON posts;
CREATE POLICY "Authenticated users can create posts" ON posts FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authors can update their posts" ON posts;
CREATE POLICY "Authors can update their posts" ON posts FOR UPDATE USING (auth.uid() = author_id);
DROP POLICY IF EXISTS "Authors can delete their posts" ON posts;
CREATE POLICY "Authors can delete their posts" ON posts FOR DELETE USING (auth.uid() = author_id);

-- Post likes policies
DROP POLICY IF EXISTS "Anyone can view post likes" ON post_likes;
CREATE POLICY "Anyone can view post likes" ON post_likes FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users can like posts" ON post_likes;
CREATE POLICY "Authenticated users can like posts" ON post_likes FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Users can unlike their likes" ON post_likes;
CREATE POLICY "Users can unlike their likes" ON post_likes FOR DELETE USING (auth.uid() = user_id);

-- Comments policies
DROP POLICY IF EXISTS "Anyone can view comments" ON comments;
CREATE POLICY "Anyone can view comments" ON comments FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users can create comments" ON comments;
CREATE POLICY "Authenticated users can create comments" ON comments FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authors can update their comments" ON comments;
CREATE POLICY "Authors can update their comments" ON comments FOR UPDATE USING (auth.uid() = author_id);
DROP POLICY IF EXISTS "Authors can delete their comments" ON comments;
CREATE POLICY "Authors can delete their comments" ON comments FOR DELETE USING (auth.uid() = author_id);

-- Resources policies (public read, admin write)
DROP POLICY IF EXISTS "Anyone can view resources" ON resources;
CREATE POLICY "Anyone can view resources" ON resources FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users can manage resources" ON resources;
CREATE POLICY "Authenticated users can manage resources" ON resources FOR ALL USING (auth.role() = 'authenticated');

-- Resource ratings policies (public read, authenticated write)
DROP POLICY IF EXISTS "Anyone can view resource ratings" ON resource_ratings;
CREATE POLICY "Anyone can view resource ratings" ON resource_ratings FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users can manage ratings" ON resource_ratings;
CREATE POLICY "Authenticated users can manage ratings" ON resource_ratings FOR ALL USING (auth.role() = 'authenticated');

-- Resource suggestions policies
DROP POLICY IF EXISTS "Anyone can view approved suggestions" ON resource_suggestions;
CREATE POLICY "Anyone can view approved suggestions" ON resource_suggestions FOR SELECT USING (status = 'approved' OR auth.uid() = created_by);
DROP POLICY IF EXISTS "Authenticated users can create suggestions" ON resource_suggestions;
CREATE POLICY "Authenticated users can create suggestions" ON resource_suggestions FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Creators can update their suggestions" ON resource_suggestions;
CREATE POLICY "Creators can update their suggestions" ON resource_suggestions FOR UPDATE USING (auth.uid() = created_by);

-- Resource applications policies
DROP POLICY IF EXISTS "Users can view own applications" ON resource_applications;
CREATE POLICY "Users can view own applications" ON resource_applications FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Authenticated users can create applications" ON resource_applications;
CREATE POLICY "Authenticated users can create applications" ON resource_applications FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Users can update own applications" ON resource_applications;
CREATE POLICY "Users can update own applications" ON resource_applications FOR UPDATE USING (auth.uid() = user_id);

-- Milestones policies
DROP POLICY IF EXISTS "Users can view own milestones" ON milestones;
CREATE POLICY "Users can view own milestones" ON milestones FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can create own milestones" ON milestones;
CREATE POLICY "Users can create own milestones" ON milestones FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own milestones" ON milestones;
CREATE POLICY "Users can update own milestones" ON milestones FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete own milestones" ON milestones;
CREATE POLICY "Users can delete own milestones" ON milestones FOR DELETE USING (auth.uid() = user_id);

-- Goals policies
DROP POLICY IF EXISTS "Users can view own goals" ON goals;
CREATE POLICY "Users can view own goals" ON goals FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can create own goals" ON goals;
CREATE POLICY "Users can create own goals" ON goals FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own goals" ON goals;
CREATE POLICY "Users can update own goals" ON goals FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete own goals" ON goals;
CREATE POLICY "Users can delete own goals" ON goals FOR DELETE USING (auth.uid() = user_id);

-- Tracker entries policies
DROP POLICY IF EXISTS "Users can view own tracker entries" ON tracker_entries;
CREATE POLICY "Users can view own tracker entries" ON tracker_entries FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can create own tracker entries" ON tracker_entries;
CREATE POLICY "Users can create own tracker entries" ON tracker_entries FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own tracker entries" ON tracker_entries;
CREATE POLICY "Users can update own tracker entries" ON tracker_entries FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete own tracker entries" ON tracker_entries;
CREATE POLICY "Users can delete own tracker entries" ON tracker_entries FOR DELETE USING (auth.uid() = user_id);

-- Achievements policies (public read, admin write)
DROP POLICY IF EXISTS "Anyone can view achievements" ON achievements;
CREATE POLICY "Anyone can view achievements" ON achievements FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users can manage achievements" ON achievements;
CREATE POLICY "Authenticated users can manage achievements" ON achievements FOR ALL USING (auth.role() = 'authenticated');

-- User achievements policies
DROP POLICY IF EXISTS "Users can view own achievements" ON user_achievements;
CREATE POLICY "Users can view own achievements" ON user_achievements FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can create own achievements" ON user_achievements;
CREATE POLICY "Users can create own achievements" ON user_achievements FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own achievements" ON user_achievements;
CREATE POLICY "Users can update own achievements" ON user_achievements FOR UPDATE USING (auth.uid() = user_id);

-- Messages policies
DROP POLICY IF EXISTS "Users can view their messages" ON messages;
CREATE POLICY "Users can view their messages" ON messages FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
DROP POLICY IF EXISTS "Users can send messages" ON messages;
CREATE POLICY "Users can send messages" ON messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
DROP POLICY IF EXISTS "Users can update their sent messages" ON messages;
CREATE POLICY "Users can update their sent messages" ON messages FOR UPDATE USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
DROP POLICY IF EXISTS "Users can delete their sent messages" ON messages;
CREATE POLICY "Users can delete their sent messages" ON messages FOR DELETE USING (auth.uid() = sender_id);
