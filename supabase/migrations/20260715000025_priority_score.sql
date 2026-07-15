-- Migration 025: businesses 테이블에 priority_score 컬럼 추가
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS priority_score integer NOT NULL DEFAULT 0
    CHECK (priority_score >= 0 AND priority_score <= 20);

CREATE INDEX IF NOT EXISTS idx_businesses_priority ON public.businesses(priority_score DESC);
