-- Allow approved assistants to create follow-up tasks assigned to themselves.
-- This unblocks the "My Follow-ups -> Add Follow-up" flow for agents.

CREATE POLICY "Agents can create own followups"
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
