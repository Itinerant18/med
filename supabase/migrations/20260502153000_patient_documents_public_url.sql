CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.patient_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
  public_url TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.patient_documents
  ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS patient_id UUID,
  ADD COLUMN IF NOT EXISTS public_url TEXT,
  ADD COLUMN IF NOT EXISTS storage_path TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

ALTER TABLE public.patient_documents
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ALTER COLUMN created_at SET DEFAULT now();

UPDATE public.patient_documents
SET id = gen_random_uuid()
WHERE id IS NULL;

UPDATE public.patient_documents
SET created_at = now()
WHERE created_at IS NULL;

ALTER TABLE public.patient_documents
  ALTER COLUMN id SET NOT NULL,
  ALTER COLUMN patient_id SET NOT NULL,
  ALTER COLUMN public_url SET NOT NULL,
  ALTER COLUMN storage_path SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'patient_documents_pkey'
      AND conrelid = 'public.patient_documents'::regclass
  ) THEN
    ALTER TABLE public.patient_documents
      ADD CONSTRAINT patient_documents_pkey PRIMARY KEY (id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'patient_documents_patient_id_fkey'
      AND conrelid = 'public.patient_documents'::regclass
  ) THEN
    ALTER TABLE public.patient_documents
      ADD CONSTRAINT patient_documents_patient_id_fkey
      FOREIGN KEY (patient_id)
      REFERENCES public.patients(id)
      ON DELETE CASCADE;
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'patient_documents_patient_id_storage_path_key'
      AND conrelid = 'public.patient_documents'::regclass
  ) THEN
    ALTER TABLE public.patient_documents
      ADD CONSTRAINT patient_documents_patient_id_storage_path_key
      UNIQUE (patient_id, storage_path);
  END IF;
END
$$;

ALTER TABLE public.patient_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "patient_documents_select_own" ON public.patient_documents;
CREATE POLICY "patient_documents_select_own"
ON public.patient_documents
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.patients
    WHERE patients.id = patient_documents.patient_id
      AND patients.created_by_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "patient_documents_insert_own" ON public.patient_documents;
CREATE POLICY "patient_documents_insert_own"
ON public.patient_documents
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.patients
    WHERE patients.id = patient_documents.patient_id
      AND patients.created_by_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "patient_documents_delete_own" ON public.patient_documents;
CREATE POLICY "patient_documents_delete_own"
ON public.patient_documents
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.patients
    WHERE patients.id = patient_documents.patient_id
      AND patients.created_by_id = auth.uid()
  )
);
