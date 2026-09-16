-- Provider Directory: typed capabilities + geolocation matching + St. Louis seed data
--
-- Builds on `resources_curated` (see 20260915_120000_curated_resources_directory.sql).
-- Goal: ARIE must be able to distinguish intents such as
--   "my power chair is broken"        -> does_repairs
--   "I need a new custom chair"       -> does_crt_custom_wheelchairs
--   "I need a wheelchair evaluation"  -> does_wheelchair_evals_clinical / provider_type='clinical_eval'
--   "I need a ramp installed"         -> does_home_modifications + does_installation
--   "general DME"                     -> provider_type in ('general_dme','repair_rental_retail')

-- 1) Typed directory columns ------------------------------------------------
ALTER TABLE public.resources_curated
  -- Safety net: older remote DBs may have a legacy `resources_curated` table
  -- that predates `20260915_120000_curated_resources_directory.sql`. Because
  -- that migration used `CREATE TABLE IF NOT EXISTS`, it would not add newer
  -- columns on already-existing tables. SQL-language functions validate column
  -- references at CREATE time, so we must ensure these exist before we define
  -- `search_provider_directory()`.
  ADD COLUMN IF NOT EXISTS address TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS state TEXT,
  ADD COLUMN IF NOT EXISTS postal_code TEXT,
  ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION,

  -- Safety net: these array columns are indexed below. On projects where an older
  -- `resources_curated` already existed, the original CREATE TABLE IF NOT EXISTS
  -- was skipped and these were missing -> "column service_kinds does not exist".
  ADD COLUMN IF NOT EXISTS service_kinds TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS capabilities TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS specialty TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS specialties TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS source TEXT,
  ADD COLUMN IF NOT EXISTS source_id TEXT,
  ADD COLUMN IF NOT EXISTS provider_type TEXT,                 -- crt_vendor | clinical_eval | repair_rental_retail | general_dme | home_accessibility | independent_living | other
  ADD COLUMN IF NOT EXISTS services_offered TEXT,              -- free text narrative
  ADD COLUMN IF NOT EXISTS service_area TEXT,                  -- e.g. 'Greater St. Louis metro'
  ADD COLUMN IF NOT EXISTS service_area_radius_miles DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS hours TEXT,                         -- human readable hours
  ADD COLUMN IF NOT EXISTS does_repairs BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS does_rentals BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS does_sales BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS does_crt_custom_wheelchairs BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS does_wheelchair_evals_clinical BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS does_seating_positioning BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS does_home_modifications BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS does_installation BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS does_in_home_service BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS does_insurance_coordination BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS accepts_medicaid BOOLEAN,
  ADD COLUMN IF NOT EXISTS accepts_medicare BOOLEAN,
  ADD COLUMN IF NOT EXISTS insurance_accepted TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS populations_served TEXT[] DEFAULT ARRAY[]::TEXT[], -- adults | pediatric | all_ages
  ADD COLUMN IF NOT EXISTS conditions_served TEXT[] DEFAULT ARRAY[]::TEXT[],  -- e.g. spinal_cord_injury
  ADD COLUMN IF NOT EXISTS geo_precision TEXT DEFAULT 'approximate',          -- exact | approximate | service_area_only
  ADD COLUMN IF NOT EXISTS needs_verification BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS verification_notes TEXT,
  ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_resources_curated_provider_type ON public.resources_curated(provider_type);
CREATE INDEX IF NOT EXISTS idx_resources_curated_service_kinds ON public.resources_curated USING GIN (service_kinds);
CREATE INDEX IF NOT EXISTS idx_resources_curated_capabilities ON public.resources_curated USING GIN (capabilities);
CREATE INDEX IF NOT EXISTS idx_resources_curated_populations ON public.resources_curated USING GIN (populations_served);

