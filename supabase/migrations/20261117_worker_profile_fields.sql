-- Worker profile visibility & credit earning fields
ALTER TABLE businesses
  ADD COLUMN IF NOT EXISTS profile_visible   boolean      DEFAULT true,
  ADD COLUMN IF NOT EXISTS worker_credits    numeric(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS work_auth         text,
  ADD COLUMN IF NOT EXISTS driver_license    jsonb,
  ADD COLUMN IF NOT EXISTS transportation    text[]       DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS experience        jsonb        DEFAULT '[]';

-- Index for fast "find public workers" queries
CREATE INDEX IF NOT EXISTS idx_businesses_profile_visible
  ON businesses (profile_visible, is_worker)
  WHERE is_worker = true AND profile_visible = true;

COMMENT ON COLUMN businesses.profile_visible  IS 'Worker: show profile in employer search results';
COMMENT ON COLUMN businesses.worker_credits   IS 'Worker: accumulated credit balance (paid out at $100)';
COMMENT ON COLUMN businesses.work_auth        IS 'Worker: citizen_pr | ead | visa | prefer_not';
COMMENT ON COLUMN businesses.driver_license   IS 'Worker: {has_license, state, class}';
COMMENT ON COLUMN businesses.transportation   IS 'Worker: own_vehicle | motorcycle | public_transit | need_ride';
COMMENT ON COLUMN businesses.experience       IS 'Worker: [{role, type, years, months, projects, note}]';
