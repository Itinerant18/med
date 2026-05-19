-- Creates a view that returns one row per distinct external doctor (by name +
-- hospital), with the most-recent visit date and total visit count.  Used by
-- the doctor-side "pick from history" when assigning a new external-doctor task.
CREATE OR REPLACE VIEW public.known_external_doctors AS
SELECT DISTINCT ON (ext_doctor_name, ext_doctor_hospital)
    ext_doctor_name,
    ext_doctor_specialization,
    ext_doctor_hospital,
    ext_doctor_phone,
    area_district,
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

-- Grant read access to authenticated users so doctors can query history.
GRANT SELECT ON public.known_external_doctors TO authenticated;