-- Stable upsert key for curated seed data.
-- NOTE: intentionally NOT a partial index. Postgres cannot infer a partial index
-- as the arbiter for `ON CONFLICT (source, source_id)` without a matching
-- index predicate, which would fail with
-- "no unique or exclusion constraint matching the ON CONFLICT specification".
-- NULLs are still allowed/duplicable because NULLs are distinct in unique indexes.
DROP INDEX IF EXISTS public.uq_resources_curated_source;

-- Remove pre-existing duplicates so the unique index can be built.
DELETE FROM public.resources_curated r
USING public.resources_curated keeper
WHERE r.source IS NOT NULL
  AND r.source_id IS NOT NULL
  AND keeper.source = r.source
  AND keeper.source_id = r.source_id
  AND keeper.ctid < r.ctid;

CREATE UNIQUE INDEX IF NOT EXISTS uq_resources_curated_source
  ON public.resources_curated(source, source_id);

-- 2) Geolocation + capability search RPC ------------------------------------
-- Returns approved directory entries within `radius_miles` of the user, filtered
-- by optional provider types / required capability flags, ordered by distance.
CREATE OR REPLACE FUNCTION public.search_provider_directory(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  radius_miles DOUBLE PRECISION DEFAULT 40,
  provider_types TEXT[] DEFAULT NULL,
  require_repairs BOOLEAN DEFAULT FALSE,
  require_rentals BOOLEAN DEFAULT FALSE,
  require_sales BOOLEAN DEFAULT FALSE,
  require_crt BOOLEAN DEFAULT FALSE,
  require_clinical_eval BOOLEAN DEFAULT FALSE,
  require_seating BOOLEAN DEFAULT FALSE,
  require_home_modifications BOOLEAN DEFAULT FALSE,
  require_installation BOOLEAN DEFAULT FALSE,
  exclude_pediatric_only BOOLEAN DEFAULT FALSE,
  max_results INTEGER DEFAULT 25
)
RETURNS TABLE (
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
  WITH scoped AS (
    SELECT
      r.*,
      -- Haversine distance in miles
      3958.7559 * 2 * ASIN(
        LEAST(1, SQRT(
          POWER(SIN(RADIANS(r.lat - user_lat) / 2), 2) +
          COS(RADIANS(user_lat)) * COS(RADIANS(r.lat)) *
          POWER(SIN(RADIANS(r.lng - user_lng) / 2), 2)
        ))
      ) AS dist_miles
    FROM public.resources_curated r
    WHERE r.status = 'approved'
      AND r.lat IS NOT NULL
      AND r.lng IS NOT NULL
  )
  SELECT
    s.id, s.name, s.provider_type, s.type, s.address, s.city, s.state, s.postal_code,
    s.lat, s.lng, s.dist_miles AS distance_miles,
    s.phone, s.contact_email, s.website, s.hours, s.availability, s.description,
    s.services_offered, s.service_area,
    s.service_kinds, s.capabilities, s.populations_served, s.conditions_served, s.insurance_accepted,
    s.does_repairs, s.does_rentals, s.does_sales, s.does_crt_custom_wheelchairs,
    s.does_wheelchair_evals_clinical, s.does_seating_positioning,
    s.does_home_modifications, s.does_installation, s.does_in_home_service,
    s.does_insurance_coordination, s.accepts_medicaid, s.accepts_medicare,
    s.geo_precision, s.needs_verification, s.last_verified_at
  FROM scoped s
  WHERE (
      s.dist_miles <= radius_miles
      -- service-area-only providers count as in-range within their stated radius
      OR (s.service_area_radius_miles IS NOT NULL AND s.dist_miles <= s.service_area_radius_miles)
    )
    AND (provider_types IS NULL OR array_length(provider_types, 1) IS NULL OR s.provider_type = ANY(provider_types))
    AND (NOT require_repairs OR COALESCE(s.does_repairs, FALSE))
    AND (NOT require_rentals OR COALESCE(s.does_rentals, FALSE))
    AND (NOT require_sales OR COALESCE(s.does_sales, FALSE))
    AND (NOT require_crt OR COALESCE(s.does_crt_custom_wheelchairs, FALSE))
    AND (NOT require_clinical_eval OR COALESCE(s.does_wheelchair_evals_clinical, FALSE))
    AND (NOT require_seating OR COALESCE(s.does_seating_positioning, FALSE))
    AND (NOT require_home_modifications OR COALESCE(s.does_home_modifications, FALSE))
    AND (NOT require_installation OR COALESCE(s.does_installation, FALSE))
    AND (
      NOT exclude_pediatric_only
      OR s.populations_served IS NULL
      OR array_length(s.populations_served, 1) IS NULL
      OR NOT (s.populations_served = ARRAY['pediatric']::TEXT[])
    )
  ORDER BY s.dist_miles ASC
  LIMIT GREATEST(1, COALESCE(max_results, 25));
$$;

GRANT EXECUTE ON FUNCTION public.search_provider_directory(
  DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT[],
  BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, INTEGER
) TO anon, authenticated;

-- 3) St. Louis metro seed data ---------------------------------------------
-- Coordinates are approximate (rooftop-level accuracy not guaranteed);
-- geo_precision is recorded so the app can show/verify accordingly.

