-- Migration 018: employer_profiles에 display_name, phone 컬럼 추가
ALTER TABLE public.employer_profiles
  ADD COLUMN IF NOT EXISTS display_name text,
  ADD COLUMN IF NOT EXISTS phone        text;
