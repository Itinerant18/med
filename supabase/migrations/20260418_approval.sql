-- migrations/20260418_approval.sql
ALTER TABLE public.doctors
  ADD COLUMN IF NOT EXISTS approval_status TEXT
    DEFAULT 'pending'
    CHECK (approval_status IN ('pending','approved','rejected')),
  ADD COLUMN IF NOT EXISTS approved_by    UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS approved_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Existing doctors are auto-approved
UPDATE public.doctors SET approval_status = 'approved'
  WHERE approval_status = 'pending';
