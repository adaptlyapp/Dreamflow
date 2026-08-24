-- Fix family_patient_links foreign key constraints
-- The table was referencing non-existent 'patients' table instead of 'users' table

-- Step 1: Drop the old foreign key constraints
ALTER TABLE family_patient_links 
  DROP CONSTRAINT IF EXISTS family_patient_links_patient_id_fkey;

ALTER TABLE family_patient_links 
  DROP CONSTRAINT IF EXISTS family_patient_links_family_member_id_fkey;

-- Step 2: Delete any invalid records that reference non-existent users
-- Remove records where patient_id doesn't exist in auth.users
DELETE FROM family_patient_links 
WHERE patient_id NOT IN (SELECT id FROM auth.users);

-- Remove records where family_member_id doesn't exist in auth.users
DELETE FROM family_patient_links 
WHERE family_member_id NOT IN (SELECT id FROM auth.users);

-- Step 3: Add correct foreign key constraints that reference auth.users(id)
ALTER TABLE family_patient_links 
  ADD CONSTRAINT family_patient_links_patient_id_fkey 
  FOREIGN KEY (patient_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE family_patient_links 
  ADD CONSTRAINT family_patient_links_family_member_id_fkey 
  FOREIGN KEY (family_member_id) REFERENCES auth.users(id) ON DELETE CASCADE;
