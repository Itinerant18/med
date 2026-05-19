-- ============================================================
-- Migration: Add area_district to agent_outside_visits
--            Add ext_doc_followup_reminder_days to doctors
-- Run this in the Supabase SQL Editor
-- ============================================================

-- 1. Add area/district column to external doctor visits table
ALTER TABLE agent_outside_visits
ADD COLUMN IF NOT EXISTS area_district TEXT;

-- 2. Add follow-up reminder days preference to doctors (agent profiles) table
ALTER TABLE doctors
ADD COLUMN IF NOT EXISTS ext_doc_followup_reminder_days INTEGER DEFAULT 7;

-- Optional: add a comment for documentation
COMMENT ON COLUMN agent_outside_visits.area_district
  IS 'District in West Bengal where the external doctor is located';
COMMENT ON COLUMN doctors.ext_doc_followup_reminder_days
  IS 'Number of days after an external visit to trigger a follow-up reminder for the agent';
