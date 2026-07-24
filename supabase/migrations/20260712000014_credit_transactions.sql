-- Migration 014: credit_transactions 테이블 생성
-- Employer 크레딧 구매 내역 기록

CREATE TABLE IF NOT EXISTS public.credit_transactions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employer_id   uuid NOT NULL REFERENCES public.employer_profiles(id) ON DELETE CASCADE,
  amount_usd    numeric(10,2) NOT NULL,
  credits_added integer NOT NULL,
  payment_ref   text,
  created_at    timestamptz DEFAULT now()
);

ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;

-- 본인 거래 내역만 조회 가능
CREATE POLICY "tx_own_select" ON public.credit_transactions
  FOR SELECT USING (
    employer_id IN (
      SELECT id FROM public.employer_profiles WHERE owner_id = auth.uid()
    )
  );

-- 삽입은 service role(Edge Function)만 허용 — 클라이언트 직접 삽입 불가
