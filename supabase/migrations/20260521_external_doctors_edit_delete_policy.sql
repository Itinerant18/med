-- Expand UPDATE/DELETE permissions so the user who added an entry can also
-- edit or remove it (not just head_doctors).
DROP POLICY IF EXISTS "external_doctors_update_head_doctor" ON public.external_doctors;
DROP POLICY IF EXISTS "external_doctors_delete_head_doctor" ON public.external_doctors;

CREATE POLICY "external_doctors_update_authorized"
    ON public.external_doctors FOR UPDATE
    TO authenticated
    USING  (public.get_my_role() = 'head_doctor' OR added_by = (SELECT auth.uid()))
    WITH CHECK (public.get_my_role() = 'head_doctor' OR added_by = (SELECT auth.uid()));

CREATE POLICY "external_doctors_delete_authorized"
    ON public.external_doctors FOR DELETE
    TO authenticated
    USING (public.get_my_role() = 'head_doctor' OR added_by = (SELECT auth.uid()));
