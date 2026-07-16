-- Migration 028: reset_monthly_contacts에 pending_plan 발효 로직 추가
-- 매월 1일 실행 시: contacts 리셋 + 예약된 다운그레이드 플랜 적용

CREATE OR REPLACE FUNCTION reset_monthly_contacts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE businesses
  SET contacts_used_month  = 0,
      contacts_month_reset = CURRENT_DATE,
      plan                 = COALESCE(pending_plan, plan),
      pending_plan         = NULL
  WHERE contacts_used_month > 0
     OR pending_plan IS NOT NULL;
END;
$$;
