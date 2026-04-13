-- Consolidated migration for MediFlow Patient Form and RBAC
-- Add extended fields to patients table
ALTER TABLE public.patients
  ADD COLUMN IF NOT EXISTS blood_group TEXT,
  ADD COLUMN IF NOT EXISTS national_id TEXT,
  ADD COLUMN IF NOT EXISTS alternate_phone TEXT,
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS state TEXT,
  ADD COLUMN IF NOT EXISTS pin_code TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_name TEXT,
  ADD COLUMN IF NOT EXISTS emergency_relationship TEXT,
  ADD COLUMN IF NOT EXISTS allergies TEXT,
  ADD COLUMN IF NOT EXISTS existing_conditions TEXT,
  ADD COLUMN IF NOT EXISTS current_medications TEXT,
  ADD COLUMN IF NOT EXISTS policy_number TEXT,
  ADD COLUMN IF NOT EXISTS created_by_id UUID REFERENCES auth.users(id);

-- Add role column to doctors table
ALTER TABLE public.doctors
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'doctor'
  CHECK (role IN ('doctor', 'assistant'));

-- 4. Create RLS Policies for RBAC (Prompt B4)
DROP POLICY IF EXISTS "assistants_own_patients_only" ON public.patients;
CREATE POLICY "assistants_own_patients_only"
ON public.patients
FOR SELECT
TO authenticated
USING (
  (SELECT role FROM public.doctors WHERE id = auth.uid()) = 'doctor'
  OR last_updated_by = (SELECT full_name FROM public.doctors WHERE id = auth.uid())
);

DROP POLICY IF EXISTS "assistants_update_own_only" ON public.patients;
CREATE POLICY "assistants_update_own_only"
ON public.patients
FOR UPDATE
TO authenticated
USING (
  (SELECT role FROM public.doctors WHERE id = auth.uid()) = 'doctor'
  OR last_updated_by = (SELECT full_name FROM public.doctors WHERE id = auth.uid())
);

-- Extend visits table for Vitals Tracking
ALTER TABLE public.visits 
ADD COLUMN IF NOT EXISTS bp_systolic INTEGER,
ADD COLUMN IF NOT EXISTS bp_diastolic INTEGER,
ADD COLUMN IF NOT EXISTS pulse INTEGER,
ADD COLUMN IF NOT EXISTS temperature DECIMAL,
ADD COLUMN IF NOT EXISTS spo2 INTEGER,
ADD COLUMN IF NOT EXISTS respiratory_rate INTEGER,
ADD COLUMN IF NOT EXISTS created_by_id UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS last_updated_by_id UUID REFERENCES auth.users(id);

-- Create RLS Policies for visits
DROP POLICY IF EXISTS "Doctors have full access to visits" ON public.visits;
CREATE POLICY "Doctors have full access to visits"
ON public.visits FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.doctors WHERE id = auth.uid()) = 'doctor'
);

DROP POLICY IF EXISTS "Assistants can access their own patients' visits" ON public.visits;
CREATE POLICY "Assistants can access their own patients' visits"
ON public.visits FOR ALL 
TO authenticated
USING (
  (SELECT role FROM public.doctors WHERE id = auth.uid()) = 'assistant'
  AND (
    last_updated_by = (SELECT full_name FROM public.doctors WHERE id = auth.uid())
    OR created_by_id = auth.uid()
  )
);
