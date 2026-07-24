-- Migration 032: Worker 희망 급여 컬럼 추가
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS desired_pay text DEFAULT NULL;
