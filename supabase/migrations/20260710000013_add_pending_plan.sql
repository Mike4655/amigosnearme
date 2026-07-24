-- =============================================
-- Migration 013: businesses에 pending_plan 컬럼 추가
-- 다운그레이드 예약 플랜 저장 (null = 예약 없음)
-- 업그레이드 즉시 적용 시 NULL로 리셋
-- =============================================

ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS pending_plan text;
