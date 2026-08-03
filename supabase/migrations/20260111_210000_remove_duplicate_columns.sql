-- Remove duplicate lowercase columns from resource_suggestions table
ALTER TABLE resource_suggestions 
  DROP COLUMN IF EXISTS postalcode,
  DROP COLUMN IF EXISTS contactemail;
