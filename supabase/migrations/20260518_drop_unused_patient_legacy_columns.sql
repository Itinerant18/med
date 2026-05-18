-- Conservative schema cleanup for patients.
-- These legacy fields are not referenced by the current app screens, providers,
-- or Supabase functions. Keeping the core clinical fields intact.

ALTER TABLE public.patients
  DROP COLUMN IF EXISTS occupation,
  DROP COLUMN IF EXISTS national_id,
  DROP COLUMN IF EXISTS alternate_phone,
  DROP COLUMN IF EXISTS city,
  DROP COLUMN IF EXISTS state,
  DROP COLUMN IF EXISTS pin_code,
  DROP COLUMN IF EXISTS emergency_contact_name,
  DROP COLUMN IF EXISTS emergency_relationship,
  DROP COLUMN IF EXISTS health_scheme_other,
  DROP COLUMN IF EXISTS policy_number,
  DROP COLUMN IF EXISTS last_visit_at,
  DROP COLUMN IF EXISTS last_visit_date,
  DROP COLUMN IF EXISTS last_visit_type;
