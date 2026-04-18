-- migrations/20260418_followup_tasks.sql
CREATE TABLE public.followup_tasks (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id    UUID REFERENCES public.patients(id) ON DELETE CASCADE,
  dr_visit_id   UUID REFERENCES public.dr_visits(id) ON DELETE SET NULL,
  assigned_to   UUID REFERENCES auth.users(id),   -- agent's user id
  created_by    UUID REFERENCES auth.users(id),   -- doctor's user id
  due_date      DATE NOT NULL,
  notes         TEXT,
  status        TEXT DEFAULT 'pending'
                CHECK (status IN ('pending','completed','overdue')),
  completed_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.followup_tasks ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Doctors can see all followups" ON public.followup_tasks
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.doctors
      WHERE id = auth.uid() AND role = 'doctor'
    )
  );

CREATE POLICY "Doctors can create followups" ON public.followup_tasks
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.doctors
      WHERE id = auth.uid() AND role = 'doctor'
    )
  );

CREATE POLICY "Doctors can update/delete followups" ON public.followup_tasks
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.doctors
      WHERE id = auth.uid() AND role = 'doctor'
    )
  );

CREATE POLICY "Agents can see assigned followups" ON public.followup_tasks
  FOR SELECT USING (
    assigned_to = auth.uid()
  );

CREATE POLICY "Agents can update assigned followups" ON public.followup_tasks
  FOR UPDATE USING (
    assigned_to = auth.uid()
  );
