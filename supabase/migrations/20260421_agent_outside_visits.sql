-- Follow-up task schema safety tweaks
ALTER TABLE public.followup_tasks
  ALTER COLUMN created_at SET DEFAULT NOW();

DO $$
BEGIN
  IF (
    SELECT data_type FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'followup_tasks'
      AND column_name = 'due_date'
  ) = 'timestamp with time zone' THEN
    ALTER TABLE public.followup_tasks
      ALTER COLUMN due_date TYPE DATE USING due_date::DATE;
  END IF;
END $$;

-- Agent-reported outside (external) doctor visits
CREATE TABLE IF NOT EXISTS public.agent_outside_visits (
  id                        UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id                UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
  followup_task_id          UUID REFERENCES public.followup_tasks(id) ON DELETE SET NULL,
  agent_id                  UUID NOT NULL REFERENCES public.doctors(id),

  ext_doctor_name           TEXT NOT NULL,
  ext_doctor_specialization TEXT,
  ext_doctor_hospital       TEXT,
  ext_doctor_phone          TEXT,

  visit_date                DATE NOT NULL DEFAULT CURRENT_DATE,
  chief_complaint           TEXT,
  diagnosis                 TEXT,
  prescriptions             TEXT,
  visit_notes               TEXT,
  next_followup_date        DATE,

  status                    TEXT NOT NULL DEFAULT 'recorded'
                             CHECK (status IN ('recorded', 'reviewed')),
  reviewed_by               UUID REFERENCES public.doctors(id),
  reviewed_at               TIMESTAMPTZ,

  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.agent_outside_visits ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'agent_outside_visits'
      AND policyname = 'agent_outside_visits_select_rbac'
  ) THEN
    CREATE POLICY agent_outside_visits_select_rbac ON public.agent_outside_visits
      FOR SELECT USING (
        agent_id = auth.uid()
        OR public.get_my_role() IN ('head_doctor', 'doctor')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'agent_outside_visits'
      AND policyname = 'agent_outside_visits_insert_own'
  ) THEN
    CREATE POLICY agent_outside_visits_insert_own ON public.agent_outside_visits
      FOR INSERT WITH CHECK (agent_id = auth.uid());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'agent_outside_visits'
      AND policyname = 'agent_outside_visits_update_rbac'
  ) THEN
    CREATE POLICY agent_outside_visits_update_rbac ON public.agent_outside_visits
      FOR UPDATE USING (
        agent_id = auth.uid()
        OR public.get_my_role() IN ('head_doctor', 'doctor')
      );
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.agent_outside_visits_touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS agent_outside_visits_updated_at ON public.agent_outside_visits;
CREATE TRIGGER agent_outside_visits_updated_at
  BEFORE UPDATE ON public.agent_outside_visits
  FOR EACH ROW EXECUTE FUNCTION public.agent_outside_visits_touch_updated_at();
