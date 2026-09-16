-- Wellspring Health App - Database Schema
-- This file documents the existing deployed schema

-- Users table (linked to auth.users)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  profile_image_url TEXT,
  patient_code TEXT,
  role TEXT DEFAULT 'patient' NOT NULL,
  onboarding_completed BOOLEAN DEFAULT true,
  conditions TEXT[] DEFAULT '{}',
  diagnosis_date TIMESTAMPTZ,
  interests TEXT[] DEFAULT '{}',
  preferences JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Hospitals table
CREATE TABLE IF NOT EXISTS hospitals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  city TEXT,
  metro TEXT,
  brand_primary INTEGER,
  brand_secondary INTEGER,
  brand_tertiary INTEGER,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Conditions table
CREATE TABLE IF NOT EXISTS conditions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  symptoms TEXT[] DEFAULT '{}',
  daily_adjustments TEXT[] DEFAULT '{}',
  resources TEXT[] DEFAULT '{}',
  ai_generated BOOLEAN DEFAULT false,
  timeline JSONB DEFAULT '{}',
  related_groups TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Groups (Communities) table
CREATE TABLE IF NOT EXISTS groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  image_url TEXT,
  type TEXT NOT NULL,
  related_condition TEXT,
  member_count INTEGER DEFAULT 0,
  privacy TEXT DEFAULT 'open',
  owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
  owner_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Group members table
CREATE TABLE IF NOT EXISTS group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'approved',
  joined_at TIMESTAMPTZ DEFAULT now()
);

-- Posts table
CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID REFERENCES users(id) ON DELETE CASCADE,
  author_name TEXT NOT NULL,
  author_image_url TEXT,
  content TEXT NOT NULL,
  image_url TEXT,
  media_url TEXT,
  media_type TEXT,
  community_id UUID REFERENCES groups(id) ON DELETE SET NULL,
  type TEXT NOT NULL,
  related_conditions TEXT[] DEFAULT '{}',
  likes_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Post likes table
CREATE TABLE IF NOT EXISTS post_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(post_id, user_id)
);

-- Comments table
CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  author_id UUID REFERENCES users(id) ON DELETE CASCADE,
  author_name TEXT NOT NULL,
  author_image_url TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Resources table
CREATE TABLE IF NOT EXISTS resources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  specialty TEXT[] DEFAULT '{}',
  location TEXT NOT NULL,
  address TEXT NOT NULL,
  distance DOUBLE PRECISION DEFAULT 0,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  contact_phone TEXT,
  contact_email TEXT,
  website TEXT,
  availability TEXT NOT NULL,
  rating DOUBLE PRECISION DEFAULT 0,
  review_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Resource ratings table
