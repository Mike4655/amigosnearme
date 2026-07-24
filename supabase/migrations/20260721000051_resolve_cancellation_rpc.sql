-- Migration 051: Admin 전용 cancellation resolve + business soft-delete RPC

CREATE OR REPLACE FUNCTION process_cancellation_request(
  p_req_id   uuid,
  p_user_id  uuid,
  p_user_type text
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

  -- 1. soft-delete 해당 계정
  IF p_user_type IN ('business', 'worker') THEN
    UPDATE public.businesses SET account_status = 'deleted' WHERE owner_id = p_user_id;
  ELSIF p_user_type = 'employer' THEN
    UPDATE public.employer_profiles SET account_status = 'deleted' WHERE owner_id = p_user_id;
  ELSIF p_user_type = 'customer' THEN
    UPDATE public.customer_profiles SET account_status = 'deleted' WHERE id = p_user_id;
  END IF;

  -- 2. cancellation_request resolved = true
  UPDATE public.cancellation_requests SET resolved = true WHERE id = p_req_id;
END;
$$;

REVOKE ALL ON FUNCTION process_cancellation_request(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION process_cancellation_request(uuid, uuid, text) TO authenticated;
