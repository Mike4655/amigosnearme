-- =============================================
-- Migration 006: Phase 3 — employer_profiles 테이블 생성
-- =============================================

CREATE TABLE IF NOT EXISTS employer_profiles (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id       uuid        NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  credit_balance integer     NOT NULL DEFAULT 0,
  account_status text        NOT NULL DEFAULT 'active'
                             CHECK (account_status IN ('active','suspended','deleted')),
  created_at     timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_employer_profiles_owner ON employer_profiles(owner_id);

-- credit_transactions 테이블 (구매 이력 — Phase 5 결제 연동 후 채워짐)
CREATE TABLE IF NOT EXISTS credit_transactions (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  employer_id  uuid        NOT NULL REFERENCES employer_profiles(id) ON DELETE CASCADE,
  amount_usd   numeric(10,2),
  credits_added integer    NOT NULL,
  payment_ref  text,
  created_at   timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_credit_tx_employer ON credit_transactions(employer_id);

-- Phase 1~2 기간 가입한 기존 Employer 일괄 마이그레이션
INSERT INTO employer_profiles (owner_id)
SELECT id FROM auth.users
WHERE raw_user_meta_data->>'user_type' = 'employer'
  AND id NOT IN (SELECT owner_id FROM employer_profiles);
