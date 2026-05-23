-- 20260523120000_rbac_fixes.sql
--
-- Closes RBAC gaps surfaced by the 2026-05-23 audit:
--
--   C4: followup_tasks has no DELETE policy that covers head_doctor.
--       The legacy "Doctors can update/delete followups" policy only
--       matched role='doctor' and used FOR ALL, leaving head_doctor
--       unable to delete and assistants able to delete via the FOR ALL
--       scope being broader than intended. Replace with a dedicated
--       followup_delete_rbac that mirrors the select/update pattern.
--
--   C5: patients_delete_rbac currently allows any doctor or the
--       creator. The app-level PatientPermissions.canDeletePatient()
--       restricts deletion to head_doctor only. Tighten the policy
--       so the database matches the documented role matrix.
--
--   C6: (not addressed here) dr_visits_delete_rbac already includes
--       the created_by_id branch -- verified by reading
--       20260518_dr_visits_delete_policy.sql line 10 and
--       20260518_optimize_rls_auth_uid_initplan.sql lines 13-18.
--       The audit finding was a false positive.
--
--   C7: doctors.approval_status / approved_by / approved_at /
--       rejection_reason had no column-level guard. The existing
--       doctors_update_own_or_admin policy lets any user update
--       their own row, which means a user could flip themselves to
--       'approved'. Postgres has no column-level RLS, so this is
--       enforced via a BEFORE UPDATE trigger that allows the
--       approval columns to change only when the caller's role
--       (per public.get_my_role()) is 'head_doctor'.

----------------------------------------------------------------------
-- C4: followup_tasks DELETE policy
----------------------------------------------------------------------

DROP POLICY IF EXISTS "Doctors can update/delete followups"
  ON public.followup_tasks;

DROP POLICY IF EXISTS "followup_delete_rbac"
  ON public.followup_tasks;

CREATE POLICY "followup_delete_rbac" ON public.followup_tasks
FOR DELETE
TO authenticated
USING (
  public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text])
  OR assigned_to = (select auth.uid())
);

----------------------------------------------------------------------
-- C5: tighten patients_delete_rbac to head_doctor only
----------------------------------------------------------------------

DROP POLICY IF EXISTS "patients_delete_rbac" ON public.patients;

CREATE POLICY "patients_delete_rbac" ON public.patients
FOR DELETE
TO authenticated
USING (
  public.get_my_role() = 'head_doctor'::text
);

----------------------------------------------------------------------
-- C7: approval column guard via trigger
----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.guard_doctors_approval_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  approval_changed boolean;
BEGIN
  approval_changed :=
       NEW.approval_status IS DISTINCT FROM OLD.approval_status
    OR NEW.approved_by      IS DISTINCT FROM OLD.approved_by
    OR NEW.approved_at      IS DISTINCT FROM OLD.approved_at
    OR NEW.rejection_reason IS DISTINCT FROM OLD.rejection_reason;

  IF approval_changed
     AND public.get_my_role() IS DISTINCT FROM 'head_doctor' THEN
    RAISE EXCEPTION
      'approval columns can only be modified by the head doctor'
      USING ERRCODE = '42501'; -- insufficient_privilege
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS doctors_guard_approval_columns ON public.doctors;

CREATE TRIGGER doctors_guard_approval_columns
BEFORE UPDATE ON public.doctors
FOR EACH ROW
EXECUTE FUNCTION public.guard_doctors_approval_columns();
