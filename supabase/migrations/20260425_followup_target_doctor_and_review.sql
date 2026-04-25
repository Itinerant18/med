-- 20260425_followup_target_doctor_and_review.sql
--
-- Phase 1 of the follow-up redesign:
--
--  • Doctor-side fields: doctor specifies the *target* external doctor /
--    hospital and gives the assistant on-the-ground instructions when
--    creating the follow-up task.
--
--  • Assistant scheduling: scheduled_visit_date lets the assistant track
--    when they actually plan to take the patient (separate from due_date,
--    which is the deadline by which the loop must close).
--
--  • Doctor review loop: after an assistant completes the task and records
--    the agent_outside_visit, the assigning doctor reviews and acknowledges
--    the outcome before the workflow is considered closed.
--
--  • Status checks: introduce 'in_progress' and 'cancelled' so the lifecycle
--    matches the new flow.
--
--  • Assistant performance KPI: surface outside_visits_total so the head
--    doctor's performance dashboard reflects external-visit work.

-- ── 1. Add target / scheduling / review columns to followup_tasks ─────────
ALTER TABLE public.followup_tasks
  ADD COLUMN IF NOT EXISTS target_ext_doctor_name           TEXT,
  ADD COLUMN IF NOT EXISTS target_ext_doctor_hospital       TEXT,
  ADD COLUMN IF NOT EXISTS target_ext_doctor_specialization TEXT,
  ADD COLUMN IF NOT EXISTS target_ext_doctor_phone          TEXT,
  ADD COLUMN IF NOT EXISTS visit_instructions               TEXT,
  ADD COLUMN IF NOT EXISTS scheduled_visit_date             DATE,
  ADD COLUMN IF NOT EXISTS reviewed_by                      UUID REFERENCES public.doctors(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at                      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS doctor_review_notes              TEXT;

-- ── 2. Replace the status CHECK constraint to include 'in_progress' / 'cancelled'.
DO $$
DECLARE
  cons_name text;
BEGIN
  -- Drop any existing check constraint on followup_tasks.status.
  FOR cons_name IN
    SELECT con.conname
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    WHERE nsp.nspname = 'public'
      AND rel.relname = 'followup_tasks'
      AND con.contype = 'c'
      AND pg_get_constraintdef(con.oid) ILIKE '%status%IN%'
  LOOP
    EXECUTE format(
      'ALTER TABLE public.followup_tasks DROP CONSTRAINT IF EXISTS %I',
      cons_name
    );
  END LOOP;
END $$;

ALTER TABLE public.followup_tasks
  ADD CONSTRAINT followup_tasks_status_check
  CHECK (status IN ('pending', 'in_progress', 'completed', 'overdue', 'cancelled'));

-- ── 3. Useful index for "needs review" queries.
CREATE INDEX IF NOT EXISTS followup_tasks_needs_review_idx
  ON public.followup_tasks (created_by, status)
  WHERE status = 'completed' AND reviewed_at IS NULL;

-- ── 4. Re-create assistant_performance with outside_visits_total.
DROP VIEW IF EXISTS public.assistant_performance;

CREATE VIEW public.assistant_performance AS
SELECT
  d.id                                                                  AS assistant_id,
  d.full_name,
  d.specialization,
  COUNT(DISTINCT p.id)                                                  AS patients_registered,
  COUNT(DISTINCT v.id)                                                  AS visits_created,
  COUNT(DISTINCT ft.id)                                                 AS followups_total,
  COUNT(DISTINCT ft.id) FILTER (WHERE ft.status = 'completed')          AS followups_completed,
  COUNT(DISTINCT ft.id) FILTER (WHERE ft.status = 'overdue')            AS followups_overdue,
  COUNT(DISTINCT aov.id)                                                AS outside_visits_total
FROM public.doctors d
LEFT JOIN public.patients               p   ON p.created_by_id = d.id
LEFT JOIN public.visits                 v   ON v.created_by_id = d.id
LEFT JOIN public.followup_tasks         ft  ON ft.assigned_to  = d.id
LEFT JOIN public.agent_outside_visits   aov ON aov.agent_id    = d.id
WHERE d.role = 'assistant'
  AND d.approval_status = 'approved'
GROUP BY d.id, d.full_name, d.specialization;

-- Mirror the original grants — only authenticated users with the right RLS
-- on doctors / followup_tasks / etc. will see anything anyway.
GRANT SELECT ON public.assistant_performance TO authenticated;
