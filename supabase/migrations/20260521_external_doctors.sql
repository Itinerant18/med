-- Creates the external_doctors table for manually tracking doctors outside
-- the practice (referral partners, specialists, etc.).
-- Distinct from the known_external_doctors VIEW which derives records from
-- agent_outside_visits history.

CREATE TABLE IF NOT EXISTS public.external_doctors (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    specialization  TEXT,
    hospital        TEXT,
    phone           TEXT,
    email           TEXT,
    added_by        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.external_doctors ENABLE ROW LEVEL SECURITY;

-- All authenticated staff can browse the directory
CREATE POLICY "external_doctors_select_authenticated"
    ON public.external_doctors FOR SELECT
    TO authenticated
    USING (true);

-- Any authenticated staff member can add a new external doctor
CREATE POLICY "external_doctors_insert_authenticated"
    ON public.external_doctors FOR INSERT
    TO authenticated
    WITH CHECK (added_by = (SELECT auth.uid()));

-- Only head doctors can edit existing records
CREATE POLICY "external_doctors_update_head_doctor"
    ON public.external_doctors FOR UPDATE
    TO authenticated
    USING  (public.get_my_role() = 'head_doctor')
    WITH CHECK (public.get_my_role() = 'head_doctor');

CREATE POLICY "external_doctors_delete_head_doctor"
    ON public.external_doctors FOR DELETE
    TO authenticated
    USING (public.get_my_role() = 'head_doctor');
