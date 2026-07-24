-- Migration 022: DROP contact_balance from businesses
-- Employer 크레딧은 employer_profiles.credit_balance 로 이전 완료 (Phase 3)
-- businesses 테이블의 contact_balance 컬럼은 더 이상 사용하지 않음

ALTER TABLE businesses DROP COLUMN IF EXISTS contact_balance;
