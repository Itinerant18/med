CREATE TABLE IF NOT EXISTS notifications (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
  category     TEXT NOT NULL DEFAULT 'system',
  title        TEXT NOT NULL,
  body         TEXT NOT NULL,
  priority     TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'high', 'urgent')),
  is_read      BOOLEAN NOT NULL DEFAULT false,
  entity_type  TEXT,
  entity_id    UUID,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notif_recipient_idx ON notifications (recipient_id, created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notif_own" ON notifications USING (auth.uid() = recipient_id);
