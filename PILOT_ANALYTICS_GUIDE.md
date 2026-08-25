# Adaptly Pilot Study Analytics Guide
## Database Queries & Data Points for Outcome Measurement

---

## 📊 Outcome 1: Patient Engagement
**Testing Method:** Usage analytics

### Key Metrics to Track

#### 1. Daily Active Users (DAU) & Weekly Active Users (WAU)
```sql
-- Daily Active Users
SELECT 
  DATE(created_at) as date,
  COUNT(DISTINCT user_id) as daily_active_users
FROM tracker_entries
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Weekly Active Users
SELECT 
  DATE_TRUNC('week', created_at) as week,
  COUNT(DISTINCT user_id) as weekly_active_users
FROM tracker_entries
WHERE created_at >= NOW() - INTERVAL '90 days'
GROUP BY week
ORDER BY week DESC;
```

#### 2. Feature Usage Breakdown
```sql
-- Tracker usage (health logging)
SELECT 
  user_id,
  COUNT(*) as total_entries,
  COUNT(DISTINCT DATE(date)) as unique_days_logged,
  AVG(CASE WHEN pain_level IS NOT NULL THEN 1 ELSE 0 END) * 100 as pain_tracking_rate,
  AVG(CASE WHEN steps IS NOT NULL THEN 1 ELSE 0 END) * 100 as steps_tracking_rate,
  AVG(CASE WHEN sleep_quality IS NOT NULL THEN 1 ELSE 0 END) * 100 as sleep_tracking_rate
FROM tracker_entries
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY user_id;

-- Journey/Goal engagement
SELECT 
  user_id,
  COUNT(*) as total_goals,
  SUM(CASE WHEN completed THEN 1 ELSE 0 END) as completed_goals,
  ROUND(SUM(CASE WHEN completed THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100, 2) as completion_rate
FROM goals
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY user_id;

-- Resource discovery
SELECT 
  created_by as user_id,
  COUNT(*) as resources_viewed,
  COUNT(DISTINCT type) as resource_types_explored
FROM resource_suggestions
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY created_by;

-- Community participation
SELECT 
  author_id as user_id,
  COUNT(*) as posts_created,
  SUM(likes_count) as total_likes_received,
  SUM(comments_count) as total_comments_received
FROM posts
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY author_id;
```

#### 3. Session Duration & Frequency
```sql
-- Average time between tracker entries (proxy for session frequency)
WITH user_sessions AS (
  SELECT 
    user_id,
    created_at,
    LEAD(created_at) OVER (PARTITION BY user_id ORDER BY created_at) - created_at as time_between_sessions
  FROM tracker_entries
  WHERE created_at >= NOW() - INTERVAL '30 days'
)
SELECT 
  user_id,
  COUNT(*) as session_count,
  AVG(time_between_sessions) as avg_time_between_sessions,
  MIN(time_between_sessions) as shortest_gap,
  MAX(time_between_sessions) as longest_gap
FROM user_sessions
WHERE time_between_sessions IS NOT NULL
GROUP BY user_id;
```

#### 4. Retention Rate
```sql
-- Weekly retention cohort analysis
WITH first_week AS (
  SELECT 
    user_id,
    DATE_TRUNC('week', MIN(created_at)) as cohort_week
  FROM tracker_entries
  GROUP BY user_id
),
weekly_activity AS (
  SELECT DISTINCT
    user_id,
    DATE_TRUNC('week', created_at) as activity_week
  FROM tracker_entries
)
SELECT 
  fw.cohort_week,
  COUNT(DISTINCT fw.user_id) as cohort_size,
  COUNT(DISTINCT CASE WHEN wa.activity_week = fw.cohort_week + INTERVAL '1 week' THEN wa.user_id END) as week_1_retained,
  COUNT(DISTINCT CASE WHEN wa.activity_week = fw.cohort_week + INTERVAL '2 weeks' THEN wa.user_id END) as week_2_retained,
  COUNT(DISTINCT CASE WHEN wa.activity_week = fw.cohort_week + INTERVAL '4 weeks' THEN wa.user_id END) as week_4_retained
FROM first_week fw
LEFT JOIN weekly_activity wa ON fw.user_id = wa.user_id
GROUP BY fw.cohort_week
ORDER BY fw.cohort_week DESC;
```

