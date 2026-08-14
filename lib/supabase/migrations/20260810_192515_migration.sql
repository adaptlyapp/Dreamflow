-- Migration: Clean up duplicate journeys
-- Description: Remove duplicate journey entries, keeping only the most recent for each user/condition/domain combination

-- Step 1: Delete all journey-related child records for duplicate journeys
-- This ensures referential integrity before deleting parent journey records

-- Delete tasks for goals of milestones of phases of duplicate journeys
DELETE FROM journey_tasks
WHERE goal_id IN (
  SELECT jg.id 
  FROM journey_goals jg
  INNER JOIN journey_milestones jm ON jg.milestone_id = jm.id
  INNER JOIN phases p ON jm.phase_id = p.id
  INNER JOIN journeys j ON p.journey_id = j.id
  WHERE j.id NOT IN (
    -- Keep only the most recent journey for each user/condition/domain combo
    SELECT DISTINCT ON (user_id, condition_id, domain_type) id
    FROM journeys
    ORDER BY user_id, condition_id, domain_type, created_at DESC
  )
);

-- Delete goals for milestones of phases of duplicate journeys
DELETE FROM journey_goals
WHERE milestone_id IN (
  SELECT jm.id 
  FROM journey_milestones jm
  INNER JOIN phases p ON jm.phase_id = p.id
  INNER JOIN journeys j ON p.journey_id = j.id
  WHERE j.id NOT IN (
    SELECT DISTINCT ON (user_id, condition_id, domain_type) id
    FROM journeys
    ORDER BY user_id, condition_id, domain_type, created_at DESC
  )
);

-- Delete milestones for phases of duplicate journeys
DELETE FROM journey_milestones
WHERE phase_id IN (
  SELECT p.id 
  FROM phases p
  INNER JOIN journeys j ON p.journey_id = j.id
  WHERE j.id NOT IN (
    SELECT DISTINCT ON (user_id, condition_id, domain_type) id
    FROM journeys
    ORDER BY user_id, condition_id, domain_type, created_at DESC
  )
);

-- Delete phases of duplicate journeys
DELETE FROM phases
WHERE journey_id NOT IN (
  SELECT DISTINCT ON (user_id, condition_id, domain_type) id
  FROM journeys
  ORDER BY user_id, condition_id, domain_type, created_at DESC
);

-- Step 2: Delete duplicate journey records
-- Keep only the most recent journey for each unique combination of user_id, condition_id, and domain_type
DELETE FROM journeys
WHERE id NOT IN (
  SELECT DISTINCT ON (user_id, condition_id, domain_type) id
  FROM journeys
  ORDER BY user_id, condition_id, domain_type, created_at DESC
);

-- Step 3: Clean up orphaned recovery domains (domains without any journeys)
DELETE FROM recovery_domains
WHERE user_id IN (
  SELECT DISTINCT user_id FROM journeys
)
AND type NOT IN (
  SELECT DISTINCT domain_type FROM journeys WHERE domain_type IS NOT NULL
);
