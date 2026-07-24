-- =============================================
-- Migration 004: increment_contact_count RPC + monthly reset function
-- =============================================

-- 1. increment_contact_count RPC
-- profile.html에서 WhatsApp 창 열기 / 폼 제출 직후 호출
CREATE OR REPLACE FUNCTION increment_contact_count(biz_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE businesses
  SET contacts_used_month = contacts_used_month + 1
  WHERE id = biz_id;
END;
$$;

-- anon/authenticated 롤에 실행 권한 부여
GRANT EXECUTE ON FUNCTION increment_contact_count(uuid) TO anon, authenticated;

-- 2. 월간 contacts 리셋 함수 (GitHub Actions cron에서 호출)
CREATE OR REPLACE FUNCTION reset_monthly_contacts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE businesses
  SET contacts_used_month  = 0,
      contacts_month_reset = CURRENT_DATE
  WHERE contacts_used_month > 0;
END;
$$;

-- service_role 롤에만 실행 권한 (cron 전용)
REVOKE EXECUTE ON FUNCTION reset_monthly_contacts() FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION reset_monthly_contacts() TO service_role;

-- 3. email_log에 is_voided 컬럼 추가 (Phase 3 Step 6 사전 준비)
ALTER TABLE email_log
  ADD COLUMN IF NOT EXISTS is_voided boolean DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_email_log_is_voided
  ON email_log(scenario, ref_id) WHERE is_voided = false;
