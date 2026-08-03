-- Fix RLS policies for resource_suggestions table to allow authenticated users to insert

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can insert their own suggestions" ON resource_suggestions;
DROP POLICY IF EXISTS "Users can view their own suggestions" ON resource_suggestions;
DROP POLICY IF EXISTS "Admins can view all suggestions" ON resource_suggestions;
DROP POLICY IF EXISTS "Admins can update suggestions" ON resource_suggestions;

-- Enable RLS if not already enabled
ALTER TABLE resource_suggestions ENABLE ROW LEVEL SECURITY;

-- Allow any authenticated user to insert suggestions
CREATE POLICY "Authenticated users can insert suggestions"
  ON resource_suggestions
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Allow users to view their own suggestions
CREATE POLICY "Users can view their own suggestions"
  ON resource_suggestions
  FOR SELECT
  TO authenticated
  USING (submitted_by_uid = auth.uid()::text);

-- Allow admins to view all suggestions (check if user has admin role in users table)
CREATE POLICY "Admins can view all suggestions"
  ON resource_suggestions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid()::text 
      AND users.role = 'admin'
    )
  );

-- Allow admins to update suggestions
CREATE POLICY "Admins can update suggestions"
  ON resource_suggestions
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid()::text 
      AND users.role = 'admin'
    )
  );
