-- Allow scoped deletes on dr_visits so visit detail delete actions work.
-- Mirrors the existing select/update RBAC scope for doctors, head doctors,
-- and the record owner / assigned assistant.

DROP POLICY IF EXISTS "dr_visits_delete_rbac" ON public.dr_visits;
CREATE POLICY "dr_visits_delete_rbac" ON public.dr_visits
FOR DELETE USING (
  public.get_my_role() IN ('head_doctor', 'doctor')
  OR assigned_agent_id = auth.uid()
  OR created_by_id = auth.uid()
);