---

## 🎯 Outcome 2: Recovery Preparedness
**Testing Method:** Pre/post survey + app usage data

### Key Metrics to Track

#### 1. Recovery Blueprint Completion
```sql
-- Blueprint creation and completeness
SELECT 
  user_id,
  created_at as blueprint_created_date,
  CASE 
    WHEN jsonb_array_length(care_team) > 0 THEN 1 ELSE 0 
  END as has_care_team,
  CASE 
    WHEN jsonb_array_length(daily_routines) > 0 THEN 1 ELSE 0 
  END as has_daily_routines,
  CASE 
    WHEN jsonb_array_length(equipment) > 0 THEN 1 ELSE 0 
  END as has_equipment_list,
  CASE 
    WHEN jsonb_array_length(supplies) > 0 THEN 1 ELSE 0 
  END as has_supplies_list,
  CASE 
    WHEN roadmap IS NOT NULL THEN 1 ELSE 0 
  END as has_roadmap,
  (
    CASE WHEN jsonb_array_length(care_team) > 0 THEN 1 ELSE 0 END +
    CASE WHEN jsonb_array_length(daily_routines) > 0 THEN 1 ELSE 0 END +
    CASE WHEN jsonb_array_length(equipment) > 0 THEN 1 ELSE 0 END +
    CASE WHEN jsonb_array_length(supplies) > 0 THEN 1 ELSE 0 END +
    CASE WHEN roadmap IS NOT NULL THEN 1 ELSE 0 END
  ) * 20 as blueprint_completion_percentage
FROM recovery_blueprints;
```

#### 2. Journey Progress (Recovery Domain Coverage)
```sql
-- Domain-specific progress tracking
SELECT 
  user_id,
  type as recovery_domain,
  completed_phases,
  total_phases,
  CASE 
    WHEN total_phases > 0 THEN ROUND((completed_phases::NUMERIC / total_phases) * 100, 2)
    ELSE 0 
  END as domain_completion_percentage,
  last_activity_at
FROM recovery_domains
ORDER BY user_id, type;

-- Journey milestone completion rates
SELECT 
  jm.user_id,
  COUNT(*) as total_milestones,
  SUM(CASE WHEN jm.status = 'completed' THEN 1 ELSE 0 END) as completed_milestones,
  ROUND(SUM(CASE WHEN jm.status = 'completed' THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100, 2) as milestone_completion_rate,
  AVG(EXTRACT(EPOCH FROM (jm.completed_at - jm.started_at)) / 86400) as avg_days_to_complete
FROM journey_milestones jm
WHERE jm.started_at IS NOT NULL
GROUP BY jm.user_id;
```

#### 3. Education Resource Engagement
```sql
-- Education content viewed (milestone education)
SELECT 
  user_id,
  COUNT(DISTINCT id) as milestones_with_education_viewed,
  COUNT(CASE WHEN education_content IS NOT NULL THEN 1 END) as education_milestones_available
FROM journey_milestones
WHERE completed_at IS NOT NULL OR started_at IS NOT NULL
GROUP BY user_id;
```

#### 4. Pre/Post Survey Comparison (Manual Data Entry)
```sql
-- Create a survey responses table to track pre/post assessments
CREATE TABLE IF NOT EXISTS pilot_survey_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  survey_type TEXT NOT NULL, -- 'pre' or 'post'
  question_id TEXT NOT NULL,
  question_text TEXT NOT NULL,
  response_value INTEGER, -- Likert scale 1-5
  response_text TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Query for pre/post comparison
WITH pre_scores AS (
  SELECT 
    user_id,
    AVG(response_value) as pre_avg_score
  FROM pilot_survey_responses
  WHERE survey_type = 'pre'
  GROUP BY user_id
),
post_scores AS (
  SELECT 
    user_id,
    AVG(response_value) as post_avg_score
  FROM pilot_survey_responses
  WHERE survey_type = 'post'
  GROUP BY user_id
)
SELECT 
  pre.user_id,
  pre.pre_avg_score,
  post.post_avg_score,
  post.post_avg_score - pre.pre_avg_score as improvement_score,
  ROUND(((post.post_avg_score - pre.pre_avg_score) / pre.pre_avg_score) * 100, 2) as improvement_percentage
FROM pre_scores pre
LEFT JOIN post_scores post ON pre.user_id = post.user_id;
```

