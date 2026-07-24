-- =============================================
-- Migration 007: Phase 3 — contact_log.customer_id → actor_id
-- (§9.5 기준 — Customer·Employer 모두 actor_id로 통합)
-- =============================================

ALTER TABLE contact_log RENAME COLUMN customer_id TO actor_id;

-- actor_id 인덱스 갱신
DROP INDEX IF EXISTS idx_contact_log_customer;
CREATE INDEX IF NOT EXISTS idx_contact_log_actor ON contact_log(actor_id);
