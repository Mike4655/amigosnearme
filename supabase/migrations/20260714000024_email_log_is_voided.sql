-- Migration 024: email_log에 is_voided 컬럼 추가
-- EM3/EM4/EM6 dedup 초기화 (크레딧 구매 시 해당 사이클의 경고 이메일 dedup 해제)

ALTER TABLE email_log ADD COLUMN IF NOT EXISTS is_voided boolean DEFAULT false;

-- voided 되지 않은 최신 로그 조회용 인덱스
CREATE INDEX IF NOT EXISTS idx_email_log_scenario_ref_voided
  ON email_log(scenario, ref_id, is_voided);