INSERT INTO public.resources_curated (
  name, type, provider_type, address, city, state, postal_code, country, lat, lng,
  phone, contact_email, website, hours, availability, description, services_offered,
  service_area, service_area_radius_miles,
  specialty, specialties, service_kinds, capabilities, populations_served, conditions_served,
  does_repairs, does_rentals, does_sales, does_crt_custom_wheelchairs,
  does_wheelchair_evals_clinical, does_seating_positioning,
  does_home_modifications, does_installation, does_in_home_service, does_insurance_coordination,
  geo_precision, needs_verification, verification_notes,
  status, source, source_id, last_verified_at, created_at, updated_at
) VALUES
-- === Complex Rehab Technology (CRT) vendors ===
(
  'Numotion', 'service', 'crt_vendor',
  '13300 Lakefront Dr', 'Earth City', 'MO', '63045', 'US', 38.7620, -90.4650,
  '(314) 699-9500', NULL, NULL, 'Mon–Fri 8:30 AM–5:00 PM', 'Mon–Fri 8:30 AM–5:00 PM',
  'Complex Rehab Technology (CRT) / wheelchair provider.',
  'Custom manual and power wheelchairs, complex seating and positioning, cushions, mobility evaluations, equipment configuration, insurance coordination, delivery/fitting, adjustments, maintenance and repairs.',
  'Greater St. Louis metro', 60,
  ARRAY['Complex Rehab Technology','Wheelchairs']::TEXT[], ARRAY['Complex Rehab Technology','Wheelchairs']::TEXT[],
  ARRAY['crt_vendor','repair']::TEXT[],
  ARRAY['custom_wheelchairs','custom_seating','mobility_evaluation','repairs','insurance_coordination','delivery_fitting']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['spinal_cord_injury','neuromuscular','mobility_impairment']::TEXT[],
  TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, TRUE,
  'approximate', FALSE, NULL,
  'approved', 'curated_stl', 'stl_numotion_earth_city', NOW(), NOW(), NOW()
),
(
  'Alliance Rehab and Medical Equipment', 'service', 'crt_vendor',
  '1763 Larkin Williams Rd', 'Fenton', 'MO', '63026', 'US', 38.5150, -90.4390,
  '(314) 942-7590', 'info@alliancerehabmed.com', NULL, 'Mon–Fri 9:00 AM–5:00 PM', 'Mon–Fri 9:00 AM–5:00 PM',
  'Complex Rehab Technology / DME provider. Main line: (800) 813-1656.',
  'Customized manual and power wheelchairs, complex seating and positioning, mobility technology, evaluations and fitting, equipment adjustments, repairs, insurance and documentation coordination.',
  'Greater St. Louis metro', 60,
  ARRAY['Complex Rehab Technology','Wheelchairs']::TEXT[], ARRAY['Complex Rehab Technology','Wheelchairs']::TEXT[],
  ARRAY['crt_vendor','repair']::TEXT[],
  ARRAY['custom_wheelchairs','custom_seating','mobility_evaluation','repairs','insurance_coordination']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['spinal_cord_injury','neuromuscular','mobility_impairment']::TEXT[],
  TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, TRUE,
  'approximate', FALSE, NULL,
  'approved', 'curated_stl', 'stl_alliance_rehab_fenton', NOW(), NOW(), NOW()
),
(
  'National Seating & Mobility, Inc. (NSM)', 'service', 'crt_vendor',
  '502 Rudder Rd', 'Fenton', 'MO', '63026', 'US', 38.5120, -90.4230,
  '(833) 386-9235', NULL, NULL, 'Mon–Fri 8:00 AM–4:30 PM', 'Mon–Fri 8:00 AM–4:30 PM',
  'Complex Rehab Technology / accessibility provider.',
  'Custom power and manual wheelchairs, seating systems, cushions, custom molding, positioning equipment, wheelchair repair, and home-accessibility equipment.',
  'Greater St. Louis metro', 60,
  ARRAY['Complex Rehab Technology','Wheelchairs','Accessibility']::TEXT[], ARRAY['Complex Rehab Technology','Wheelchairs','Accessibility']::TEXT[],
  ARRAY['crt_vendor','repair','home_accessibility']::TEXT[],
  ARRAY['custom_wheelchairs','custom_seating','custom_molding','repairs','home_accessibility']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['spinal_cord_injury','neuromuscular','mobility_impairment']::TEXT[],
  TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE,
  'approximate', FALSE, NULL,
  'approved', 'curated_stl', 'stl_nsm_fenton', NOW(), NOW(), NOW()
),
(
  'Rehab Medical of St. Louis', 'service', 'crt_vendor',
  '924 Hemsath Rd', 'St. Charles', 'MO', '63303', 'US', 38.7840, -90.5620,
  '(314) 205-0070', NULL, NULL, 'Mon–Fri 9:00 AM–4:00 PM', 'Mon–Fri 9:00 AM–4:00 PM',
  'Complex Rehab Technology / DME provider.',
  'Customized power and manual wheelchairs, complex seating, pediatric mobility, equipment configuration and fitting, in-home service, repairs, insurance authorization/documentation and ongoing equipment support.',
  'Greater St. Louis metro and St. Charles County', 60,
  ARRAY['Complex Rehab Technology','Wheelchairs']::TEXT[], ARRAY['Complex Rehab Technology','Wheelchairs']::TEXT[],
  ARRAY['crt_vendor','repair']::TEXT[],
  ARRAY['custom_wheelchairs','custom_seating','pediatric_mobility','repairs','in_home_service','insurance_coordination']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['spinal_cord_injury','neuromuscular','mobility_impairment']::TEXT[],
  TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, TRUE,
  'approximate', FALSE, NULL,
  'approved', 'curated_stl', 'stl_rehab_medical_st_charles', NOW(), NOW(), NOW()
),
(
  'St. Louis Wheelchair (Therapeutic Specialties, Inc.)', 'service', 'crt_vendor',
  '5240 Oakland Ave, Suite A', 'St. Louis', 'MO', '63110', 'US', 38.6290, -90.2760,
  '(314) 291-9900', NULL, NULL, 'Mon–Thu 8:00 AM–4:30 PM', 'Mon–Thu 8:00 AM–4:30 PM',
  'Local complex-rehab wheelchair provider located within Paraquad.',
  'Custom manual wheelchairs, custom power wheelchairs, seating and positioning, equipment fitting, maintenance and repairs, home-accessibility solutions.',
  'St. Louis City and County', 40,
  ARRAY['Complex Rehab Technology','Wheelchairs']::TEXT[], ARRAY['Complex Rehab Technology','Wheelchairs']::TEXT[],
  ARRAY['crt_vendor','repair','home_accessibility']::TEXT[],
  ARRAY['custom_wheelchairs','custom_seating','repairs','equipment_fitting','home_accessibility']::TEXT[],
  ARRAY['adults']::TEXT[], ARRAY['spinal_cord_injury','mobility_impairment']::TEXT[],
  TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, TRUE,
  'approximate', TRUE, 'Hours based on current public listing; confirm seasonal changes.',
  'approved', 'curated_stl', 'stl_wheelchair_therapeutic_specialties', NOW(), NOW(), NOW()
),

