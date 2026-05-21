-- Add external_doctors to the supabase_realtime publication so that
-- INSERT/UPDATE events are broadcast to clients watching the directory.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'external_doctors'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.external_doctors;
  END IF;
END $$;

ALTER TABLE public.external_doctors REPLICA IDENTITY FULL;
