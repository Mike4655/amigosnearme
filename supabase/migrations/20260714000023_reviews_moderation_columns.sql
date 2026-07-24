-- Migration 023: reviews 테이블에 moderation 컬럼 추가

ALTER TABLE reviews
  ADD COLUMN IF NOT EXISTS flagged_at   timestamptz,
  ADD COLUMN IF NOT EXISTS removed      boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS removed_at   timestamptz,
  ADD COLUMN IF NOT EXISTS removed_note text;

-- flagged 리뷰 조회 인덱스
CREATE INDEX IF NOT EXISTS idx_reviews_flagged ON reviews(flagged) WHERE flagged = true;
-- removed 리뷰 제외 조회 인덱스
CREATE INDEX IF NOT EXISTS idx_reviews_not_removed ON reviews(biz_id) WHERE removed = false;
