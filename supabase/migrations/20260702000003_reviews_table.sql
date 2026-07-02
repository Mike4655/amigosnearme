-- =============================================
-- Migration 003: reviews 테이블 재생성
-- =============================================

DROP TABLE IF EXISTS reviews CASCADE;

CREATE TABLE reviews (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  biz_id       uuid        NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  reviewer_id  uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating       integer     NOT NULL CHECK (rating BETWEEN 1 AND 5),
  review_text  text,
  flagged      boolean     DEFAULT false,
  created_at   timestamptz DEFAULT now()
);

CREATE INDEX idx_reviews_biz_id    ON reviews(biz_id);
CREATE INDEX idx_reviews_rating     ON reviews(rating);
CREATE INDEX idx_reviews_reviewer   ON reviews(reviewer_id);

-- 동일 고객이 같은 업체에 리뷰 중복 방지
CREATE UNIQUE INDEX idx_reviews_unique_reviewer_biz
  ON reviews(biz_id, reviewer_id);
