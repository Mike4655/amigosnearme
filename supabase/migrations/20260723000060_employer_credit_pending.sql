-- Migration 060: Employer credit pending flow
-- Adds pending columns + submit/confirm RPCs

-- 1. pending 컬럼 추가
ALTER TABLE public.employer_profiles
  ADD COLUMN IF NOT EXISTS pending_credits        integer,
  ADD COLUMN IF NOT EXISTS pending_payment_method text,
  ADD COLUMN IF NOT EXISTS pending_package_id     text,
  ADD COLUMN IF NOT EXISTS pending_submitted_at   timestamptz;

-- 2. submit_employer_credit_manual: employer가 결제 완료 후 호출
DROP FUNCTION IF EXISTS public.submit_employer_credit_manual(uuid, text, text);
CREATE OR REPLACE FUNCTION public.submit_employer_credit_manual(
  p_employer_id    uuid,
  p_package_id     text,
  p_payment_method text DEFAULT 'zelle'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_credits integer;
BEGIN
  -- 패키지별 크레딧 수
  v_credits := CASE p_package_id
    WHEN 'starter' THEN 5
    WHEN 'value'   THEN 15
    WHEN 'pro'     THEN 30
    ELSE 0
  END;

  IF v_credits = 0 THEN
    RAISE EXCEPTION 'Unknown package_id: %', p_package_id;
  END IF;

  UPDATE public.employer_profiles
  SET
    pending_credits        = v_credits,
    pending_payment_method = p_payment_method,
    pending_package_id     = p_package_id,
    pending_submitted_at   = now()
  WHERE id = p_employer_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_employer_credit_manual(uuid, text, text) TO authenticated;

-- 3. confirm_employer_credit_manual: admin이 결제 확인 후 호출
DROP FUNCTION IF EXISTS public.confirm_employer_credit_manual(uuid);
CREATE OR REPLACE FUNCTION public.confirm_employer_credit_manual(
  p_employer_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_credits integer;
  v_pkg     text;
  v_amt     numeric;
BEGIN
  SELECT pending_credits, pending_package_id
  INTO v_credits, v_pkg
  FROM public.employer_profiles
  WHERE id = p_employer_id;

  IF v_credits IS NULL OR v_credits = 0 THEN
    RAISE EXCEPTION 'No pending credits for employer %', p_employer_id;
  END IF;

  v_amt := CASE v_pkg
    WHEN 'starter' THEN 10
    WHEN 'value'   THEN 20
    WHEN 'pro'     THEN 30
    ELSE 0
  END;

  -- 크레딧 지급 + pending 클리어
  UPDATE public.employer_profiles
  SET
    credit_balance         = credit_balance + v_credits,
    pending_credits        = NULL,
    pending_payment_method = NULL,
    pending_package_id     = NULL,
    pending_submitted_at   = NULL
  WHERE id = p_employer_id;

  -- 거래 이력 기록
  INSERT INTO public.credit_transactions (employer_id, credits_added, amount_usd, payment_ref)
  VALUES (p_employer_id, v_credits, v_amt, 'manual-' || v_pkg);
END;
$$;

-- admin only (collegeessayboard@gmail.com)
REVOKE EXECUTE ON FUNCTION public.confirm_employer_credit_manual(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_employer_credit_manual(uuid)
  TO authenticated;
