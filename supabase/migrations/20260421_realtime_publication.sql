-- Ensure follow-up, dr_visit, and agent_outside_visit changes are emitted on
-- the supabase_realtime publication so clients can react in real time.
DO $$
DECLARE
  v_table TEXT;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'followup_tasks',
    'dr_visits',
    'agent_outside_visits'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = v_table
    ) THEN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        v_table
      );
    END IF;
  END LOOP;
END $$;

-- Emit full old row on UPDATE/DELETE so realtime payloads contain prior values.
ALTER TABLE public.followup_tasks REPLICA IDENTITY FULL;
ALTER TABLE public.dr_visits REPLICA IDENTITY FULL;
ALTER TABLE public.agent_outside_visits REPLICA IDENTITY FULL;
