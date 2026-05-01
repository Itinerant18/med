CREATE TABLE IF NOT EXISTS user_preferences (
  user_id UUID PRIMARY KEY REFERENCES doctors(id) ON DELETE CASCADE,
  quiet_hours_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  quiet_hours_start INTEGER NOT NULL DEFAULT 22 CHECK (quiet_hours_start BETWEEN 0 AND 23),
  quiet_hours_end INTEGER NOT NULL DEFAULT 7 CHECK (quiet_hours_end BETWEEN 0 AND 23),
  notification_channels JSONB NOT NULL DEFAULT
    '{"patient": true, "visit": true, "followup": true, "system": true}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_preferences'
      AND policyname = 'user_preferences_select_own'
  ) THEN
    CREATE POLICY user_preferences_select_own
      ON user_preferences
      FOR SELECT
      USING (user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_preferences'
      AND policyname = 'user_preferences_insert_own'
  ) THEN
    CREATE POLICY user_preferences_insert_own
      ON user_preferences
      FOR INSERT
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_preferences'
      AND policyname = 'user_preferences_update_own'
  ) THEN
    CREATE POLICY user_preferences_update_own
      ON user_preferences
      FOR UPDATE
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

CREATE OR REPLACE FUNCTION update_user_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS user_preferences_updated_at ON user_preferences;

CREATE TRIGGER user_preferences_updated_at
  BEFORE UPDATE ON user_preferences
  FOR EACH ROW
  EXECUTE FUNCTION update_user_preferences_updated_at();
