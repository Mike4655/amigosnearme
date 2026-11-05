-- Add expires_at column to jobs
ALTER TABLE jobs
  ADD COLUMN IF NOT EXISTS expires_at timestamptz;

-- Enable pg_cron extension (requires superuser; run once)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule daily job: expire jobs at midnight UTC
SELECT cron.schedule(
  'expire-jobs-daily',
  '0 0 * * *',
  $$
    UPDATE jobs
    SET status = 'closed'
    WHERE status = 'open'
      AND expires_at IS NOT NULL
      AND expires_at < now();
  $$
);
