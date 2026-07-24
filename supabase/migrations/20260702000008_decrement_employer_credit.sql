-- RPC: decrement_employer_credit
-- Atomically decrements credit_balance by 1.
-- Returns new balance. Raises exception if balance is already 0.
CREATE OR REPLACE FUNCTION decrement_employer_credit(p_employer_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
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

-- Only authenticated users can call this; the SECURITY DEFINER
-- runs as the function owner so no extra table grants are needed.
REVOKE ALL ON FUNCTION decrement_employer_credit(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION decrement_employer_credit(uuid) TO authenticated;