---

## 👥 Outcome 3: Patient Usability
**Testing Method:** Task-based testing + app analytics

### Key Metrics to Track

#### 1. Task Completion Rates
```sql
-- Journey tasks completion
SELECT 
  user_id,
  COUNT(*) as total_tasks_assigned,
  SUM(CASE WHEN completed THEN 1 ELSE 0 END) as tasks_completed,
  ROUND(SUM(CASE WHEN completed THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100, 2) as task_completion_rate,
  AVG(EXTRACT(EPOCH FROM (completed_at - created_at)) / 3600) as avg_hours_to_complete
FROM journey_tasks
GROUP BY user_id;
```

#### 2. Error Rate / Failed Attempts (Manual Logging)
```sql
-- Create error tracking table
CREATE TABLE IF NOT EXISTS pilot_usability_errors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  feature_name TEXT NOT NULL, -- 'tracker', 'blueprint', 'journey', etc.
  error_type TEXT NOT NULL, -- 'navigation', 'form_validation', 'crash', etc.
  error_description TEXT,
  severity TEXT, -- 'low', 'medium', 'high', 'critical'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Query error rates by feature
SELECT 
  feature_name,
  COUNT(*) as error_count,
  COUNT(CASE WHEN severity IN ('high', 'critical') THEN 1 END) as critical_errors,
  COUNT(DISTINCT user_id) as users_affected
FROM pilot_usability_errors
GROUP BY feature_name
ORDER BY error_count DESC;
```

#### 3. Feature Discovery Time
```sql
-- Time to first use of key features
WITH first_tracker_entry AS (
  SELECT user_id, MIN(created_at) as first_tracker_use
  FROM tracker_entries GROUP BY user_id
),
first_blueprint AS (
  SELECT user_id, MIN(created_at) as first_blueprint_use
  FROM recovery_blueprints GROUP BY user_id
),
first_journey AS (
  SELECT user_id, MIN(created_at) as first_journey_use
  FROM journeys GROUP BY user_id
),
user_onboarding AS (
  SELECT id as user_id, created_at as signup_date
  FROM users
)
SELECT 
  uo.user_id,
  EXTRACT(EPOCH FROM (fte.first_tracker_use - uo.signup_date)) / 60 as minutes_to_tracker,
  EXTRACT(EPOCH FROM (fb.first_blueprint_use - uo.signup_date)) / 60 as minutes_to_blueprint,
  EXTRACT(EPOCH FROM (fj.first_journey_use - uo.signup_date)) / 60 as minutes_to_journey
FROM user_onboarding uo
LEFT JOIN first_tracker_entry fte ON uo.user_id = fte.user_id
LEFT JOIN first_blueprint fb ON uo.user_id = fb.user_id
LEFT JOIN first_journey fj ON uo.user_id = fj.user_id;
```

---

## 👨‍👩‍👧 Outcome 4: Family Confidence
**Testing Method:** Pre/post survey + family feature usage

### Key Metrics to Track

#### 1. Family Member Account Creation & Linkage
```sql
-- Family connections established
SELECT 
  COUNT(*) as total_family_links,
  COUNT(DISTINCT patient_id) as patients_with_family,
  COUNT(DISTINCT family_member_id) as total_family_members,
  AVG(family_per_patient) as avg_family_per_patient
FROM (
  SELECT 
    patient_id,
    COUNT(DISTINCT family_member_id) as family_per_patient
  FROM family_patient_links
  GROUP BY patient_id
) subquery;
```

#### 2. Family Data Entry Activity
```sql
-- Health logs created by family members (not patient)
SELECT 
  fpl.family_member_id,
  u.name as family_member_name,
  COUNT(te.id) as health_logs_created,
  COUNT(DISTINCT fpl.patient_id) as patients_supported
FROM tracker_entries te
JOIN family_patient_links fpl ON te.created_by_user_id = fpl.family_member_id
LEFT JOIN users u ON fpl.family_member_id = u.id
WHERE te.created_by_user_id != te.user_id
GROUP BY fpl.family_member_id, u.name;
```

