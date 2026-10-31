-- businesses 테이블에 welcome_sent 컬럼 추가
-- SB1/W1 환영 이메일 중복 발송 방지용 플래그
-- Resend SMTP 연결로 이메일 인증이 활성화된 이후,
-- 인증 완료 후 첫 로그인 시 dashboard.html에서 SB1을 발송하기 위해 사용
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS welcome_sent boolean NOT NULL DEFAULT false;