-- === Clinical wheelchair evaluation & rehabilitation ===
(
  'WashU Medicine — Wheelchair, Seating, Mobility & Assistive Technology at Paraquad', 'center', 'clinical_eval',
  'Stephen A. Orthwein Center at Paraquad, 5200 Berthold Ave', 'St. Louis', 'MO', '63110', 'US', 38.6280, -90.2770,
  '(314) 286-1669', NULL, NULL, 'By appointment', 'By appointment',
  'Clinical wheelchair/seating evaluation program. Specialist contact: Sue Tucker, OTD, OTR/L, ATP — (314) 273-7008.',
  'Wheelchair and seating evaluations, positioning, mobility assessment, assistive-technology evaluation; clinicians assess functional/clinical requirements and coordinate with wheelchair vendors.',
  'St. Louis metro', 60,
  ARRAY['Seating Evaluation','Assistive Technology','Rehabilitation']::TEXT[], ARRAY['Seating Evaluation','Assistive Technology','Rehabilitation']::TEXT[],
  ARRAY['clinical_eval','seating_eval']::TEXT[],
  ARRAY['wheelchair_evaluation','seating_evaluation','assistive_technology_evaluation','mobility_assessment']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['spinal_cord_injury','neuromuscular','mobility_impairment']::TEXT[],
  FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE,
  'approximate', FALSE, NULL,
  'approved', 'curated_stl', 'stl_washu_wheelchair_seating_paraquad', NOW(), NOW(), NOW()
),
(
  'Paraquad', 'center', 'independent_living',
  '5240 Oakland Ave', 'St. Louis', 'MO', '63110', 'US', 38.6290, -90.2760,
  '(314) 289-4200', NULL, NULL, 'Mon–Fri 8:00 AM–5:00 PM', 'Mon–Fri 8:00 AM–5:00 PM',
  'Independent living / disability resource center with rehabilitation programming. Information & Referral: (314) 289-4266. SCI/Exercise programs: (314) 289-4202.',
  'Disability information and referral, independent-living support, community programs; via the Orthwein Center and WashU relationship: wheelchair/seating/mobility services, adapted exercise, FES therapy and wheelchair wellness programs.',
  'St. Louis metro', 60,
  ARRAY['Independent Living','Disability Services','Rehabilitation']::TEXT[], ARRAY['Independent Living','Disability Services','Rehabilitation']::TEXT[],
  ARRAY['independent_living','clinical_eval']::TEXT[],
  ARRAY['information_referral','independent_living','adapted_exercise','fes_therapy','wheelchair_wellness']::TEXT[],
  ARRAY['adults']::TEXT[], ARRAY['spinal_cord_injury','mobility_impairment']::TEXT[],
  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
  'approximate', FALSE, NULL,
  'approved', 'curated_stl', 'stl_paraquad', NOW(), NOW(), NOW()
),