CREATE TABLE IF NOT EXISTS resource_ratings (
  resource_id UUID PRIMARY KEY REFERENCES resources(id) ON DELETE CASCADE,
  avg_google DOUBLE PRECISION DEFAULT 0,
  count_google INTEGER DEFAULT 0,
  avg_app DOUBLE PRECISION DEFAULT 0,
  count_app INTEGER DEFAULT 0,
  avg_combined DOUBLE PRECISION DEFAULT 0,
  count_combined INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Resource suggestions table
CREATE TABLE IF NOT EXISTS resource_suggestions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  address TEXT NOT NULL,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  city TEXT,
  state TEXT,
  postal_code TEXT,
  country TEXT,
  phone TEXT,
  website TEXT,
  contact_email TEXT,
  description TEXT,
  specialties TEXT[] DEFAULT '{}',
  status TEXT DEFAULT 'pending',
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_by_email TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Resource applications table
CREATE TABLE IF NOT EXISTS resource_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  notes TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Milestones table
CREATE TABLE IF NOT EXISTS milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  condition_id UUID REFERENCES conditions(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  due_date TIMESTAMPTZ,
  completed BOOLEAN DEFAULT false,
  "order" INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Plan timelines table
CREATE TABLE IF NOT EXISTS plan_timelines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  condition_id UUID REFERENCES conditions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  milestones JSONB DEFAULT '[]',
  is_current BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS plan_timelines_one_current_per_condition
  ON plan_timelines(user_id, condition_id)
  WHERE is_current = true;

-- Goals table
CREATE TABLE IF NOT EXISTS goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  target_per_period INTEGER NOT NULL,
  progress_this_period INTEGER DEFAULT 0,
  period TEXT NOT NULL,
  last_reset_at TIMESTAMPTZ,
  linked_tracker_key TEXT,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Tracker entries table
CREATE TABLE IF NOT EXISTS tracker_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  date TIMESTAMPTZ NOT NULL,
  pain_level INTEGER,
  mood TEXT,
  spasm_frequency INTEGER,
  bladder_success BOOLEAN,
  bowel_program BOOLEAN,
  sleep_quality INTEGER,
  energy_level INTEGER,
  systolic_bp INTEGER,
  diastolic_bp INTEGER,
  heart_rate INTEGER,
  steps INTEGER,
  weight DECIMAL(5, 2),
  temperature DECIMAL(4, 1),
  notes TEXT,
  medications TEXT[] DEFAULT '{}',
  symptoms TEXT[] DEFAULT '{}',
  triggers TEXT[] DEFAULT '{}',
  activities TEXT[] DEFAULT '{}',
  custom_fields JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Achievements table
CREATE TABLE IF NOT EXISTS achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  icon TEXT NOT NULL,
  category TEXT NOT NULL,
  tier INTEGER NOT NULL,
  requirement INTEGER NOT NULL,
  condition TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- User achievements table
CREATE TABLE IF NOT EXISTS user_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  achievement_id UUID REFERENCES achievements(id) ON DELETE CASCADE,
  progress INTEGER DEFAULT 0,
  unlocked BOOLEAN DEFAULT false,
  unlocked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, achievement_id)
);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES users(id) ON DELETE CASCADE,
  sender_name TEXT NOT NULL,
  receiver_name TEXT NOT NULL,
  sender_image_url TEXT,
  receiver_image_url TEXT,
  content TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_posts_author_id ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_community_id ON posts(community_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_tracker_entries_user_id ON tracker_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_tracker_entries_date ON tracker_entries(date DESC);
CREATE INDEX IF NOT EXISTS idx_goals_user_id ON goals(user_id);
CREATE INDEX IF NOT EXISTS idx_milestones_user_id ON milestones(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- -----------------------------------------------------------------------------
-- Curated provider directory (resources_curated) + RPC search
-- -----------------------------------------------------------------------------

-- The provider directory is used by ProviderDirectoryService via the
-- `search_provider_directory` RPC.
--
-- This section is written to be schema-drift tolerant:
-- - If the table doesn't exist, it is created.
-- - If it exists but is missing expected columns, they are added.
DO $$
BEGIN
  IF to_regclass('public.resources_curated') IS NULL THEN
    CREATE TABLE public.resources_curated (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL,
      provider_type TEXT NOT NULL DEFAULT 'other',
      type TEXT NOT NULL DEFAULT 'service',
      address TEXT NOT NULL DEFAULT '',
      city TEXT,
      state TEXT,
      postal_code TEXT,
      country TEXT,
      lat DOUBLE PRECISION,
      lng DOUBLE PRECISION,
      phone TEXT,
      contact_email TEXT,
      website TEXT,
      hours TEXT,
      availability TEXT NOT NULL DEFAULT 'Hours not available',
      description TEXT,
      services_offered TEXT,
      service_area TEXT,
      service_kinds TEXT[] NOT NULL DEFAULT '{}',
      capabilities TEXT[] NOT NULL DEFAULT '{}',
      populations_served TEXT[] NOT NULL DEFAULT '{}',
      conditions_served TEXT[] NOT NULL DEFAULT '{}',
      insurance_accepted TEXT[] NOT NULL DEFAULT '{}',
      does_repairs BOOLEAN NOT NULL DEFAULT false,
      does_rentals BOOLEAN NOT NULL DEFAULT false,
      does_sales BOOLEAN NOT NULL DEFAULT false,
      does_crt_custom_wheelchairs BOOLEAN NOT NULL DEFAULT false,
      does_wheelchair_evals_clinical BOOLEAN NOT NULL DEFAULT false,
      does_seating_positioning BOOLEAN NOT NULL DEFAULT false,
      does_home_modifications BOOLEAN NOT NULL DEFAULT false,
      does_installation BOOLEAN NOT NULL DEFAULT false,
      does_in_home_service BOOLEAN NOT NULL DEFAULT false,
      does_insurance_coordination BOOLEAN NOT NULL DEFAULT false,
      accepts_medicaid BOOLEAN,
      accepts_medicare BOOLEAN,
      geo_precision TEXT NOT NULL DEFAULT 'approximate',
      needs_verification BOOLEAN NOT NULL DEFAULT false,
      last_verified_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  ELSE
    ALTER TABLE public.resources_curated
      ADD COLUMN IF NOT EXISTS name TEXT,
      ADD COLUMN IF NOT EXISTS provider_type TEXT,
      ADD COLUMN IF NOT EXISTS type TEXT,
      ADD COLUMN IF NOT EXISTS address TEXT,
      ADD COLUMN IF NOT EXISTS city TEXT,
      ADD COLUMN IF NOT EXISTS state TEXT,
      ADD COLUMN IF NOT EXISTS postal_code TEXT,
      ADD COLUMN IF NOT EXISTS country TEXT,
      ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION,
      ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION,
      ADD COLUMN IF NOT EXISTS phone TEXT,
      ADD COLUMN IF NOT EXISTS contact_email TEXT,
      ADD COLUMN IF NOT EXISTS website TEXT,
      ADD COLUMN IF NOT EXISTS hours TEXT,
      ADD COLUMN IF NOT EXISTS availability TEXT,
      ADD COLUMN IF NOT EXISTS description TEXT,
      ADD COLUMN IF NOT EXISTS services_offered TEXT,
      ADD COLUMN IF NOT EXISTS service_area TEXT,
      ADD COLUMN IF NOT EXISTS service_kinds TEXT[] DEFAULT '{}',
      ADD COLUMN IF NOT EXISTS capabilities TEXT[] DEFAULT '{}',
      ADD COLUMN IF NOT EXISTS populations_served TEXT[] DEFAULT '{}',
      ADD COLUMN IF NOT EXISTS conditions_served TEXT[] DEFAULT '{}',
      ADD COLUMN IF NOT EXISTS insurance_accepted TEXT[] DEFAULT '{}',
      ADD COLUMN IF NOT EXISTS does_repairs BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS does_rentals BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS does_sales BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS does_crt_custom_wheelchairs BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS does_wheelchair_evals_clinical BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS does_seating_positioning BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS does_home_modifications BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS does_installation BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS does_in_home_service BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS does_insurance_coordination BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS accepts_medicaid BOOLEAN,
      ADD COLUMN IF NOT EXISTS accepts_medicare BOOLEAN,
      ADD COLUMN IF NOT EXISTS geo_precision TEXT,
      ADD COLUMN IF NOT EXISTS needs_verification BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now(),
      ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- Legacy column tolerance for resources_curated
-- -----------------------------------------------------------------------------
-- Older versions of this table (already deployed remotely) may contain extra
-- NOT NULL columns (e.g. `location`) that our curated seed inserts do not set.
-- Those constraints cause: 23502 null value in column "..." violates not-null.
--
-- Strategy:
--  1. Backfill a sensible value for known legacy columns.
--  2. Give them a DEFAULT so future inserts succeed.
--  3. Drop NOT NULL on any remaining legacy column that we never populate.
DO $$
DECLARE
  col RECORD;
  managed_cols TEXT[] := ARRAY[
    'id','name','provider_type','type','address','city','state','postal_code','country',
    'lat','lng','phone','contact_email','website','hours','availability','description',
    'services_offered','service_area','service_kinds','capabilities','populations_served',
    'conditions_served','insurance_accepted','does_repairs','does_rentals','does_sales',
    'does_crt_custom_wheelchairs','does_wheelchair_evals_clinical','does_seating_positioning',
    'does_home_modifications','does_installation','does_in_home_service',
    'does_insurance_coordination','accepts_medicaid','accepts_medicare','geo_precision',
    'needs_verification','last_verified_at','created_at','updated_at'
  ];
BEGIN
  -- Known legacy column: `location` (free-text locality string).
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'resources_curated' AND column_name = 'location'
  ) THEN
    BEGIN
      EXECUTE $sql$
        UPDATE public.resources_curated
        SET location = COALESCE(
          NULLIF(btrim(concat_ws(', ', NULLIF(city, ''), NULLIF(state, ''))), ''),
          NULLIF(btrim(address), ''),
          'Unknown'
        )
        WHERE location IS NULL
      $sql$;
      EXECUTE 'ALTER TABLE public.resources_curated ALTER COLUMN location SET DEFAULT ''Unknown''';
    EXCEPTION WHEN others THEN
      -- Different data type (e.g. geography/jsonb): just relax the constraint below.
      NULL;
    END;
  END IF;

  -- Relax NOT NULL on any non-managed (legacy/unknown) column without a default.
  FOR col IN
    SELECT a.attname AS column_name
    FROM pg_attribute a
    WHERE a.attrelid = 'public.resources_curated'::regclass
      AND a.attnum > 0
      AND NOT a.attisdropped
      AND a.attnotnull
      AND NOT (a.attname = ANY (managed_cols))
  LOOP
    EXECUTE format('ALTER TABLE public.resources_curated ALTER COLUMN %I DROP NOT NULL', col.column_name);
  END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS idx_resources_curated_provider_type ON public.resources_curated(provider_type);
CREATE INDEX IF NOT EXISTS idx_resources_curated_state ON public.resources_curated(state);
CREATE INDEX IF NOT EXISTS idx_resources_curated_city ON public.resources_curated(city);
CREATE INDEX IF NOT EXISTS idx_resources_curated_capabilities_gin ON public.resources_curated USING gin (capabilities);
CREATE INDEX IF NOT EXISTS idx_resources_curated_service_kinds_gin ON public.resources_curated USING gin (service_kinds);

-- Prevent duplicates for curated directory entries.
-- NOTE: We normalize to lower(trim()) so repeated deployments remain idempotent.
CREATE UNIQUE INDEX IF NOT EXISTS uq_resources_curated_name_address_norm
  ON public.resources_curated (lower(btrim(name)), lower(btrim(address)));

-- -----------------------------------------------------------------------------
-- Curated seed data: STL wheelchair / CRT providers
-- -----------------------------------------------------------------------------
-- These rows are intentionally marked geo_precision='approximate' and
-- needs_verification=true unless you have exact rooftop coordinates.
-- The goal is that keyword search (e.g. "need a new wheelchair") returns
-- high-signal local options in St. Louis metro.
INSERT INTO public.resources_curated (
  name,
  provider_type,
  type,
  address,
  city,
  state,
  postal_code,
  country,
  lat,
  lng,
  phone,
  contact_email,
  website,
  hours,
  availability,
  description,
  services_offered,
  service_kinds,
  capabilities,
  does_repairs,
  does_rentals,
  does_sales,
  does_crt_custom_wheelchairs,
  does_wheelchair_evals_clinical,
  does_seating_positioning,
  does_home_modifications,
  does_installation,
  does_in_home_service,
  does_insurance_coordination,
  geo_precision,
  needs_verification
)
VALUES
  (
    'Numotion',
    'crt_vendor',
    'service',
    '13300 Lakefront Dr',
    'Earth City',
    'MO',
    '63045',
    'US',
    38.7731,
    -90.4643,
    '(314) 699-9500',
    NULL,
    NULL,
    'Mon–Fri, 8:30 AM–5:00 PM',
    'Mon–Fri, 8:30 AM–5:00 PM',
    'Complex Rehab Technology (CRT) wheelchair provider for medically necessary custom seating and mobility.',
    'Custom manual and power wheelchairs; complex seating/positioning; cushions; mobility evaluations; equipment configuration; insurance coordination; delivery/fitting; adjustments; maintenance and repairs.',
    ARRAY['wheelchair','complex rehab technology','crt','seating','positioning','power wheelchair','manual wheelchair','mobility evaluation','insurance'],
    ARRAY['custom wheelchair','power wheelchair','manual wheelchair','complex seating','positioning','cushions','mobility evaluation','insurance coordination','delivery fitting','repairs'],
    true,
    false,
    true,
    true,
    false,
    true,
    false,
    false,
    false,
    true,
    'approximate',
    true
  ),
  (
    'Alliance Rehab and Medical Equipment',
    'crt_vendor',
    'service',
    '1763 Larkin Williams Rd',
    'Fenton',
    'MO',
    '63026',
    'US',
    38.5131,
    -90.4418,
    '(314) 942-7590',
    'info@alliancerehabmed.com',
    NULL,
    'Mon–Fri, 9:00 AM–5:00 PM',
    'Mon–Fri, 9:00 AM–5:00 PM',
    'Complex Rehab Technology / DME provider focused on customized mobility and positioning needs.',
    'Customized manual and power wheelchairs; complex seating/positioning; mobility technology; evaluations and fitting; adjustments; repairs; insurance/documentation coordination.',
    ARRAY['wheelchair','crt','dme','seating','positioning','power wheelchair','manual wheelchair','repairs','insurance'],
    ARRAY['custom wheelchair','complex seating','positioning','evaluations fitting','repairs','documentation insurance'],
    true,
    false,
    true,
    true,
    false,
    true,
    false,
    false,
    false,
    true,
    'approximate',
    true
  ),
  (
    'National Seating & Mobility, Inc. (NSM)',
    'crt_vendor',
    'service',
    '502 Rudder Rd',
    'Fenton',
    'MO',
    '63026',
    'US',
    38.5131,
    -90.4418,
    '(833) 386-9235',
    NULL,
    NULL,
    'Mon–Fri, 8:00 AM–4:30 PM',
    'Mon–Fri, 8:00 AM–4:30 PM',
    'CRT wheelchair + accessibility provider (seating systems, positioning, and repair).',
    'Custom power and manual wheelchairs; seating systems; cushions; custom molding; positioning equipment; wheelchair repair; home-accessibility equipment.',
    ARRAY['wheelchair','crt','seating','positioning','cushions','repair','accessibility'],
    ARRAY['custom power wheelchair','custom manual wheelchair','seating systems','custom molding','positioning equipment','wheelchair repair','home accessibility'],
    true,
    false,
    true,
    true,
    false,
    true,
    true,
    false,
    false,
    true,
    'approximate',
    true
  ),
  (
    'Rehab Medical of St. Louis',
    'crt_vendor',
    'service',
    '924 Hemsath Rd',
    'St. Charles',
    'MO',
    '63303',
    'US',
    38.7881,
    -90.4974,
    '(314) 205-0070',
    NULL,
    NULL,
    'Mon–Fri, 9:00 AM–4:00 PM',
    'Mon–Fri, 9:00 AM–4:00 PM',
    'CRT / DME provider for customized wheelchairs including pediatric mobility.',
    'Customized power and manual wheelchairs; complex seating; pediatric mobility; configuration and fitting; in-home service; repairs; insurance authorization/documentation; ongoing support.',
    ARRAY['wheelchair','crt','dme','pediatric mobility','seating','repairs','insurance'],
    ARRAY['custom wheelchair','pediatric mobility','complex seating','fitting','in-home service','repairs','insurance authorization'],
    true,
    false,
    true,
    true,
    false,
    true,
    false,
    false,
    true,
    true,
    'approximate',
    true
  ),
  (
    'St. Louis Wheelchair (Therapeutic Specialties, Inc.)',
    'crt_vendor',
    'service',
    '5240 Oakland Ave, Suite A',
    'St. Louis',
    'MO',
    '63110',
    'US',
    38.6270,
    -90.1994,
    '(314) 291-9900',
    NULL,
    NULL,
    'Mon–Thu, ~8:00 AM–4:30 PM (verify)',
    'Mon–Thu, ~8:00 AM–4:30 PM (verify)',
    'Local complex-rehab wheelchair provider located within Paraquad.',
    'Custom manual and power wheelchairs; seating and positioning; fitting; maintenance/repairs; home-accessibility solutions.',
    ARRAY['wheelchair','crt','seating','positioning','repairs','home accessibility'],
    ARRAY['custom manual wheelchair','custom power wheelchair','seating positioning','fitting','repairs','home accessibility'],
    true,
    false,
    true,
    true,
    false,
    true,
    true,
    false,
    false,
    true,
    'approximate',
    true
  ),
  (
    'WashU Medicine — Wheelchair, Seating, Mobility & Assistive Technology at Paraquad',
    'clinical_eval',
    'service',
    '5200 Berthold Ave (Stephen A. Orthwein Center at Paraquad)',
    'St. Louis',
    'MO',
    '63110',
    'US',
    38.6270,
    -90.1994,
    '(314) 286-1669',
    NULL,
    NULL,
    NULL,
    'Call for appointment',
    'Clinical wheelchair/seating evaluations and assistive-technology assessment. Works with vendors for appropriate equipment.',
    'Wheelchair and seating evaluations; positioning; mobility assessment; assistive-technology evaluation.',
    ARRAY['wheelchair evaluation','seating evaluation','assistive technology','clinical','ot','atp'],
    ARRAY['clinical evaluation','seating assessment','positioning','assistive technology','mobility assessment'],
    false,
    false,
    false,
    false,
    true,
    true,
    false,
    false,
    false,
    false,
    'approximate',
    true
  ),
  (
    'Paraquad',
    'independent_living',
    'service',
    '5240 Oakland Ave',
    'St. Louis',
    'MO',
    '63110',
    'US',
    38.6270,
    -90.1994,
    '(314) 289-4200',
    NULL,
    NULL,
    'Mon–Fri 8:00 AM–5:00 PM (Information & Referral)',
    'Mon–Fri 8:00 AM–5:00 PM',
    'Independent living/disability resource with referrals and rehabilitation programming; connected to wheelchair/seating services via Orthwein Center.',
    'Disability information and referrals; independent-living support; community programs; wheelchair wellness; adapted exercise; FES therapy.',
    ARRAY['disability resource','independent living','referrals','wheelchair wellness','exercise','sci'],
    ARRAY['information referral','independent living support','community programs','wheelchair wellness'],
    false,
    false,
    false,
    false,
    true,
    false,
    true,
    false,
    false,
    false,
    'approximate',
    true
  ),
  (
    'Mobility City',
    'repair_rental_retail',
    'service',
    '2145 Barrett Station Rd',
    'Des Peres',
    'MO',
    '63131',
    'US',
    38.6009,
    -90.4329,
    '(636) 329-6367',
    NULL,
    NULL,
    NULL,
    'Call for service / rentals',
    'Wheelchair and scooter repair, rentals, and mobility equipment sales; in-shop and in-home service.',
    'Power-wheelchair and scooter repair; manual wheelchair service; equipment rentals; sales; sanitization; in-shop and in-home service.',
    ARRAY['wheelchair repair','rental','scooter repair','mobility equipment','in-home service'],
    ARRAY['repairs','rentals','sales','in-home service','power wheelchair repair','scooter repair'],
    true,
    true,
    true,
    false,
    false,
    false,
    false,
    false,
    true,
    false,
    'approximate',
    true
  ),
  (
    'Moose Mobility LLC',
    'repair_rental_retail',
    'service',
    '10050 Gravois Rd',
    'Affton',
    'MO',
    '63123',
    'US',
    38.5520,
    -90.3334,
    '(314) 499-7249',
    'msabanovic@moosemobilityllc.com',
    NULL,
    NULL,
    'Call for rentals/repairs (address discrepancy; verify)',
    'Wheelchair/DME sales, rentals and repairs; consignment; reports an on-staff DME technician. Verify address before production use.',
    'Manual and power wheelchairs; scooters; transport chairs; hospital beds; walkers and other DME; rentals; repairs; consignment sales.',
    ARRAY['wheelchair','dme','rental','repair','scooter','hospital bed','walker','consignment'],
    ARRAY['rentals','repairs','sales','dme technician','consignment'],
    true,
    true,
    true,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    'approximate',
    true
  ),
  (
    'MediEquip, Inc. — West County',
    'general_dme',
    'service',
    '12852 Manchester Rd',
    'Des Peres',
    'MO',
    '63131',
    'US',
    38.6009,
    -90.4329,
    '(314) 965-9300',
    NULL,
    NULL,
    'Mon–Fri 9–5; Sat 10–4',
    'Mon–Fri 9–5; Sat 10–4',
    'Mobility/accessibility equipment, rentals, installation and service (West County).',
    'Mobility and accessibility equipment; rentals; installation; service; independent-living support products.',
    ARRAY['mobility equipment','accessibility','rentals','installation','service'],
    ARRAY['rentals','sales','installation','service'],
    true,
    true,
    true,
    false,
    false,
    false,
    true,
    true,
    false,
    false,
    'approximate',
    true
  ),
  (
    'MediEquip, Inc. — South County',
    'general_dme',
    'service',
    '5845 S Lindbergh Blvd',
    'St. Louis',
    'MO',
    '63123',
    'US',
    38.5520,
    -90.3334,
    '(314) 892-7000',
    NULL,
    NULL,
    'Mon–Fri 9–5; Sat 10–4',
    'Mon–Fri 9–5; Sat 10–4',
    'Mobility/accessibility equipment, rentals, installation and service (South County).',
    'Mobility and accessibility equipment; rentals; service; home-accessibility equipment.',
    ARRAY['mobility equipment','accessibility','rentals','installation','service'],
    ARRAY['rentals','sales','installation','service'],
    true,
    true,
    true,
    false,
    false,
    false,
    true,
    true,
    false,
    false,
    'approximate',
    true
  ),
  (
    'Provider Plus LLC',
    'general_dme',
    'service',
    '7748 Watson Rd',
    'St. Louis',
    'MO',
    '63119',
    'US',
    38.6270,
    -90.1994,
    '(314) 961-8500',
    NULL,
    NULL,
    'Mon–Fri 8:00 AM–5:00 PM',
    'Mon–Fri 8:00 AM–5:00 PM',
    'General DME / medical supply provider that includes mobility equipment.',
    'Home medical equipment and supplies, including mobility equipment.',
    ARRAY['dme','medical supplies','mobility equipment','wheelchair'],
    ARRAY['sales','dme','mobility equipment'],
    false,
    false,
    true,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    'approximate',
    true
  ),
  (
    'Med X Change LLC',
    'general_dme',
    'service',
    '325 S 5th St',
    'St. Charles',
    'MO',
    '63301',
    'US',
    38.7881,
    -90.4974,
    '(636) 949-5660',
    NULL,
    NULL,
    'Mon–Fri 9:00 AM–5:00 PM',
    'Mon–Fri 9:00 AM–5:00 PM',
    'DME / mobility equipment provider serving St. Charles and St. Louis metro.',
    'Medical and mobility equipment and supplies.',
    ARRAY['dme','mobility equipment','wheelchair','supplies'],
    ARRAY['sales','dme','mobility equipment'],
    false,
    false,
    true,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    'approximate',
    true
  ),
  (
    '101 Mobility of St Louis',
    'home_accessibility',
    'service',
    '831 Westwood Industrial Park Dr, Suite 101',
    'Weldon Spring',
    'MO',
    '63304',
    'US',
    38.7203,
    -90.6893,
    '(636) 447-1414',
    NULL,
    NULL,
    'Mon–Fri 8:00 AM–4:00 PM',
    'Mon–Fri 8:00 AM–4:00 PM',
    'Home mobility/accessibility solutions (ramps, stairlifts, lifts, elevators).',
    'Wheelchair ramps; stairlifts; home elevators; patient lifts; consultations and installation.',
    ARRAY['ramps','stairlifts','home accessibility','lifts','installation'],
    ARRAY['consultation','installation','ramps','stairlifts','lifts','home elevators'],
    false,
    false,
    true,
    false,
    false,
    false,
    true,
    true,
    false,
    false,
    'approximate',
    true
  ),
  (
    'Next Day Access St. Louis',
    'home_accessibility',
    'service',
    'Service area: Greater St. Louis (on-site assessment)',
    'St. Louis',
    'MO',
    NULL,
    'US',
    38.6270,
    -90.1994,
    '(314) 710-2158',
    NULL,
    NULL,
    NULL,
    'Call/text for consultation',
    'Residential/commercial accessibility modifications with on-site assessment and installation.',
    'Wheelchair ramps; stair lifts; vertical platform lifts; grab bars; bathroom-safety modifications; patient lifts; pool lifts; installation.',
    ARRAY['ramps','stair lifts','platform lifts','grab bars','bathroom safety','installation','accessibility'],
    ARRAY['on-site assessment','installation','ramps','stair lifts','platform lifts','grab bars','bathroom modifications'],
    false,
    false,
    true,
    false,
    false,
    false,
    true,
    true,
    false,
    false,
    'approximate',
    true
  ),
  (
    'Mobility Plus Ballwin',
    'repair_rental_retail',
    'service',
    '15461 Clayton Rd',
    'Ballwin',
    'MO',
    '63011',
    'US',
    38.5951,
    -90.5462,
    '(314) 608-5789',
    NULL,
    NULL,
    NULL,
    'Call for sales/repairs/rentals',
    'Local mobility equipment and accessibility provider (scooters, ramps, lifts); sales, repairs and rentals; home visits/installations.',
    'Mobility scooters; ramps and lifts; equipment sales; repairs; rentals; home visits; installations; custom accessibility projects.',
    ARRAY['mobility scooters','repairs','rentals','ramps','lifts','installation','home visits'],
    ARRAY['sales','repairs','rentals','installation','home visits','ramps','lifts'],
    true,
    true,
    true,
    false,
    false,
    false,
    true,
    true,
    true,
    false,
    'approximate',
    true
  )
ON CONFLICT (lower(btrim(name)), lower(btrim(address))) DO UPDATE
SET
  provider_type = EXCLUDED.provider_type,
  type = EXCLUDED.type,
  city = EXCLUDED.city,
  state = EXCLUDED.state,
  postal_code = EXCLUDED.postal_code,
  country = EXCLUDED.country,
  lat = EXCLUDED.lat,
  lng = EXCLUDED.lng,
  phone = EXCLUDED.phone,
  contact_email = EXCLUDED.contact_email,
  website = EXCLUDED.website,
  hours = EXCLUDED.hours,
  availability = EXCLUDED.availability,
  description = EXCLUDED.description,
  services_offered = EXCLUDED.services_offered,
  service_kinds = EXCLUDED.service_kinds,
  capabilities = EXCLUDED.capabilities,
  does_repairs = EXCLUDED.does_repairs,
  does_rentals = EXCLUDED.does_rentals,
  does_sales = EXCLUDED.does_sales,
  does_crt_custom_wheelchairs = EXCLUDED.does_crt_custom_wheelchairs,
  does_wheelchair_evals_clinical = EXCLUDED.does_wheelchair_evals_clinical,
  does_seating_positioning = EXCLUDED.does_seating_positioning,
  does_home_modifications = EXCLUDED.does_home_modifications,
  does_installation = EXCLUDED.does_installation,
  does_in_home_service = EXCLUDED.does_in_home_service,
  does_insurance_coordination = EXCLUDED.does_insurance_coordination,
  geo_precision = EXCLUDED.geo_precision,
  needs_verification = EXCLUDED.needs_verification,
  updated_at = now();

-- Repair legacy/non-canonical provider_type values so they match the app's
-- ProviderType constants (lib/models/provider_directory_entry.dart).
UPDATE public.resources_curated
SET provider_type = CASE provider_type
      WHEN 'crt_wheelchair_provider' THEN 'crt_vendor'
      WHEN 'complex_rehab_technology' THEN 'crt_vendor'
      WHEN 'clinical_wheelchair_evaluation' THEN 'clinical_eval'
      WHEN 'wheelchair_repair_rental' THEN 'repair_rental_retail'
      WHEN 'general_dme_mobility' THEN 'general_dme'
      WHEN 'independent_living_resource' THEN 'independent_living'
      ELSE provider_type
    END,
    updated_at = now()
WHERE provider_type IN (
  'crt_wheelchair_provider',
  'complex_rehab_technology',
  'clinical_wheelchair_evaluation',
  'wheelchair_repair_rental',
  'general_dme_mobility',
  'independent_living_resource'
);

-- Keyword hygiene: CRT vendors that service what they build should always be
-- discoverable for "my chair is broken" style repair searches.
UPDATE public.resources_curated
SET service_kinds = (
      SELECT array_agg(DISTINCT k)
      FROM unnest(coalesce(service_kinds, '{}') || ARRAY['wheelchair repair','repair','fix wheelchair','service','maintenance']) AS k
    ),
    updated_at = now()
WHERE does_repairs = true
  AND NOT ('wheelchair repair' = ANY(coalesce(service_kinds, '{}')));

-- Custom/complex needs vocabulary for CRT + clinical evaluation providers.
UPDATE public.resources_curated
SET service_kinds = (
      SELECT array_agg(DISTINCT k)
      FROM unnest(
        coalesce(service_kinds, '{}') ||
        ARRAY['new wheelchair','custom wheelchair','complex rehab','crt','complex seating','positioning','wheelchair evaluation']
      ) AS k
    ),
    updated_at = now()
WHERE (does_crt_custom_wheelchairs = true OR does_wheelchair_evals_clinical = true)
  AND NOT ('new wheelchair' = ANY(coalesce(service_kinds, '{}')));

-- RPC used by the Flutter app to search/filter providers.
-- NOTE: This uses a Haversine approximation (no PostGIS required).
CREATE OR REPLACE FUNCTION public.search_provider_directory(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  radius_miles DOUBLE PRECISION DEFAULT 50,
  provider_types TEXT[] DEFAULT NULL,
  require_repairs BOOLEAN DEFAULT false,
  require_rentals BOOLEAN DEFAULT false,
  require_sales BOOLEAN DEFAULT false,
  require_crt BOOLEAN DEFAULT false,
  require_clinical_eval BOOLEAN DEFAULT false,
  require_seating BOOLEAN DEFAULT false,
  require_home_modifications BOOLEAN DEFAULT false,
  require_installation BOOLEAN DEFAULT false,
  exclude_pediatric_only BOOLEAN DEFAULT false,
  max_results INTEGER DEFAULT 50,
  text_query TEXT DEFAULT NULL
)
RETURNS TABLE(
  id UUID,
  name TEXT,
  provider_type TEXT,
  type TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  postal_code TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  distance_miles DOUBLE PRECISION,
  phone TEXT,
  contact_email TEXT,
  website TEXT,
  hours TEXT,
  availability TEXT,
  description TEXT,
  services_offered TEXT,
  service_area TEXT,
  service_kinds TEXT[],
  capabilities TEXT[],
  populations_served TEXT[],
  conditions_served TEXT[],
  insurance_accepted TEXT[],
  does_repairs BOOLEAN,
  does_rentals BOOLEAN,
  does_sales BOOLEAN,
  does_crt_custom_wheelchairs BOOLEAN,
  does_wheelchair_evals_clinical BOOLEAN,
  does_seating_positioning BOOLEAN,
  does_home_modifications BOOLEAN,
  does_installation BOOLEAN,
  does_in_home_service BOOLEAN,
  does_insurance_coordination BOOLEAN,
  accepts_medicaid BOOLEAN,
  accepts_medicare BOOLEAN,
  geo_precision TEXT,
  needs_verification BOOLEAN,
  last_verified_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  WITH base AS (
    SELECT
      s.*,
      (
        3958.7613 * 2 * asin(
          sqrt(
            pow(sin(radians((s.lat - user_lat) / 2)), 2) +
            cos(radians(user_lat)) * cos(radians(s.lat)) *
            pow(sin(radians((s.lng - user_lng) / 2)), 2)
          )
        )
      ) AS distance_miles
    FROM public.resources_curated s
    WHERE s.lat IS NOT NULL
      AND s.lng IS NOT NULL
      AND (
        text_query IS NULL
        OR btrim(text_query) = ''
        OR to_tsvector(
          'english',
          concat_ws(
            ' ',
            coalesce(s.name, ''),
            coalesce(s.provider_type, ''),
            coalesce(s.type, ''),
            coalesce(s.address, ''),
            coalesce(s.city, ''),
            coalesce(s.state, ''),
            coalesce(s.services_offered, ''),
            coalesce(s.service_area, ''),
            array_to_string(coalesce(s.service_kinds, '{}'), ' '),
            array_to_string(coalesce(s.capabilities, '{}'), ' '),
            array_to_string(coalesce(s.populations_served, '{}'), ' '),
            array_to_string(coalesce(s.conditions_served, '{}'), ' ')
          )
        ) @@ websearch_to_tsquery('english', text_query)
      )
  )
  SELECT
    b.id,
    b.name,
    COALESCE(b.provider_type, 'other') AS provider_type,
    COALESCE(b.type, 'service') AS type,
    COALESCE(b.address, '') AS address,
    b.city,
    b.state,
    b.postal_code,
    b.lat,
    b.lng,
    b.distance_miles,
    b.phone,
    b.contact_email,
    b.website,
    b.hours,
    COALESCE(b.availability, 'Hours not available') AS availability,
    b.description,
    b.services_offered,
    b.service_area,
    COALESCE(b.service_kinds, '{}') AS service_kinds,
    COALESCE(b.capabilities, '{}') AS capabilities,
    COALESCE(b.populations_served, '{}') AS populations_served,
    COALESCE(b.conditions_served, '{}') AS conditions_served,
    COALESCE(b.insurance_accepted, '{}') AS insurance_accepted,
    COALESCE(b.does_repairs, false) AS does_repairs,
    COALESCE(b.does_rentals, false) AS does_rentals,
    COALESCE(b.does_sales, false) AS does_sales,
    COALESCE(b.does_crt_custom_wheelchairs, false) AS does_crt_custom_wheelchairs,
    COALESCE(b.does_wheelchair_evals_clinical, false) AS does_wheelchair_evals_clinical,
    COALESCE(b.does_seating_positioning, false) AS does_seating_positioning,
    COALESCE(b.does_home_modifications, false) AS does_home_modifications,
    COALESCE(b.does_installation, false) AS does_installation,
    COALESCE(b.does_in_home_service, false) AS does_in_home_service,
    COALESCE(b.does_insurance_coordination, false) AS does_insurance_coordination,
    b.accepts_medicaid,
    b.accepts_medicare,
    COALESCE(b.geo_precision, 'approximate') AS geo_precision,
    COALESCE(b.needs_verification, false) AS needs_verification,
    b.last_verified_at
  FROM base b
  WHERE b.distance_miles <= radius_miles
    AND (provider_types IS NULL OR array_length(provider_types, 1) IS NULL OR b.provider_type = ANY(provider_types))
    AND (NOT require_repairs OR COALESCE(b.does_repairs, false) = true)
    AND (NOT require_rentals OR COALESCE(b.does_rentals, false) = true)
    AND (NOT require_sales OR COALESCE(b.does_sales, false) = true)
    AND (NOT require_crt OR COALESCE(b.does_crt_custom_wheelchairs, false) = true)
    AND (NOT require_clinical_eval OR COALESCE(b.does_wheelchair_evals_clinical, false) = true)
    AND (NOT require_seating OR COALESCE(b.does_seating_positioning, false) = true)
    AND (NOT require_home_modifications OR COALESCE(b.does_home_modifications, false) = true)
    AND (NOT require_installation OR COALESCE(b.does_installation, false) = true)
    -- If/when pediatric-only tagging is added, this can be enforced.
    AND (NOT exclude_pediatric_only OR true)
  ORDER BY b.distance_miles ASC
  LIMIT GREATEST(1, LEAST(max_results, 200));
$$;
