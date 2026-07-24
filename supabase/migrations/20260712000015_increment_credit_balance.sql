-- Migration 015: increment_credit_balance RPC
-- credit_balance를 atomic하게 증가시키는 함수 (race condition 방지)

CREATE OR REPLACE FUNCTION public.increment_credit_balance(
  p_employer_id uuid,
  p_amount      integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE employer_profiles
  SET credit_balance = COALESCE(credit_balance, 0) + p_amount
  WHERE id = p_employer_id;
END;
$$;
