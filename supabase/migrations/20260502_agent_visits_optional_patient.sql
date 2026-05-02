-- Migration: Make patient_id optional in agent_outside_visits
-- Reason: Agents may visit external doctors solely for information collection,
--         without accompanying a specific patient. When a patient IS referred
--         by the external doctor, the patient_id is populated from the followup task.

ALTER TABLE public.agent_outside_visits
  ALTER COLUMN patient_id DROP NOT NULL;
