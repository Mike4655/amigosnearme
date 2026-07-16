-- Migration 026: businesses 테이블에 이메일 인증 대기 컬럼 추가
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS pending_email TEXT,
  ADD COLUMN IF NOT EXISTS pending_email_token TEXT;