#### 3. Family Feature Usage
```sql
-- Dashboard views, notes added, schedule engagement
-- (Requires creating activity tracking table)
CREATE TABLE IF NOT EXISTS pilot_family_activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_member_id UUID NOT NULL REFERENCES auth.users(id),
  patient_id UUID NOT NULL REFERENCES auth.users(id),
  activity_type TEXT NOT NULL, -- 'dashboard_view', 'note_added', 'schedule_view', 'health_log_added'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Query family engagement
SELECT 
  family_member_id,
  COUNT(*) as total_activities,
  COUNT(CASE WHEN activity_type = 'dashboard_view' THEN 1 END) as dashboard_views,
  COUNT(CASE WHEN activity_type = 'note_added' THEN 1 END) as notes_added,
  COUNT(CASE WHEN activity_type = 'health_log_added' THEN 1 END) as health_logs_added,
  COUNT(DISTINCT DATE(created_at)) as active_days
FROM pilot_family_activity_log
GROUP BY family_member_id;
```

#### 4. Family Confidence Survey (Pre/Post)
```sql
-- Use same survey table as patient preparedness, filtered by role
SELECT 
  psr.user_id,
  u.role,
  psr.survey_type,
  AVG(psr.response_value) as avg_confidence_score
FROM pilot_survey_responses psr
JOIN users u ON psr.user_id = u.id
WHERE u.role = 'family_member' 
  AND psr.question_id LIKE 'confidence_%'
GROUP BY psr.user_id, u.role, psr.survey_type;
```

---

## 🏥 Outcome 5: Clinician Usefulness
**Testing Method:** Clinician assessment + feedback surveys

### Key Metrics to Track

#### 1. Care Team Documented
```sql
-- Care team members added to blueprints
SELECT 
  user_id,
  jsonb_array_length(care_team) as care_team_size,
  care_team
FROM recovery_blueprints
WHERE jsonb_array_length(care_team) > 0;
```

#### 2. Patient Data Completeness (Clinical Utility)
```sql
-- Comprehensive data capture for clinical review
SELECT 
  user_id,
  COUNT(*) as total_tracker_entries,
  COUNT(CASE WHEN pain_level IS NOT NULL THEN 1 END) as pain_entries,
  COUNT(CASE WHEN medications IS NOT NULL AND array_length(medications, 1) > 0 THEN 1 END) as med_entries,
  COUNT(CASE WHEN heart_rate IS NOT NULL THEN 1 END) as vitals_entries,
  COUNT(CASE WHEN steps IS NOT NULL THEN 1 END) as activity_entries,
  COUNT(CASE WHEN custom_fields ? 'nutrition' THEN 1 END) as nutrition_entries,
  ROUND(
    (
      COUNT(CASE WHEN pain_level IS NOT NULL THEN 1 END) +
      COUNT(CASE WHEN medications IS NOT NULL THEN 1 END) +
      COUNT(CASE WHEN heart_rate IS NOT NULL THEN 1 END) +
      COUNT(CASE WHEN steps IS NOT NULL THEN 1 END) +
      COUNT(CASE WHEN custom_fields ? 'nutrition' THEN 1 END)
    )::NUMERIC / (COUNT(*) * 5) * 100, 2
  ) as data_completeness_percentage
FROM tracker_entries
GROUP BY user_id;
```

#### 3. Clinician Survey Responses (Manual)
```sql
-- Create clinician feedback table
CREATE TABLE IF NOT EXISTS pilot_clinician_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinician_id TEXT NOT NULL, -- Anonymous ID
  clinician_role TEXT, -- 'physician', 'nurse', 'pt', 'ot', etc.
  patient_id UUID REFERENCES auth.users(id),
  question_id TEXT NOT NULL,
  question_text TEXT NOT NULL,
  response_value INTEGER, -- Likert 1-5
  response_text TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Aggregate clinician usefulness scores
SELECT 
  clinician_role,
  COUNT(DISTINCT clinician_id) as clinician_count,
  AVG(response_value) as avg_usefulness_score,
  COUNT(*) as total_responses
FROM pilot_clinician_feedback
GROUP BY clinician_role;
```

---

## ⏱️ Outcome 6: Workflow Burden
**Testing Method:** Time tracking + staff feedback

### Key Metrics to Track

