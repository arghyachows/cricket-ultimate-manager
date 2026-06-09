-- ============================================================
-- Add daily_streak column to users table for daily reward streaks
-- ============================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS daily_streak INT NOT NULL DEFAULT 0;

-- Create index for streak queries
CREATE INDEX IF NOT EXISTS idx_users_daily_streak ON users(daily_streak);
