-- Add RLS policies for patient_notes and patient_resources tables
-- These policies allow authenticated patients to read their own notes and resources

-- Enable RLS on patients table (if not already)
ALTER TABLE IF EXISTS public.patients ENABLE ROW LEVEL SECURITY;

-- Enable RLS on patient_notes table (if not already)
ALTER TABLE IF EXISTS public.patient_notes ENABLE ROW LEVEL SECURITY;

-- Enable RLS on patient_resources table (if not already)
ALTER TABLE IF EXISTS public.patient_resources ENABLE ROW LEVEL SECURITY;

-- Policy: Allow users to select their own patient record
DROP POLICY IF EXISTS "patients_select_own" ON public.patients;
CREATE POLICY "patients_select_own" ON public.patients
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Policy: Allow patients to select notes visible to them
-- This checks that the note belongs to the patient record linked to the current user
-- and that the visibility is either 'patient_visible' or 'family_visible'
DROP POLICY IF EXISTS "patient_notes_select_own" ON public.patient_notes;
CREATE POLICY "patient_notes_select_own" ON public.patient_notes
  FOR SELECT
  TO authenticated
  USING (
    patient_id IN (
      SELECT id FROM public.patients WHERE user_id = auth.uid()
    )
    AND visibility IN ('patient_visible', 'family_visible')
  );

-- Policy: Allow patients to select resources visible to them
-- This checks that the resource belongs to the patient record linked to the current user
-- and that the visibility is either 'patient_only' or 'family_visible'
DROP POLICY IF EXISTS "patient_resources_select_own" ON public.patient_resources;
CREATE POLICY "patient_resources_select_own" ON public.patient_resources
  FOR SELECT
  TO authenticated
  USING (
    patient_id IN (
      SELECT id FROM public.patients WHERE user_id = auth.uid()
    )
    AND visibility IN ('patient_only', 'family_visible')
  );
