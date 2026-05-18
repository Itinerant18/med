-- Allow agents to delete their own external doctor visit rows from the agent
-- profile screen. Keep the scope tight: only the owning agent or privileged
-- staff can remove the row.

DROP POLICY IF EXISTS "agent_outside_visits_delete_rbac" ON public.agent_outside_visits;
CREATE POLICY "agent_outside_visits_delete_rbac" ON public.agent_outside_visits
FOR DELETE USING (
  agent_id = (select auth.uid())
  OR public.get_my_role() = ANY (ARRAY['head_doctor'::text, 'doctor'::text])
);
