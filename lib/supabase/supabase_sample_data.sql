CREATE OR REPLACE FUNCTION insert_user_to_auth(
    email text,
    password text
) RETURNS UUID AS $$
DECLARE
  user_id uuid;
  encrypted_pw text;
BEGIN
  user_id := gen_random_uuid();
  encrypted_pw := crypt(password, gen_salt('bf'));
  
  INSERT INTO auth.users
    (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES
    (gen_random_uuid(), user_id, 'authenticated', 'authenticated', email, encrypted_pw, '2023-05-03 19:41:43.585805+00', '2023-04-22 13:10:03.275387+00', '2023-04-22 13:10:31.458239+00', '{"provider":"email","providers":["email"]}', '{}', '2023-05-03 19:41:43.580424+00', '2023-05-03 19:41:43.585948+00', '', '', '', '');
  
  INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  VALUES
    (gen_random_uuid(), user_id, format('{"sub":"%s","email":"%s"}', user_id::text, email)::jsonb, 'email', '2023-05-03 19:41:43.582456+00', '2023-05-03 19:41:43.582497+00', '2023-05-03 19:41:43.582497+00');
  
  RETURN user_id;
END;
$$ LANGUAGE plpgsql;


SELECT insert_user_to_auth('alice@example.com', 'password123');
SELECT insert_user_to_auth('bob@example.com', 'password123');
SELECT insert_user_to_auth('charlie@example.com', 'password123');
SELECT insert_user_to_auth('diana@example.com', 'password123');
SELECT insert_user_to_auth('eve@example.com', 'password123');
SELECT insert_user_to_auth('frank@example.com', 'password123');
SELECT insert_user_to_auth('grace@example.com', 'password123');
SELECT insert_user_to_auth('heidi@example.com', 'password123');
SELECT insert_user_to_auth('ivan@example.com', 'password123');
SELECT insert_user_to_auth('judy@example.com', 'password123');


INSERT INTO public.users (id, name, email, profile_image_url, patient_code, role, onboarding_completed, conditions, diagnosis_date, interests, preferences)
SELECT
    (SELECT id FROM auth.users WHERE email = 'alice@example.com'),
    'Alice Smith',
    'alice@example.com',
    'https://picsum.photos/id/1005/200/300',
    'PSMITH001',
    'patient',
    true,
    ARRAY['Multiple Sclerosis', 'Chronic Pain'],
    '2022-01-15 10:00:00+00',
    ARRAY['Yoga', 'Hiking', 'Reading'],
    '{"notifications": {"email": true, "push": true}}'::jsonb
UNION ALL
SELECT
    (SELECT id FROM auth.users WHERE email = 'bob@example.com'),
    'Bob Johnson',
    'bob@example.com',
    'https://picsum.photos/id/1006/200/300',
    'BJOHNSON002',
    'patient',
    true,
    ARRAY['Spinal Cord Injury'],
    '2021-05-20 14:30:00+00',
    ARRAY['Gaming', 'Cooking'],
    '{"theme": "dark"}'::jsonb
UNION ALL
SELECT
    (SELECT id FROM auth.users WHERE email = 'charlie@example.com'),
    'Charlie Brown',
    'charlie@example.com',
    'https://picsum.photos/id/1008/200/300',
    'CBROWN003',
    'patient',
    true,
    ARRAY['Parkinson''s Disease'],
    '2023-03-10 09:00:00+00',
    ARRAY['Gardening', 'Music'],
    '{"language": "en"}'::jsonb
UNION ALL
SELECT
    (SELECT id FROM auth.users WHERE email = 'diana@example.com'),
    'Diana Prince',
    'diana@example.com',
    'https://picsum.photos/id/1011/200/300',
    'DPRINCE004',
    'patient',
    true,
    ARRAY['Stroke Recovery'],
    '2022-11-01 11:45:00+00',
    ARRAY['Swimming', 'Art'],
    '{"privacy": {"data_sharing": false}}'::jsonb
UNION ALL
SELECT
    (SELECT id FROM auth.users WHERE email = 'eve@example.com'),
    'Eve Adams',
    'eve@example.com',
    'https://picsum.photos/id/1012/200/300',
    'EADAMS005',
    'patient',
    true,
    ARRAY['Multiple Sclerosis'],
    '2020-08-25 16:00:00+00',
    ARRAY['Reading', 'Writing'],
    '{"notifications": {"email": false}}'::jsonb
UNION ALL
SELECT
    (SELECT id FROM auth.users WHERE email = 'frank@example.com'),
    'Frank White',
    'frank@example.com',
    'https://picsum.photos/id/1015/200/300',
    'FWHITE006',
    'patient',
    true,
    ARRAY['Chronic Pain'],
    '2023-01-01 08:00:00+00',
    ARRAY['Running', 'Photography'],
    '{"theme": "light"}'::jsonb
UNION ALL
SELECT
    (SELECT id FROM auth.users WHERE email = 'grace@example.com'),
    'Grace Hopper',
    'grace@example.com',
    'https://picsum.photos/id/1016/200/300',
    'GHOPPER007',
    'patient',
    true,
    ARRAY['Spinal Cord Injury'],
    '2021-03-15 13:00:00+00',
    ARRAY['Coding', 'Board Games'],
    '{"language": "es"}'::jsonb
UNION ALL
SELECT
    (SELECT id FROM auth.users WHERE email = 'heidi@example.com'),
    'Heidi Klum',
    'heidi@example.com',
    'https://picsum.photos/id/1018/200/300',
    'HKLUM008',
    'patient',
    true,
    ARRAY['Parkinson''s Disease'],
    '2022-07-07 10:15:00+00',
    ARRAY['Fashion', 'Travel'],
    '{"privacy": {"data_sharing": true}}'::jsonb
UNION ALL
SELECT
    (SELECT id FROM auth.users WHERE email = 'ivan@example.com'),
    'Ivan Petrov',
    'ivan@example.com',
    'https://picsum.photos/id/1020/200/300',
    'IPETROV009',
    'patient',
    true,
    ARRAY['Stroke Recovery'],
    '2023-02-20 15:00:00+00',
    ARRAY['Chess', 'Cooking'],
    '{"notifications": {"push": false}}'::jsonb
UNION ALL
SELECT
    (SELECT id FROM auth.users WHERE email = 'judy@example.com'),
    'Judy Garland',
    'judy@example.com',
    'https://picsum.photos/id/1021/200/300',
    'JGARLAND010',
    'patient',
    true,
    ARRAY['Multiple Sclerosis'],
    '2020-01-01 09:00:00+00',
    ARRAY['Singing', 'Movies'],
    '{"theme": "dark"}'::jsonb;


INSERT INTO public.hospitals (id, name, city, metro, brand_primary, brand_secondary, brand_tertiary)
SELECT gen_random_uuid(), 'Wellspring Medical Center', 'New York', 'NYC Metro', 1, 2, 3
UNION ALL
SELECT gen_random_uuid(), 'City General Hospital', 'Los Angeles', 'LA Metro', 4, 5, 6
UNION ALL
SELECT gen_random_uuid(), 'Community Health Clinic', 'Chicago', 'Chicago Metro', 7, 8, 9
UNION ALL
SELECT gen_random_uuid(), 'St. Jude''s Rehabilitation', 'Houston', 'Houston Metro', 10, 11, 12
UNION ALL
SELECT gen_random_uuid(), 'Northern Star Hospital', 'Seattle', 'Seattle Metro', 13, 14, 15;


INSERT INTO public.conditions (id, name, description, symptoms, daily_adjustments, resources, ai_generated, timeline, related_groups)
SELECT
    gen_random_uuid(),
    'Multiple Sclerosis',
    'A chronic disease that affects the brain and spinal cord, leading to symptoms such as fatigue, numbness, and difficulty with balance.',
    ARRAY['Fatigue', 'Numbness', 'Vision problems', 'Muscle weakness', 'Dizziness'],
    ARRAY['Regular exercise', 'Balanced diet', 'Stress management', 'Medication adherence'],
    ARRAY['MS Society', 'Neurology Clinic'],
    false,
    '{"phases": [{"name": "Diagnosis", "duration": "1 month"}, {"name": "Treatment Initiation", "duration": "3 months"}]}'::jsonb,
    ARRAY['MS Support Group', 'Neurological Health']
UNION ALL
SELECT
    gen_random_uuid(),
    'Spinal Cord Injury',
    'Damage to the spinal cord that can result in a loss of function, such as mobility or sensation.',
    ARRAY['Loss of movement', 'Loss of sensation', 'Spasms', 'Pain', 'Bladder/bowel dysfunction'],
    ARRAY['Physical therapy', 'Occupational therapy', 'Pain management', 'Adaptive equipment'],
    ARRAY['SCI Foundation', 'Rehabilitation Center'],
    false,
    '{"phases": [{"name": "Acute Care", "duration": "2 weeks"}, {"name": "Rehabilitation", "duration": "6 months"}]}'::jsonb,
    ARRAY['SCI Warriors', 'Mobility Matters']
UNION ALL
SELECT
    gen_random_uuid(),
    'Chronic Pain',
    'Persistent pain that lasts for more than three months, often interfering with daily activities.',
    ARRAY['Constant aching', 'Burning sensation', 'Stiffness', 'Fatigue', 'Sleep disturbances'],
    ARRAY['Mindfulness', 'Gentle exercise', 'Medication management', 'Therapy'],
    ARRAY['Pain Management Clinic', 'Support Groups'],
    false,
    '{"phases": [{"name": "Assessment", "duration": "1 month"}, {"name": "Intervention", "duration": "ongoing"}]}'::jsonb,
    ARRAY['Pain Relief Community', 'Living with Chronic Pain']
UNION ALL
SELECT
    gen_random_uuid(),
    'Parkinson''s Disease',
    'A progressive disorder of the nervous system that affects movement, often including tremors.',
    ARRAY['Tremor', 'Bradykinesia', 'Rigidity', 'Postural instability', 'Speech changes'],
    ARRAY['Medication schedule', 'Physical therapy', 'Speech therapy', 'Dietary adjustments'],
    ARRAY['Parkinson''s Foundation', 'Movement Disorder Clinic'],
    false,
    '{"phases": [{"name": "Early Stage", "duration": "2-5 years"}, {"name": "Mid Stage", "duration": "5-10 years"}]}'::jsonb,
    ARRAY['Parkinson''s Support', 'Movement Matters']
UNION ALL
SELECT
    gen_random_uuid(),
    'Stroke Recovery',
    'The process of regaining abilities lost due to a stroke, such as speech, movement, and cognitive functions.',
    ARRAY['Weakness on one side', 'Speech difficulty', 'Vision changes', 'Balance problems', 'Memory issues'],
    ARRAY['Rehabilitation exercises', 'Speech therapy', 'Occupational therapy', 'Cognitive training'],
    ARRAY['Stroke Association', 'Rehabilitation Hospital'],
    false,
    '{"phases": [{"name": "Acute Recovery", "duration": "3 months"}, {"name": "Long-term Rehabilitation", "duration": "ongoing"}]}'::jsonb,
    ARRAY['Stroke Survivors', 'Road to Recovery'];


INSERT INTO public.groups (id, name, description, image_url, type, related_condition, member_count, privacy, owner_id, owner_name)
SELECT
    gen_random_uuid(),
    'MS Support Group',
    'A community for individuals living with Multiple Sclerosis to share experiences and support each other.',
    'https://picsum.photos/id/237/200/300',
    'support',
    'Multiple Sclerosis',
    3,
    'open',
    (SELECT id FROM public.users WHERE email = 'alice@example.com'),
    'Alice Smith'
UNION ALL
SELECT
    gen_random_uuid(),
    'SCI Warriors',
    'For those navigating life with a Spinal Cord Injury, offering advice, resources, and camaraderie.',
    'https://picsum.photos/id/238/200/300',
    'support',
    'Spinal Cord Injury',
    2,
    'open',
    (SELECT id FROM public.users WHERE email = 'bob@example.com'),
    'Bob Johnson'
UNION ALL
SELECT
    gen_random_uuid(),
    'Pain Relief Community',
    'Discuss strategies and share tips for managing chronic pain effectively.',
    'https://picsum.photos/id/239/200/300',
    'support',
    'Chronic Pain',
    2,
    'open',
    (SELECT id FROM public.users WHERE email = 'frank@example.com'),
    'Frank White'
UNION ALL
SELECT
    gen_random_uuid(),
    'Healthy Living Tips',
    'General wellness group for all users, focusing on healthy habits and positive lifestyle.',
    'https://picsum.photos/id/240/200/300',
    'general',
    NULL,
    4,
    'open',
    (SELECT id FROM public.users WHERE email = 'diana@example.com'),
    'Diana Prince'
UNION ALL
SELECT
    gen_random_uuid(),
    'Parkinson''s Support',
    'A safe space for individuals with Parkinson''s Disease and their caregivers.',
    'https://picsum.photos/id/241/200/300',
    'support',
    'Parkinson''s Disease',
    1,
    'private',
    (SELECT id FROM public.users WHERE email = 'charlie@example.com'),
    'Charlie Brown';


INSERT INTO public.group_members (id, group_id, user_id, status)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.groups WHERE name = 'MS Support Group'),
    (SELECT id FROM public.users WHERE email = 'alice@example.com'),
    'approved'
UNION ALL
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.groups WHERE name = 'MS Support Group'),
    (SELECT id FROM public.users WHERE email = 'eve@example.com'),
    'approved'
UNION ALL
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.groups WHERE name = 'MS Support Group'),
    (SELECT id FROM public.users WHERE email = 'judy@example.com'),
    'approved'
UNION ALL
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.groups WHERE name = 'SCI Warriors'),
    (SELECT id FROM public.users WHERE email = 'bob@example.com'),
    'approved'
UNION ALL
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.groups WHERE name = 'SCI Warriors'),
    (SELECT id FROM public.users WHERE email = 'grace@example.com'),
    'approved'
UNION ALL
SELECT