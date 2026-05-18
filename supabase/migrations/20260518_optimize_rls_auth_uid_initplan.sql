-- Reduce auth.uid() initplan overhead in row-level policies by using the
-- stable subquery form (select auth.uid()) while preserving the same access
-- rules. This keeps the policy behavior unchanged and makes repeated checks
-- cheaper for high-frequency queries.

ALTER POLICY "doctors_insert_own" ON public.doctors
WITH CHECK (id = (select auth.uid()));

ALTER POLICY "doctors_update_own_or_admin" ON public.doctors
USING ((id = (select auth.uid())) OR (public.get_my_role() = 'head_doctor'::text))
WITH CHECK ((id = (select auth.uid())) OR (public.get_my_role() = 'head_doctor'::text));

ALTER POLICY "dr_visits_delete_rbac" ON public.dr_visits
USING (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (assigned_agent_id = (select auth.uid()))
  OR (created_by_id = (select auth.uid()))
);

ALTER POLICY "Agents can see assigned visits" ON public.dr_visits
USING (assigned_agent_id = (select auth.uid()));

ALTER POLICY "dr_visits_select_rbac" ON public.dr_visits
USING (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (assigned_agent_id = (select auth.uid()))
);

ALTER POLICY "dr_visits_update_rbac" ON public.dr_visits
USING (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (assigned_agent_id = (select auth.uid()))
)
WITH CHECK (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (assigned_agent_id = (select auth.uid()))
);

ALTER POLICY "Doctors can update/delete followups" ON public.followup_tasks
USING (
  EXISTS (
    SELECT 1
    FROM public.doctors
    WHERE doctors.id = (select auth.uid())
      AND doctors.role = 'doctor'::text
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.doctors
    WHERE doctors.id = (select auth.uid())
      AND doctors.role = 'doctor'::text
  )
);

ALTER POLICY "Agents can see assigned followups" ON public.followup_tasks
USING (assigned_to = (select auth.uid()));

ALTER POLICY "followup_select_rbac" ON public.followup_tasks
USING (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (assigned_to = (select auth.uid()))
);

ALTER POLICY "followup_update_rbac" ON public.followup_tasks
USING (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (assigned_to = (select auth.uid()))
)
WITH CHECK (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (assigned_to = (select auth.uid()))
);

ALTER POLICY "patients_delete_rbac" ON public.patients
USING (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (created_by_id = (select auth.uid()))
);

ALTER POLICY "patients_insert_authenticated" ON public.patients
WITH CHECK (created_by_id = (select auth.uid()));

ALTER POLICY "patients_select_rbac" ON public.patients
USING (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (created_by_id = (select auth.uid()))
);

ALTER POLICY "patients_update_rbac" ON public.patients
USING (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (created_by_id = (select auth.uid()))
)
WITH CHECK (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (created_by_id = (select auth.uid()))
);

ALTER POLICY "visits_insert_authenticated" ON public.visits
WITH CHECK (created_by_id = (select auth.uid()));

ALTER POLICY "visits_select_rbac" ON public.visits
USING (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (created_by_id = (select auth.uid()))
);

ALTER POLICY "visits_update_rbac" ON public.visits
USING (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (created_by_id = (select auth.uid()))
)
WITH CHECK (
  (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
  OR (created_by_id = (select auth.uid()))
);

ALTER POLICY "agent_outside_visits_insert_own" ON public.agent_outside_visits
WITH CHECK (agent_id = (select auth.uid()));

ALTER POLICY "agent_outside_visits_select_rbac" ON public.agent_outside_visits
USING (
  (agent_id = (select auth.uid()))
  OR (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
);

ALTER POLICY "agent_outside_visits_update_rbac" ON public.agent_outside_visits
USING (
  (agent_id = (select auth.uid()))
  OR (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
)
WITH CHECK (
  (agent_id = (select auth.uid()))
  OR (public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text]))
);

ALTER POLICY "patient_documents_select_own" ON public.patient_documents
USING (
  EXISTS (
    SELECT 1
    FROM public.patients
    WHERE patients.id = patient_documents.patient_id
      AND patients.created_by_id = (select auth.uid())
  )
);

ALTER POLICY "patient_documents_insert_own" ON public.patient_documents
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.patients
    WHERE patients.id = patient_documents.patient_id
      AND patients.created_by_id = (select auth.uid())
  )
);

ALTER POLICY "patient_documents_delete_own" ON public.patient_documents
USING (
  EXISTS (
    SELECT 1
    FROM public.patients
    WHERE patients.id = patient_documents.patient_id
      AND patients.created_by_id = (select auth.uid())
  )
);

ALTER POLICY "user_preferences_insert_own" ON public.user_preferences
WITH CHECK (user_id = (select auth.uid()));

ALTER POLICY "user_preferences_select_own" ON public.user_preferences
USING (user_id = (select auth.uid()));

ALTER POLICY "user_preferences_update_own" ON public.user_preferences
USING (user_id = (select auth.uid()))
WITH CHECK (user_id = (select auth.uid()));
