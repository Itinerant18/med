-- migrations/20260418_dr_visits.sql
CREATE TABLE public.dr_visits (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id       UUID REFERENCES public.patients(id) ON DELETE CASCADE,
  doctor_id        UUID REFERENCES auth.users(id),
  assigned_agent_id UUID REFERENCES auth.users(id),  -- agent assigned
  visit_notes      TEXT,
  diagnosis        TEXT,
  visit_date       TIMESTAMPTZ DEFAULT NOW(),
  followup_date    DATE,
  followup_notes   TEXT,
  followup_status  TEXT DEFAULT 'pending'
                   CHECK (followup_status IN ('pending','completed','cancelled')),
  status           TEXT DEFAULT 'active'
                   CHECK (status IN ('active','completed','cancelled')),
  created_by_id    UUID REFERENCES auth.users(id),
  last_updated_by  TEXT,
  last_updated_at  TIMESTAMPTZ DEFAULT NOW(),
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.dr_visits ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Doctors can see all visits" ON public.dr_visits
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.doctors
      WHERE id = auth.uid() AND role = 'doctor'
    )
  );

CREATE POLICY "Doctors can create visits" ON public.dr_visits
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.doctors
      WHERE id = auth.uid() AND role = 'doctor'
    )
  );

CREATE POLICY "Doctors can update visits" ON public.dr_visits
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.doctors
      WHERE id = auth.uid() AND role = 'doctor'
    )
  );

CREATE POLICY "Agents can see assigned visits" ON public.dr_visits
  FOR SELECT USING (
    assigned_agent_id = auth.uid()
  );

CREATE POLICY "Agents can update assigned visits" ON public.dr_visits
  FOR UPDATE USING (
    assigned_agent_id = auth.uid()
  );
