-- Re-enable agent self-assignment of follow-up tasks.
-- This was previously dropped in 20260421_followup_external_doctor_fields.sql
-- but is now needed so agents can create self-reminders to re-visit external
-- doctors (assigned_to = created_by = the agent themselves).

CREATE POLICY "Agents can create self-assigned followups"
ON public.followup_tasks
FOR INSERT
WITH CHECK (
  assigned_to = auth.uid()
  AND created_by = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.doctors
    WHERE id = auth.uid()
      AND role = 'assistant'
      AND approval_status = 'approved'
  )
);
