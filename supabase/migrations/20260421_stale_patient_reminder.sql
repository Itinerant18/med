-- Stale patient reminder setup
-- Requires pg_cron + pg_net extensions to be enabled in Supabase.

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

ALTER TABLE public.patients
  ADD COLUMN IF NOT EXISTS reminder_sent BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS public.patient_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
  doctor_id UUID NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
  old_status TEXT,
  service_status TEXT,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.reset_reminder_flag()
RETURNS trigger AS $$
BEGIN
  IF ROW(NEW.service_status, NEW.last_updated_at, NEW.last_updated_by)
     IS DISTINCT FROM
     ROW(OLD.service_status, OLD.last_updated_at, OLD.last_updated_by) THEN
    NEW.reminder_sent := FALSE;
    NEW.reminder_sent_at := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS reset_reminder ON public.patients;
CREATE TRIGGER reset_reminder
BEFORE UPDATE ON public.patients
FOR EACH ROW EXECUTE FUNCTION public.reset_reminder_flag();

DO $$
DECLARE
  v_url TEXT;
  v_service_key TEXT;
  v_command TEXT;
  v_job RECORD;
BEGIN
  SELECT decrypted_secret
  INTO v_url
  FROM vault.decrypted_secrets
  WHERE name = 'supabase_url'
  LIMIT 1;

  SELECT decrypted_secret
  INTO v_service_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  IF v_url IS NULL OR v_service_key IS NULL THEN
    RAISE NOTICE 'Skipping cron schedule: set vault secrets `supabase_url` and `service_role_key` first.';
    RETURN;
  END IF;

  FOR v_job IN
    SELECT jobid FROM cron.job WHERE jobname = 'stale-patient-reminder'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;

  v_command := format(
    $cmd$
      SELECT net.http_post(
        url := %L,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', %L
        )
      );
    $cmd$,
    v_url || '/functions/v1/stale-patient-reminder',
    'Bearer ' || v_service_key
  );

  PERFORM cron.schedule(
    'stale-patient-reminder',
    '0 9 * * *',
    v_command
  );
END;
$$;
