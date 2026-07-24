-- Migration 017: decrement_employer_credit에 SET search_path = public 추가
-- (increment_credit_balance와 동일한 보안 패턴 적용)

CREATE OR REPLACE FUNCTION public.decrement_employer_credit(p_employer_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance integer;
BEGIN
  SELECT credit_balance INTO v_balance
  FROM employer_profiles
  WHERE owner_id = p_employer_id
  FOR UPDATE;

  IF v_balance IS NULL THEN
    RAISE EXCEPTION 'Employer profile not found for user %', p_employer_id;
  END IF;

  IF v_balance <= 0 THEN
    RAISE EXCEPTION 'Insufficient credits';
  END IF;

  UPDATE employer_profiles
  SET credit_balance = credit_balance - 1
  WHERE owner_id = p_employer_id;

  RETURN v_balance - 1;
END;
$$;

REVOKE ALL ON FUNCTION public.decrement_employer_credit(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.decrement_employer_credit(uuid) TO authenticated;
