-- Fix RLS policy for resource_suggestions table
-- The INSERT policy was checking 'created_by' column, but the app uses 'submitted_by_uid'

-- Drop the old policy that references the wrong column
DROP POLICY IF EXISTS "Authenticated users can create suggestions" ON resource_suggestions;

-- Create a new INSERT policy that doesn't check column ownership, just authentication
CREATE POLICY "Authenticated users can create suggestions" 
ON resource_suggestions 
FOR INSERT 
WITH CHECK (auth.role() = 'authenticated');

-- Also update the SELECT policy to check both old and new column names
DROP POLICY IF EXISTS "Anyone can view approved suggestions" ON resource_suggestions;
CREATE POLICY "Anyone can view approved suggestions" 
ON resource_suggestions 
FOR SELECT 
USING (
  status = 'approved' 
  OR auth.uid() = created_by 
  OR auth.uid() = submitted_by_uid
);

-- Update the UPDATE policy to check both column names too
DROP POLICY IF EXISTS "Creators can update their suggestions" ON resource_suggestions;
CREATE POLICY "Creators can update their suggestions" 
ON resource_suggestions 
FOR UPDATE 
USING (
  auth.uid() = created_by 
  OR auth.uid() = submitted_by_uid
);
