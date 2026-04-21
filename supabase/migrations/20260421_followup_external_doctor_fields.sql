-- Assistant follow-up reporting fields (external doctor visit details)
ALTER TABLE public.followup_tasks
  ADD COLUMN IF NOT EXISTS is_external_doctor BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS ext_doctor_name TEXT,
  ADD COLUMN IF NOT EXISTS ext_doctor_specialization TEXT,
  ADD COLUMN IF NOT EXISTS ext_doctor_hospital TEXT,
  ADD COLUMN IF NOT EXISTS ext_doctor_phone TEXT,
  ADD COLUMN IF NOT EXISTS completion_notes TEXT;

-- Workflow guard: follow-up tasks are assigned by doctors/head doctor.
DROP POLICY IF EXISTS "Agents can create own followups" ON public.followup_tasks;
