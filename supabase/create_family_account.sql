-- Create family account for emily711g@gmail.com
-- Run this in your Supabase SQL Editor

-- Step 1: Find the auth user ID
-- This will show you the auth_user_id for emily711g@gmail.com
SELECT id, email FROM auth.users WHERE email = 'emily711g@gmail.com';

-- Step 2: Insert family profile into users table
-- Replace 'YOUR_AUTH_USER_ID' with the ID from Step 1
INSERT INTO public.users (
  id,
  auth_user_id,
  name,
  email,
  role,
  onboarding_completed,
  conditions,
  interests,
  preferences,
  created_at,
  updated_at
)
VALUES (
  gen_random_uuid(), -- Generate a new UUID for the profile
  'YOUR_AUTH_USER_ID', -- Replace with actual auth user ID from Step 1
  'Emily',
  'emily711g@gmail.com',
  'family',
  false, -- Set to true if you want to skip onboarding
  '[]'::jsonb,
  '[]'::jsonb,
  '{}'::jsonb,
  NOW(),
  NOW()
)
ON CONFLICT (auth_user_id, role) DO UPDATE SET
  updated_at = NOW();

-- Step 3: Verify the profile was created
SELECT id, email, role, auth_user_id FROM public.users WHERE email = 'emily711g@gmail.com' AND role = 'family';