#### 1. Time to Complete Key Tasks (Manual Logging)
```sql
-- Create time tracking table
CREATE TABLE IF NOT EXISTS pilot_workflow_time_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  user_role TEXT NOT NULL, -- 'patient', 'family_member', 'clinician'
  task_name TEXT NOT NULL, -- 'create_blueprint', 'log_health_data', 'review_patient_data', etc.
  time_spent_seconds INTEGER NOT NULL,
  completed BOOLEAN DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Average time by task
SELECT 
  task_name,
  user_role,
  COUNT(*) as task_count,
  AVG(time_spent_seconds) / 60 as avg_minutes,
  MIN(time_spent_seconds) / 60 as min_minutes,
  MAX(time_spent_seconds) / 60 as max_minutes,
  STDDEV(time_spent_seconds) / 60 as stddev_minutes
FROM pilot_workflow_time_tracking
WHERE completed = true
GROUP BY task_name, user_role
ORDER BY avg_minutes DESC;
```

#### 2. Staff Survey - Perceived Burden
```sql
-- Use clinician feedback table with burden-specific questions
SELECT 
  clinician_role,
  AVG(CASE WHEN question_id = 'burden_time' THEN response_value END) as avg_time_burden,
  AVG(CASE WHEN question_id = 'burden_complexity' THEN response_value END) as avg_complexity_burden,
  AVG(CASE WHEN question_id = 'burden_overall' THEN response_value END) as avg_overall_burden
FROM pilot_clinician_feedback
WHERE question_id LIKE 'burden_%'
GROUP BY clinician_role;
```

---

## 📈 Outcome 7: Resource Utilization
**Testing Method:** Adaptly analytics + hospital data

### Key Metrics to Track

#### 1. Resources Discovered & Applied To
```sql
-- Resource discovery and application submission
SELECT 
  r.type as resource_type,
  COUNT(DISTINCT ra.user_id) as unique_applicants,
  COUNT(ra.id) as total_applications,
  COUNT(CASE WHEN ra.status = 'pending' THEN 1 END) as pending,
  COUNT(CASE WHEN ra.status = 'approved' THEN 1 END) as approved,
  COUNT(CASE WHEN ra.status = 'rejected' THEN 1 END) as rejected
FROM resource_applications ra
LEFT JOIN resources r ON true -- Join logic may vary
GROUP BY r.type;

-- Patient-specific resource tracking
SELECT 
  user_id,
  COUNT(*) as applications_submitted,
  COUNT(CASE WHEN status = 'approved' THEN 1 END) as resources_obtained
FROM resource_applications
GROUP BY user_id;
```

#### 2. Most Popular Resource Types
```sql
-- Resource suggestions by type
SELECT 
  type,
  COUNT(*) as suggestions_count,
  COUNT(CASE WHEN status = 'approved' THEN 1 END) as approved_count
FROM resource_suggestions
GROUP BY type
ORDER BY suggestions_count DESC;
```

#### 3. Medical Supply & Equipment Tracking
```sql
-- Equipment needs documented
SELECT 
  user_id,
  jsonb_array_length(equipment) as equipment_items_tracked,
  jsonb_array_length(supplies) as supply_items_tracked
FROM recovery_blueprints
WHERE jsonb_array_length(equipment) > 0 OR jsonb_array_length(supplies) > 0;
```

---

## 📅 Outcome 8: Follow-up Adherence
**Testing Method:** Pilot data analysis

### Key Metrics to Track

#### 1. Scheduled Follow-ups Logged
```sql
-- Journey tasks with due dates (follow-up appointments)
SELECT 
  user_id,
  COUNT(*) as scheduled_followups,
  SUM(CASE WHEN completed THEN 1 ELSE 0 END) as completed_followups,
  ROUND(SUM(CASE WHEN completed THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100, 2) as adherence_rate
FROM journey_tasks
WHERE due_date IS NOT NULL
  AND description ILIKE '%appointment%' OR description ILIKE '%follow%'
GROUP BY user_id;
```

#### 2. Medication Adherence
```sql
-- Medication logs from tracker
WITH medication_schedule AS (
  SELECT 
    user_id,
    date,
    medications,
    custom_fields->'medicationLogs' as medication_logs
  FROM tracker_entries
  WHERE medications IS NOT NULL 
    AND array_length(medications, 1) > 0
)
SELECT 
  user_id,
  COUNT(*) as days_with_meds_scheduled,
  COUNT(CASE WHEN medication_logs IS NOT NULL THEN 1 END) as days_logged,
  ROUND(
    COUNT(CASE WHEN medication_logs IS NOT NULL THEN 1 END)::NUMERIC / COUNT(*) * 100, 2
  ) as medication_logging_adherence
FROM medication_schedule
GROUP BY user_id;
```

