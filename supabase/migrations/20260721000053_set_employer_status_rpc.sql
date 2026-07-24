-- Migration 053: Admin 전용 employer account_status 변경 RPC (RLS 우회)

CREATE OR REPLACE FUNCTION set_employer_account_status(
  p_employer_id uuid,   -- employer_profiles.id
  p_status      text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF auth.email() != 'collegeessayboard@gmail.com' THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;

  IF p_status NOT IN ('active', 'suspended', 'deleted') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  UPDATE public.employer_profiles
  SET account_status = p_status
  WHERE id = p_employer_id;
END;
$$;

REVOKE ALL ON FUNCTION set_employer_account_status(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION set_employer_account_status(uuid, text) TO authenticated;
