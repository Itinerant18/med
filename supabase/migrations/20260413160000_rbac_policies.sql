-- ============================================================
-- STEP 0: DROP ALL CONFLICTING OLD POLICIES
-- ============================================================

-- PATIENTS
DROP POLICY IF EXISTS "Allow authenticated insert patients" ON public.patients;
DROP POLICY IF EXISTS "Allow authenticated read patients" ON public.patients;
DROP POLICY IF EXISTS "Allow authenticated update patients" ON public.patients;
DROP POLICY IF EXISTS "Enable INSERT for authenticated users" ON public.patients;
DROP POLICY IF EXISTS "Enable SELECT for authenticated users" ON public.patients;
DROP POLICY IF EXISTS "Enable UPDATE for authenticated users" ON public.patients;
DROP POLICY IF EXISTS "RBAC access to patients" ON public.patients;
DROP POLICY IF EXISTS "assistants_own_patients_only" ON public.patients;
DROP POLICY IF EXISTS "assistants_update_own_only" ON public.patients;

-- VISITS
DROP POLICY IF EXISTS "Allow authenticated insert visits" ON public.visits;
DROP POLICY IF EXISTS "Allow authenticated read visits" ON public.visits;
DROP POLICY IF EXISTS "Allow authenticated update visits" ON public.visits;
DROP POLICY IF EXISTS "Enable INSERT for authenticated users" ON public.visits;
DROP POLICY IF EXISTS "Enable SELECT for authenticated users" ON public.visits;
DROP POLICY IF EXISTS "Enable UPDATE for authenticated users" ON public.visits;
DROP POLICY IF EXISTS "Assistants can access their own patients visits" ON public.visits;
DROP POLICY IF EXISTS "Assistants can access their own patients' visits" ON public.visits;
DROP POLICY IF EXISTS "Doctors have full access to visits" ON public.visits;

-- DOCTORS
DROP POLICY IF EXISTS "Enable INSERT for authenticated users" ON public.doctors;
DROP POLICY IF EXISTS "Enable SELECT for authenticated users" ON public.doctors;
DROP POLICY IF EXISTS "Enable UPDATE for authenticated users" ON public.doctors;

-- ============================================================
-- STEP 1: CLEAN ROLE-HELPER FUNCTION (avoids repeated subqueries)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
SELECT role FROM public.doctors WHERE id = auth.uid();
$$;

-- ============================================================
-- STEP 2: DOCTORS TABLE POLICIES
-- ============================================================

-- All authenticated users can read all doctors (needed for name lookups)
CREATE POLICY "doctors_select_all"
ON public.doctors FOR SELECT
TO authenticated
USING (true);

-- Users can only insert their own doctor row
CREATE POLICY "doctors_insert_own"
ON public.doctors FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- Users can only update their own row
CREATE POLICY "doctors_update_own"
ON public.doctors FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- ============================================================
-- STEP 3: PATIENTS TABLE POLICIES (UUID-based, no text names)
-- ============================================================

-- SELECT: Doctors see all, assistants see only their own (by UUID)
CREATE POLICY "patients_select_rbac"
ON public.patients FOR SELECT
TO authenticated
USING (
  public.get_my_role() = 'doctor'
  OR created_by_id = auth.uid()
);

-- INSERT: Any authenticated user can add a patient
-- (created_by_id will be set by the app to auth.uid())
CREATE POLICY "patients_insert_authenticated"
ON public.patients FOR INSERT
TO authenticated
WITH CHECK (created_by_id = auth.uid());

-- UPDATE: Doctors update any, assistants update only own
CREATE POLICY "patients_update_rbac"
ON public.patients FOR UPDATE
TO authenticated
USING (
  public.get_my_role() = 'doctor'
  OR created_by_id = auth.uid()
)
WITH CHECK (
  public.get_my_role() = 'doctor'
  OR created_by_id = auth.uid()
);

-- DELETE: Doctors delete any, assistants delete only own
CREATE POLICY "patients_delete_rbac"
ON public.patients FOR DELETE
TO authenticated
USING (
  public.get_my_role() = 'doctor'
  OR created_by_id = auth.uid()
);

-- ============================================================
-- STEP 4: VISITS TABLE POLICIES
-- ============================================================

-- SELECT: Doctors see all visits, assistants see visits for their patients
CREATE POLICY "visits_select_rbac"
ON public.visits FOR SELECT
TO authenticated
USING (
  public.get_my_role() = 'doctor'
  OR created_by_id = auth.uid()
);

-- INSERT: Any authenticated user
CREATE POLICY "visits_insert_authenticated"
ON public.visits FOR INSERT
TO authenticated
WITH CHECK (created_by_id = auth.uid());

-- UPDATE: Doctors update any, assistants update own
CREATE POLICY "visits_update_rbac"
ON public.visits FOR UPDATE
TO authenticated
USING (
  public.get_my_role() = 'doctor'
  OR created_by_id = auth.uid()
)
WITH CHECK (
  public.get_my_role() = 'doctor'
  OR created_by_id = auth.uid()
);

-- DELETE: Doctors only
CREATE POLICY "visits_delete_doctors_only"
ON public.visits FOR DELETE
TO authenticated
USING (public.get_my_role() = 'doctor');
