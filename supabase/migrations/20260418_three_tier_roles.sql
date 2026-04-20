-- 1. Update the role constraint on doctors table
ALTER TABLE public.doctors
  DROP CONSTRAINT IF EXISTS doctors_role_check;

ALTER TABLE public.doctors
  ADD CONSTRAINT doctors_role_check
  CHECK (role IN ('head_doctor', 'doctor', 'assistant'));

-- 2. Promote the first existing doctor to head_doctor
-- (Run this manually once, or set head_doctor on your own account via Supabase dashboard)
-- UPDATE public.doctors SET role = 'head_doctor' WHERE email = 'your@email.com';

-- 3. Update the get_my_role() helper — no changes needed, already returns role string

-- 4. Drop and recreate RLS policies that reference role checks

-- DOCTORS table: head_doctor can update any row (for approval)
DROP POLICY IF EXISTS "doctors_update_own" ON public.doctors;

CREATE POLICY "doctors_update_own_or_admin"
ON public.doctors FOR UPDATE
TO authenticated
USING (
  id = auth.uid()
  OR public.get_my_role() = 'head_doctor'
)
WITH CHECK (
  id = auth.uid()
  OR public.get_my_role() = 'head_doctor'
);

-- PATIENTS: head_doctor and doctor see all; assistant sees only their own
DROP POLICY IF EXISTS "patients_select_rbac" ON public.patients;
CREATE POLICY "patients_select_rbac"
ON public.patients FOR SELECT
TO authenticated
USING (
  public.get_my_role() IN ('head_doctor', 'doctor')
  OR created_by_id = auth.uid()
);

DROP POLICY IF EXISTS "patients_update_rbac" ON public.patients;
CREATE POLICY "patients_update_rbac"
ON public.patients FOR UPDATE
TO authenticated
USING (
  public.get_my_role() IN ('head_doctor', 'doctor')
  OR created_by_id = auth.uid()
)
WITH CHECK (
  public.get_my_role() IN ('head_doctor', 'doctor')
  OR created_by_id = auth.uid()
);

DROP POLICY IF EXISTS "patients_delete_rbac" ON public.patients;
CREATE POLICY "patients_delete_rbac"
ON public.patients FOR DELETE
TO authenticated
USING (
  public.get_my_role() IN ('head_doctor', 'doctor')
  OR created_by_id = auth.uid()
);

-- VISITS: same as patients
DROP POLICY IF EXISTS "visits_select_rbac" ON public.visits;
CREATE POLICY "visits_select_rbac"
ON public.visits FOR SELECT
TO authenticated
USING (
  public.get_my_role() IN ('head_doctor', 'doctor')
  OR created_by_id = auth.uid()
);

DROP POLICY IF EXISTS "visits_update_rbac" ON public.visits;
CREATE POLICY "visits_update_rbac"
ON public.visits FOR UPDATE
TO authenticated
USING (
  public.get_my_role() IN ('head_doctor', 'doctor')
  OR created_by_id = auth.uid()
)
WITH CHECK (
  public.get_my_role() IN ('head_doctor', 'doctor')
  OR created_by_id = auth.uid()
);

DROP POLICY IF EXISTS "visits_delete_doctors_only" ON public.visits;
CREATE POLICY "visits_delete_doctors_only"
ON public.visits FOR DELETE
TO authenticated
USING (public.get_my_role() IN ('head_doctor', 'doctor'));

-- DR_VISITS: doctors and head_doctor create; agents see only assigned
DROP POLICY IF EXISTS "Doctors can see all visits" ON public.dr_visits;
CREATE POLICY "dr_visits_select_rbac" ON public.dr_visits
FOR SELECT USING (
  public.get_my_role() IN ('head_doctor', 'doctor')
  OR assigned_agent_id = auth.uid()
);

DROP POLICY IF EXISTS "Doctors can create visits" ON public.dr_visits;
CREATE POLICY "dr_visits_insert_rbac" ON public.dr_visits
FOR INSERT WITH CHECK (
  public.get_my_role() IN ('head_doctor', 'doctor')
);

DROP POLICY IF EXISTS "Doctors can update visits" ON public.dr_visits;
DROP POLICY IF EXISTS "Agents can update assigned visits" ON public.dr_visits;
CREATE POLICY "dr_visits_update_rbac" ON public.dr_visits
FOR UPDATE USING (
  public.get_my_role() IN ('head_doctor', 'doctor')
  OR assigned_agent_id = auth.uid()
);

-- FOLLOWUP_TASKS: same pattern
DROP POLICY IF EXISTS "Doctors can see all followups" ON public.followup_tasks;
CREATE POLICY "followup_select_rbac" ON public.followup_tasks
FOR SELECT USING (
  public.get_my_role() IN ('head_doctor', 'doctor')
  OR assigned_to = auth.uid()
);

DROP POLICY IF EXISTS "Doctors can create followups" ON public.followup_tasks;
CREATE POLICY "followup_insert_rbac" ON public.followup_tasks
FOR INSERT WITH CHECK (
  public.get_my_role() IN ('head_doctor', 'doctor')
);

DROP POLICY IF EXISTS "Agents can update assigned followups" ON public.followup_tasks;
CREATE POLICY "followup_update_rbac" ON public.followup_tasks
FOR UPDATE USING (
  public.get_my_role() IN ('head_doctor', 'doctor')
  OR assigned_to = auth.uid()
);
