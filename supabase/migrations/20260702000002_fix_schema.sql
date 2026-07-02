-- =============================================
-- Migration 002: Fix schema — 기존 테이블 재설정
-- =============================================

-- 1. businesses 테이블 컬럼 추가 (이미 추가된 경우 무시)
ALTER TABLE businesses
  ADD COLUMN IF NOT EXISTS is_worker              boolean   DEFAULT false,
  ADD COLUMN IF NOT EXISTS account_status         text      DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS verified_badge         boolean   DEFAULT false,
  ADD COLUMN IF NOT EXISTS contacts_used_month    integer   DEFAULT 0,
  ADD COLUMN IF NOT EXISTS contacts_month_reset   date      DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS contact_balance        integer   DEFAULT 0;

-- account_status 제약 (기존 제약 제거 후 재생성)
ALTER TABLE businesses
  DROP CONSTRAINT IF EXISTS chk_account_status;
ALTER TABLE businesses
  ADD CONSTRAINT chk_account_status
  CHECK (account_status IN ('active', 'suspended', 'deleted'));

-- 기존 Worker 레코드에 is_worker 표시
UPDATE businesses
SET is_worker = true
WHERE categories @> ARRAY['staffing']::text[]
  AND is_worker = false;

-- 2. 기존 로그 테이블 재설정 (데이터 없으므로 DROP 후 재생성)
DROP TABLE IF EXISTS contact_log CASCADE;
DROP TABLE IF EXISTS cancellation_requests CASCADE;
DROP TABLE IF EXISTS email_log CASCADE;

CREATE TABLE contact_log (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  biz_id       uuid        REFERENCES businesses(id) ON DELETE CASCADE,
  customer_id  uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  channel      text        NOT NULL,
  limit_hit    boolean     DEFAULT false,
  created_at   timestamptz DEFAULT now()
);

CREATE TABLE cancellation_requests (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  biz_id      uuid        REFERENCES businesses(id) ON DELETE CASCADE,
  reason      text,
  created_at  timestamptz DEFAULT now(),
  resolved    boolean     DEFAULT false
);

CREATE TABLE email_log (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario    text        NOT NULL,
  recipient   text        NOT NULL,
  ref_id      uuid,
  sent_at     timestamptz DEFAULT now()
);

-- 3. 인덱스
CREATE INDEX IF NOT EXISTS idx_businesses_account_status  ON businesses(account_status);
CREATE INDEX IF NOT EXISTS idx_businesses_is_worker       ON businesses(is_worker);
CREATE INDEX IF NOT EXISTS idx_contact_log_biz_id         ON contact_log(biz_id);
CREATE INDEX IF NOT EXISTS idx_contact_log_created_at     ON contact_log(created_at);
CREATE INDEX IF NOT EXISTS idx_email_log_scenario_ref     ON email_log(scenario, ref_id);