-- === Repair / rental / retail mobility ===
(
  'Mobility City', 'service', 'repair_rental_retail',
  '2145 Barrett Station Rd', 'Des Peres', 'MO', '63131', 'US', 38.6000, -90.4600,
  '(636) 329-6367', NULL, NULL, NULL, 'Hours not available',
  'Wheelchair repair / rental / mobility equipment. Best fit when the chair is broken rather than when a new custom chair is needed.',
  'Power-wheelchair and scooter repair, manual wheelchair service, equipment rentals, sales, sanitization, durable medical mobility equipment; in-shop and in-home service.',
  'St. Louis metro (in-home service available)', 40,
  ARRAY['Wheelchair Repair','Rentals','Mobility Equipment']::TEXT[], ARRAY['Wheelchair Repair','Rentals','Mobility Equipment']::TEXT[],
  ARRAY['repair','retail_dme']::TEXT[],
  ARRAY['repairs','rentals','sales','sanitization','in_home_service']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['mobility_impairment']::TEXT[],
  TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE,
  'approximate', TRUE, 'Confirm current business hours.',
  'approved', 'curated_stl', 'stl_mobility_city_des_peres', NOW(), NOW(), NOW()
),
(
  'Moose Mobility LLC', 'service', 'repair_rental_retail',
  '10050 Gravois Rd', 'Affton', 'MO', '63123', 'US', 38.5450, -90.3320,
  '(314) 499-7249', 'msabanovic@moosemobilityllc.com', NULL, NULL, 'Hours not available',
  'Wheelchair/DME sales, rental and repair. Repair line: (314) 498-1482. Certified DME technician on staff.',
  'Manual wheelchairs, power wheelchairs, scooters, transport chairs, hospital beds, walkers and other DME; rentals, repairs and consignment sales.',
  'St. Louis metro', 40,
  ARRAY['Wheelchair Repair','Rentals','DME']::TEXT[], ARRAY['Wheelchair Repair','Rentals','DME']::TEXT[],
  ARRAY['repair','retail_dme']::TEXT[],
  ARRAY['repairs','rentals','sales','consignment']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['mobility_impairment']::TEXT[],
  TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
  'approximate', TRUE, 'Address discrepancy: business listings also show 5025 Langley Ave, St. Louis, while the company publishes 10050 Gravois Rd. Verify before production use.',
  'approved', 'curated_stl', 'stl_moose_mobility', NOW(), NOW(), NOW()
),
(
  'MediEquip, Inc. — West County', 'service', 'repair_rental_retail',
  '12852 Manchester Rd', 'Des Peres', 'MO', '63131', 'US', 38.5990, -90.4400,
  '(314) 965-9300', NULL, NULL, 'Mon–Fri 9:00 AM–5:00 PM; Sat 10:00 AM–4:00 PM', 'Mon–Fri 9:00 AM–5:00 PM; Sat 10:00 AM–4:00 PM',
  'Mobility and accessibility equipment retailer/service. Fax: (314) 446-1230.',
  'Mobility and accessibility equipment, rentals, installation and service, with a focus on helping people remain independent at home.',
  'West St. Louis County', 40,
  ARRAY['Mobility Equipment','Accessibility','Rentals']::TEXT[], ARRAY['Mobility Equipment','Accessibility','Rentals']::TEXT[],
  ARRAY['retail_dme','home_accessibility','repair']::TEXT[],
  ARRAY['sales','rentals','installation','service','home_accessibility']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['mobility_impairment']::TEXT[],
  TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE,
  'approximate', FALSE, NULL,
  'approved', 'curated_stl', 'stl_mediequip_west_county', NOW(), NOW(), NOW()
),
(
  'MediEquip, Inc. — South County', 'service', 'repair_rental_retail',
  '5845 S Lindbergh Blvd', 'St. Louis', 'MO', '63123', 'US', 38.5240, -90.3430,
  '(314) 892-7000', NULL, NULL, 'Mon–Fri 9:00 AM–5:00 PM; Sat 10:00 AM–4:00 PM', 'Mon–Fri 9:00 AM–5:00 PM; Sat 10:00 AM–4:00 PM',
  'Mobility and accessibility equipment retailer/service. Fax: (314) 329-9209.',
  'Mobility equipment, rentals, service and home-accessibility equipment.',
  'South St. Louis County', 40,
  ARRAY['Mobility Equipment','Accessibility','Rentals']::TEXT[], ARRAY['Mobility Equipment','Accessibility','Rentals']::TEXT[],
  ARRAY['retail_dme','home_accessibility','repair']::TEXT[],
  ARRAY['sales','rentals','installation','service','home_accessibility']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['mobility_impairment']::TEXT[],
  TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE,
  'approximate', FALSE, NULL,
  'approved', 'curated_stl', 'stl_mediequip_south_county', NOW(), NOW(), NOW()
),
(
  'Provider Plus LLC', 'service', 'general_dme',
  '7748 Watson Rd', 'St. Louis', 'MO', '63119', 'US', 38.5700, -90.3450,
  '(314) 961-8500', NULL, NULL, 'Mon–Fri 8:00 AM–5:00 PM', 'Mon–Fri 8:00 AM–5:00 PM',
  'General DME / medical supply provider. Less specialized in complex seating than CRT vendors.',
  'Home medical equipment and supplies, including mobility equipment.',
  'St. Louis metro', 40,
  ARRAY['DME','Medical Supplies']::TEXT[], ARRAY['DME','Medical Supplies']::TEXT[],
  ARRAY['general_dme']::TEXT[],
  ARRAY['sales','home_medical_equipment']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['mobility_impairment']::TEXT[],
  FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE,
  'approximate', FALSE, NULL,
  'approved', 'curated_stl', 'stl_provider_plus', NOW(), NOW(), NOW()
),
(
  'Med X Change LLC', 'service', 'general_dme',
  '325 S 5th St', 'St. Charles', 'MO', '63301', 'US', 38.7770, -90.4820,
  '(636) 949-5660', NULL, NULL, 'Mon–Fri 9:00 AM–5:00 PM', 'Mon–Fri 9:00 AM–5:00 PM',
  'DME / mobility equipment provider serving St. Charles and the broader St. Louis metro.',
  'Medical and mobility equipment and supplies.',
  'St. Charles County and St. Louis metro', 40,
  ARRAY['DME','Mobility Equipment']::TEXT[], ARRAY['DME','Mobility Equipment']::TEXT[],
  ARRAY['general_dme']::TEXT[],
  ARRAY['sales','rentals','home_medical_equipment']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['mobility_impairment']::TEXT[],
  FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
  'approximate', FALSE, NULL,
  'approved', 'curated_stl', 'stl_med_x_change', NOW(), NOW(), NOW()
),

