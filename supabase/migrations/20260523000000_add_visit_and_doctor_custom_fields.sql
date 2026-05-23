-- Migration: Add custom visit and doctor fields for oncology references, districts, types, and metrics.
-- Tables modified: visits, external_doctors, agent_outside_visits

-- 1. Add post_op_referred_to to visits table
ALTER TABLE public.visits 
  ADD COLUMN IF NOT EXISTS post_op_referred_to TEXT;

-- 2. Add area_district and meet_dr_type to external_doctors table
ALTER TABLE public.external_doctors 
  ADD COLUMN IF NOT EXISTS area_district TEXT,
  ADD COLUMN IF NOT EXISTS meet_dr_type TEXT;

-- 3. Add no_of_patients_received, work_pending, and meet_dr_type to agent_outside_visits table
ALTER TABLE public.agent_outside_visits 
  ADD COLUMN IF NOT EXISTS no_of_patients_received INTEGER,
  ADD COLUMN IF NOT EXISTS work_pending TEXT,
  ADD COLUMN IF NOT EXISTS meet_dr_type TEXT;

-- 4. Recreate known_external_doctors view to include meet_dr_type and area_district
CREATE OR REPLACE VIEW public.known_external_doctors AS
SELECT DISTINCT ON (ext_doctor_name, ext_doctor_hospital)
    ext_doctor_name,
    ext_doctor_specialization,
    ext_doctor_hospital,
    ext_doctor_phone,
    area_district,
    meet_dr_type,
    COUNT(*) OVER (
        PARTITION BY ext_doctor_name, ext_doctor_hospital
    ) AS visit_count,
    MAX(visit_date) OVER (
        PARTITION BY ext_doctor_name, ext_doctor_hospital
    ) AS last_visit_date
FROM public.agent_outside_visits
WHERE ext_doctor_name IS NOT NULL
  AND ext_doctor_name <> ''
ORDER BY ext_doctor_name, ext_doctor_hospital, visit_date DESC;

-- Grant select permission on the updated view
GRANT SELECT ON public.known_external_doctors TO authenticated;