#### 3. Daily Routine Completion
```sql
-- Recovery blueprint routines vs tracker entries
WITH routine_days AS (
  SELECT 
    rb.user_id,
    jsonb_array_length(rb.daily_routines) as routines_defined,
    COUNT(DISTINCT DATE(te.date)) as days_logged
  FROM recovery_blueprints rb
  LEFT JOIN tracker_entries te ON rb.user_id = te.user_id
  WHERE rb.created_at >= NOW() - INTERVAL '30 days'
  GROUP BY rb.user_id, rb.daily_routines
)
SELECT 
  user_id,
  routines_defined,
  days_logged,
  CASE 
    WHEN days_logged >= 21 THEN 'High adherence (21+ days)'
    WHEN days_logged >= 14 THEN 'Moderate adherence (14-20 days)'
    ELSE 'Low adherence (<14 days)'
  END as adherence_level
FROM routine_days;
```

---

## 🏥 Outcome 9: Unplanned Utilization
**Testing Method:** Hospital data (if available) + patient self-report

### Key Metrics to Track

#### 1. Self-Reported ER Visits / Readmissions
```sql
-- Create table for patient-reported utilization
CREATE TABLE IF NOT EXISTS pilot_healthcare_utilization (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  event_type TEXT NOT NULL, -- 'er_visit', 'hospital_readmission', 'urgent_care', 'unscheduled_appointment'
  event_date DATE NOT NULL,
  reason TEXT,
  preventable BOOLEAN, -- Patient/clinician assessment
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Query unplanned utilization events
SELECT 
  user_id,
  COUNT(*) as total_unplanned_events,
  COUNT(CASE WHEN event_type = 'er_visit' THEN 1 END) as er_visits,
  COUNT(CASE WHEN event_type = 'hospital_readmission' THEN 1 END) as readmissions,
  COUNT(CASE WHEN preventable THEN 1 END) as potentially_preventable_events
FROM pilot_healthcare_utilization
GROUP BY user_id;

-- Compare app users vs non-users (requires control group data)
SELECT 
  CASE WHEN u.id IS NOT NULL THEN 'App User' ELSE 'Control' END as group_type,
  AVG(event_count) as avg_unplanned_events,
  AVG(er_count) as avg_er_visits
FROM pilot_healthcare_utilization hu
LEFT JOIN users u ON hu.user_id = u.id
GROUP BY group_type;
```

---

## 🎯 Outcome 10: Overall Adoption Potential
**Testing Method:** Patient + staff continuation intent surveys

### Key Metrics to Track

#### 1. Net Promoter Score (NPS)
```sql
-- Create NPS survey table
CREATE TABLE IF NOT EXISTS pilot_nps_survey (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  user_role TEXT NOT NULL, -- 'patient', 'family_member', 'clinician'
  nps_score INTEGER NOT NULL CHECK (nps_score >= 0 AND nps_score <= 10),
  feedback_text TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Calculate NPS
WITH nps_categories AS (
  SELECT 
    user_role,
    nps_score,
    CASE 
      WHEN nps_score >= 9 THEN 'Promoter'
      WHEN nps_score >= 7 THEN 'Passive'
      ELSE 'Detractor'
    END as category
  FROM pilot_nps_survey
)
SELECT 
  user_role,
  COUNT(*) as total_responses,
  COUNT(CASE WHEN category = 'Promoter' THEN 1 END) as promoters,
  COUNT(CASE WHEN category = 'Detractor' THEN 1 END) as detractors,
  ROUND(
    (
      COUNT(CASE WHEN category = 'Promoter' THEN 1 END)::NUMERIC / COUNT(*) * 100 -
      COUNT(CASE WHEN category = 'Detractor' THEN 1 END)::NUMERIC / COUNT(*) * 100
    ), 2
  ) as nps_score
FROM nps_categories
GROUP BY user_role;
```

