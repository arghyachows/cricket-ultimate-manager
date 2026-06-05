-- Idempotency keys table for match operations.
--
-- Every match request carries a client-generated idempotency key (UUID v4).
-- The server rejects duplicate keys, returning the original stored result.
-- Keys expire after 24 hours (TTL enforced by the backend).
--
-- This prevents accidental duplicate match creation when the client retries
-- due to network failures, without consuming server resources to re-execute.

CREATE TABLE IF NOT EXISTS idempotency_keys (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key TEXT NOT NULL UNIQUE,
  user_id       UUID NOT NULL REFERENCES auth_users(id) ON DELETE CASCADE,
  operation     TEXT NOT NULL CHECK (operation IN (
                  'start_match',
                  'confirm_match',
                  'cancel_match',
                  'complete_match'
                )),
  result        JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '24 hours'
);

-- Fast lookup by idempotency key
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_key
  ON idempotency_keys (idempotency_key);

-- Periodic cleanup of expired keys
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_expires_at
  ON idempotency_keys (expires_at)
  WHERE expires_at < now();

-- Revoke delete/update on expired rows — only the cleanup job may remove them
ALTER TABLE idempotency_keys ENABLE ROW LEVEL SECURITY;

-- Allow insert for authenticated users
CREATE POLICY insert_idempotency_key ON idempotency_keys
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Allow select for the owning user or service role
CREATE POLICY select_idempotency_key ON idempotency_keys
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);
