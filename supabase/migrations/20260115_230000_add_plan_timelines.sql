-- Plan timelines to store multiple versions of a user's condition plan
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

CREATE INDEX IF NOT EXISTS plan_timelines_user_condition_idx ON plan_timelines(user_id, condition_id);
CREATE UNIQUE INDEX IF NOT EXISTS plan_timelines_one_current_per_condition
  ON plan_timelines(user_id, condition_id)
  WHERE is_current = true;