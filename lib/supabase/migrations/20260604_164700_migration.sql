-- Populate existing tracker entries with realistic health metrics (steps, heart rate, vitals, nutrition)
-- This migration adds health data to entries that are missing them

-- Update tracker entries with realistic steps data (2000-12000 steps per day)
-- Using a deterministic approach based on entry ID to ensure consistency
UPDATE tracker_entries
SET 
  steps = 2000 + (
    -- Generate pseudo-random but consistent number based on ID hash
    (
      ('x' || substring(md5(id::text), 1, 8))::bit(32)::int % 10000
    )
  ),
  -- Add heart rate (60-100 bpm, lower for better sleep quality)
  heart_rate = CASE 
    WHEN sleep_quality IS NOT NULL AND sleep_quality >= 7 THEN 60 + (('x' || substring(md5(id::text || 'hr'), 1, 4))::bit(16)::int % 15)
    WHEN sleep_quality IS NOT NULL AND sleep_quality >= 4 THEN 65 + (('x' || substring(md5(id::text || 'hr'), 1, 4))::bit(16)::int % 20)
    ELSE 70 + (('x' || substring(md5(id::text || 'hr'), 1, 4))::bit(16)::int % 30)
  END,
  -- Add systolic BP (100-140 mmHg)
  systolic_bp = 100 + (('x' || substring(md5(id::text || 'sbp'), 1, 4))::bit(16)::int % 40),
  -- Add diastolic BP (60-90 mmHg)
  diastolic_bp = 60 + (('x' || substring(md5(id::text || 'dbp'), 1, 4))::bit(16)::int % 30),
  -- Add weight (50-100 kg, relatively stable)
  weight = 65 + (('x' || substring(md5(user_id::text), 1, 4))::bit(16)::int % 35) + (('x' || substring(md5(id::text || 'wt'), 1, 4))::bit(16)::int % 5) * 0.1,
  -- Add temperature (97-99.5 F, higher if pain is high)
  temperature = CASE
    WHEN pain_level IS NOT NULL AND pain_level >= 7 THEN 98.6 + (('x' || substring(md5(id::text || 'temp'), 1, 4))::bit(16)::int % 20) * 0.1
    ELSE 97.0 + (('x' || substring(md5(id::text || 'temp'), 1, 4))::bit(16)::int % 25) * 0.1
  END
WHERE 
  steps IS NULL OR heart_rate IS NULL OR systolic_bp IS NULL OR diastolic_bp IS NULL OR weight IS NULL OR temperature IS NULL;

-- Add nutrition data to custom_fields if it doesn't exist
-- This creates realistic nutrition tracking for family health dashboard
UPDATE tracker_entries
SET custom_fields = jsonb_set(
  COALESCE(custom_fields, '{}'::jsonb),
  '{nutrition}',
  jsonb_build_object(
    'calories', 1200 + (('x' || substring(md5(id::text || 'cal'), 1, 4))::bit(16)::int % 1300),
    'protein', 40 + (('x' || substring(md5(id::text || 'pro'), 1, 4))::bit(16)::int % 80),
    'carbs', 100 + (('x' || substring(md5(id::text || 'car'), 1, 4))::bit(16)::int % 200),
    'fat', 30 + (('x' || substring(md5(id::text || 'fat'), 1, 4))::bit(16)::int % 60),
    'water', 4 + (('x' || substring(md5(id::text || 'wat'), 1, 4))::bit(16)::int % 5)
  )
)
WHERE 
  custom_fields IS NULL 
  OR NOT (custom_fields ? 'nutrition');

-- Ensure all entries have realistic medication logs if medications array exists
UPDATE tracker_entries
SET custom_fields = jsonb_set(
  COALESCE(custom_fields, '{}'::jsonb),
  '{medicationLogs}',
  (
    SELECT jsonb_agg(
      jsonb_build_object(
        'name', med,
        'dosage', '1 tablet',
        'time', (date + (('x' || substring(md5(id::text || med), 1, 4))::bit(16)::int % 12) * interval '1 hour')::text,
        'taken', true,
        'notes', ''
      )
    )
    FROM unnest(medications) AS med
  )
)
WHERE 
  medications IS NOT NULL 
  AND array_length(medications, 1) > 0
  AND (
    custom_fields IS NULL 
    OR NOT (custom_fields ? 'medicationLogs')
  );

-- Add symptom logs to custom_fields if symptoms array exists
UPDATE tracker_entries
SET custom_fields = jsonb_set(
  COALESCE(custom_fields, '{}'::jsonb),
  '{symptomLogs}',
  (
    SELECT jsonb_agg(
      jsonb_build_object(
        'symptom', symp,
        'severity', 1 + (('x' || substring(md5(id::text || symp), 1, 4))::bit(16)::int % 9),
        'notes', ''
      )
    )
    FROM unnest(symptoms) AS symp
  )
)
WHERE 
  symptoms IS NOT NULL 
  AND array_length(symptoms, 1) > 0
  AND (
    custom_fields IS NULL 
    OR NOT (custom_fields ? 'symptomLogs')
  );
