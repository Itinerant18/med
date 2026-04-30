ALTER TABLE patients
  ADD COLUMN IF NOT EXISTS investigation_place TEXT,
  ADD COLUMN IF NOT EXISTS referred_by TEXT,
  ADD COLUMN IF NOT EXISTS investigation_status JSONB DEFAULT '{}'::jsonb;

ALTER TABLE agent_outside_visits
  ADD COLUMN IF NOT EXISTS meet_dr_name TEXT,
  ADD COLUMN IF NOT EXISTS meet_place TEXT,
  ADD COLUMN IF NOT EXISTS meet_dr_type TEXT,
  ADD COLUMN IF NOT EXISTS meet_times_visited INTEGER;