#### 2. Continuation Intent Survey
```sql
-- Create continuation intent survey
CREATE TABLE IF NOT EXISTS pilot_continuation_survey (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  user_role TEXT NOT NULL,
  would_continue_using BOOLEAN NOT NULL,
  would_recommend BOOLEAN NOT NULL,
  perceived_value INTEGER CHECK (perceived_value >= 1 AND perceived_value <= 5), -- Likert 1-5
  reason_text TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Query continuation intent
SELECT 
  user_role,
  COUNT(*) as total_responses,
  SUM(CASE WHEN would_continue_using THEN 1 ELSE 0 END) as would_continue,
  ROUND(SUM(CASE WHEN would_continue_using THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100, 2) as continuation_rate,
  SUM(CASE WHEN would_recommend THEN 1 ELSE 0 END) as would_recommend_count,
  ROUND(SUM(CASE WHEN would_recommend THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100, 2) as recommendation_rate,
  AVG(perceived_value) as avg_perceived_value
FROM pilot_continuation_survey
GROUP BY user_role;
```

---

## 🔧 Implementation Checklist

### Tables to Create (Run these migrations first)
- [ ] `pilot_survey_responses` - Pre/post preparedness & family confidence surveys
- [ ] `pilot_usability_errors` - Error tracking for usability testing
- [ ] `pilot_family_activity_log` - Family feature usage tracking
- [ ] `pilot_clinician_feedback` - Clinician usefulness assessments
- [ ] `pilot_workflow_time_tracking` - Time burden measurements
- [ ] `pilot_healthcare_utilization` - Unplanned ER/readmission tracking
- [ ] `pilot_nps_survey` - Net Promoter Score
- [ ] `pilot_continuation_survey` - Continuation intent

### Data Collection Process
1. **Baseline (Week 0)**: 
   - Collect pre-surveys (preparedness, family confidence)
   - Document control group baseline (if applicable)
   
2. **During Pilot (Weeks 1-8)**:
   - Automated analytics collection (tracker, goals, journeys)
   - Manual error logging during usability sessions
   - Time tracking for workflow burden
   - Clinician feedback collection (weekly or bi-weekly)
   - Family activity monitoring
   
3. **End of Pilot (Week 8)**:
   - Post-surveys (preparedness, family confidence)
   - NPS and continuation intent surveys
   - Hospital utilization data analysis
   - Final clinician assessments

### Export Commands for Analysis
```bash
# Export all pilot data for statistical analysis
psql -d your_database -c "COPY (
  SELECT * FROM pilot_survey_responses
) TO STDOUT WITH CSV HEADER" > pilot_survey_responses.csv

psql -d your_database -c "COPY (
  SELECT * FROM tracker_entries WHERE created_at >= 'PILOT_START_DATE'
) TO STDOUT WITH CSV HEADER" > pilot_tracker_data.csv

# Repeat for each pilot table and core analytics query
```

---

## 📊 Summary Dashboard Query
```sql
-- High-level pilot metrics summary
SELECT 
  'Patient Engagement' as metric_category,
  COUNT(DISTINCT user_id) as active_users,
  AVG(entries_per_user) as avg_engagement_score
FROM (
  SELECT user_id, COUNT(*) as entries_per_user
  FROM tracker_entries
  WHERE created_at >= 'PILOT_START_DATE'
  GROUP BY user_id
) subquery

UNION ALL

SELECT 
  'Recovery Preparedness',
  COUNT(DISTINCT user_id),
  AVG(blueprint_completion_percentage)
FROM recovery_blueprints

UNION ALL

SELECT 
  'Family Confidence',
  COUNT(DISTINCT family_member_id),
  COUNT(*)::NUMERIC / NULLIF(COUNT(DISTINCT patient_id), 0)
FROM family_patient_links

UNION ALL

SELECT 
  'Resource Utilization',
  COUNT(DISTINCT user_id),
  COUNT(*)
FROM resource_applications

-- Continue for each outcome category...
;
```

---

## 📝 Notes
- Replace `'PILOT_START_DATE'` with your actual pilot start date (e.g., `'2026-09-01'`)
- Customize Likert scale ranges and question IDs to match your survey instruments
- Ensure HIPAA compliance when exporting identifiable data
- Use de-identified user IDs for reporting to external stakeholders
- Consider creating database views for frequently-run analytics queries

