-- =============================================
-- AmigosNearMe — Migration 001: Schema Fixes
-- =============================================

-- 1. businesses 테이블 컬럼 추가
ALTER TABLE businesses
  ADD COLUMN IF NOT EXISTS is_worker              boolean   DEFAULT false,
  ADD COLUMN IF NOT EXISTS account_status         text      DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS verified_badge         boolean   DEFAULT false,
  ADD COLUMN IF NOT EXISTS contacts_used_month    integer   DEFAULT 0,
  ADD COLUMN IF NOT EXISTS contacts_month_reset   date      DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS contact_balance        integer   DEFAULT 0;

-- account_status 허용값 제약
ALTER TABLE businesses
  DROP CONSTRAINT IF EXISTS chk_account_status;
ALTER TABLE businesses
  ADD CONSTRAINT chk_account_status
  CHECK (account_status IN ('active', 'suspended', 'deleted'));

-- 2. 기존 Worker 레코드 마이그레이션
-- categories에 'staffing'이 포함된 레코드를 Worker로 표시
UPDATE businesses
SET is_worker = true
WHERE categories @> ARRAY['staffing']::text[];

-- 3. contact_log 테이블 (SB6, SB12, SB13, W2 용)
CREATE TABLE IF NOT EXISTS contact_log (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  biz_id       uuid        REFERENCES businesses(id) ON DELETE CASCADE,
  customer_id  uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  channel      text        NOT NULL,   -- 'whatsapp' | 'form'
  limit_hit    boolean     DEFAULT false,  -- 한도 소진 상태에서 시도 여부 (SB12/SB13)
  created_at   timestamptz DEFAULT now()
);

-- 4. cancellation_requests 테이블 (AD4 용)
CREATE TABLE IF NOT EXISTS cancellation_requests (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  biz_id      uuid        REFERENCES businesses(id) ON DELETE CASCADE,
  reason      text,
  created_at  timestamptz DEFAULT now(),
  resolved    boolean     DEFAULT false
);

-- 5. email_log 테이블 (중복 발송 방지)
CREATE TABLE IF NOT EXISTS email_log (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario    text        NOT NULL,   -- 'SB1', 'SB8', 'AD1' 등
  recipient   text        NOT NULL,
  ref_id      uuid,                   -- 관련 레코드 ID
  sent_at     timestamptz DEFAULT now()
);

-- 6. 인덱스
CREATE INDEX IF NOT EXISTS idx_businesses_account_status  ON businesses(account_status);
CREATE INDEX IF NOT EXISTS idx_businesses_is_worker       ON businesses(is_worker);
CREATE INDEX IF NOT EXISTS idx_contact_log_biz_id         ON contact_log(biz_id);
CREATE INDEX IF NOT EXISTS idx_contact_log_created_at     ON contact_log(created_at);
CREATE INDEX IF NOT EXISTS idx_email_log_scenario_ref     ON email_log(scenario, ref_id);
