-- Add title and priority columns consumed by the Add Follow-up sheet.
ALTER TABLE public.followup_tasks
  ADD COLUMN IF NOT EXISTS title TEXT,
  ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('normal', 'urgent'));
