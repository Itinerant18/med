CREATE TABLE IF NOT EXISTS work_log (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type   TEXT NOT NULL CHECK (entity_type IN ('followup_task', 'agent_outside_visit', 'dr_visit')),
  entity_id     UUID NOT NULL,
  author_id     UUID NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
  author_name   TEXT NOT NULL,
  author_role   TEXT NOT NULL,
  body          TEXT NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS work_log_entity_idx ON work_log (entity_type, entity_id, created_at DESC);

-- RLS: anyone authenticated can read logs for entities they can access.
-- For simplicity, allow any authenticated doctor to read/insert.
-- Deletion only by the author or a head_doctor.
ALTER TABLE work_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "work_log_read" ON work_log
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "work_log_insert" ON work_log
  FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "work_log_delete_own" ON work_log
  FOR DELETE USING (auth.uid() = author_id);

CREATE POLICY "work_log_delete_head_doctor" ON work_log
  FOR DELETE USING (public.get_my_role() = 'head_doctor');