-- === Home accessibility ===
(
  '101 Mobility of St. Louis', 'service', 'home_accessibility',
  '831 Westwood Industrial Park Dr, Suite 101', 'Weldon Spring', 'MO', '63304', 'US', 38.7180, -90.6890,
  '(636) 447-1414', NULL, NULL, 'Mon–Fri 8:00 AM–4:00 PM', 'Mon–Fri 8:00 AM–4:00 PM',
  'Home mobility/accessibility company. Best fit for making the environment accessible rather than obtaining a custom wheelchair.',
  'Wheelchair ramps, stairlifts, home elevators, patient lifts and other home-accessibility systems; consultations and installation.',
  'Greater St. Louis metro', 50,
  ARRAY['Home Accessibility','Ramps','Lifts']::TEXT[], ARRAY['Home Accessibility','Ramps','Lifts']::TEXT[],
  ARRAY['home_accessibility']::TEXT[],
  ARRAY['ramps','stairlifts','home_elevators','patient_lifts','installation','in_home_assessment']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['mobility_impairment','spinal_cord_injury']::TEXT[],
  TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE,
  'approximate', FALSE, NULL,
  'approved', 'curated_stl', 'stl_101_mobility', NOW(), NOW(), NOW()
),
(
  'Next Day Access St. Louis', 'service', 'home_accessibility',
  '', 'St. Louis', 'MO', NULL, 'US', 38.6270, -90.1994,
  '(314) 710-2158', NULL, NULL, NULL, 'Call/text for consultation',
  'Residential/commercial accessibility contractor. Mobile/service-area based (no storefront address recorded).',
  'Wheelchair ramps, stair lifts, vertical platform lifts, grab bars, bathroom-safety modifications, patient lifts, pool lifts and other accessibility modifications; on-site assessments and installation.',
  'Greater St. Louis incl. Ballwin, Chesterfield, Clayton, Kirkwood, St. Charles, Franklin and Jefferson Counties', 60,
  ARRAY['Home Accessibility','Ramps','Lifts']::TEXT[], ARRAY['Home Accessibility','Ramps','Lifts']::TEXT[],
  ARRAY['home_accessibility']::TEXT[],
  ARRAY['ramps','stair_lifts','platform_lifts','grab_bars','bathroom_safety','patient_lifts','installation','in_home_assessment']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['mobility_impairment','spinal_cord_injury']::TEXT[],
  FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE,
  'service_area_only', TRUE, 'No storefront address; coordinates are metro centroid. Verify published phone number periodically.',
  'approved', 'curated_stl', 'stl_next_day_access', NOW(), NOW(), NOW()
),
(
  'Mobility Plus Ballwin', 'service', 'repair_rental_retail',
  '15461 Clayton Rd', 'Ballwin', 'MO', '63011', 'US', 38.6150, -90.5300,
  '(314) 608-5789', NULL, NULL, NULL, 'Hours not available',
  'Local mobility equipment / accessibility provider for West County.',
  'Mobility scooters, ramps and lifts; equipment sales, repairs and rentals; home visits, installations and custom accessibility projects.',
  'West St. Louis County', 40,
  ARRAY['Mobility Equipment','Accessibility','Repairs']::TEXT[], ARRAY['Mobility Equipment','Accessibility','Repairs']::TEXT[],
  ARRAY['retail_dme','repair','home_accessibility']::TEXT[],
  ARRAY['sales','repairs','rentals','ramps','lifts','installation','in_home_service']::TEXT[],
  ARRAY['adults','pediatric']::TEXT[], ARRAY['mobility_impairment']::TEXT[],
  TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE,
  'approximate', TRUE, 'Confirm current business hours.',
  'approved', 'curated_stl', 'stl_mobility_plus_ballwin', NOW(), NOW(), NOW()
)
ON CONFLICT (source, source_id) DO UPDATE SET
  name = EXCLUDED.name,
  provider_type = EXCLUDED.provider_type,
  address = EXCLUDED.address,
  city = EXCLUDED.city,
  state = EXCLUDED.state,
  postal_code = EXCLUDED.postal_code,
  lat = EXCLUDED.lat,
  lng = EXCLUDED.lng,
  phone = EXCLUDED.phone,
  contact_email = EXCLUDED.contact_email,
  hours = EXCLUDED.hours,
  availability = EXCLUDED.availability,
  description = EXCLUDED.description,
  services_offered = EXCLUDED.services_offered,
  service_area = EXCLUDED.service_area,
  service_area_radius_miles = EXCLUDED.service_area_radius_miles,
  specialty = EXCLUDED.specialty,
  specialties = EXCLUDED.specialties,
  service_kinds = EXCLUDED.service_kinds,
  capabilities = EXCLUDED.capabilities,
  populations_served = EXCLUDED.populations_served,
  conditions_served = EXCLUDED.conditions_served,
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
  verification_notes = EXCLUDED.verification_notes,
  status = EXCLUDED.status,
  last_verified_at = EXCLUDED.last_verified_at,
  updated_at = NOW();
