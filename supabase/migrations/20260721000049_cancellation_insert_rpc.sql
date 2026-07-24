-- Migration 049: cancellation_requests INSERT용 SECURITY DEFINER RPC

CREATE OR REPLACE FUNCTION submit_cancellation_request(
  p_user_type text,
  p_reason    text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_uid uuid;
  v_id  uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.cancellation_requests (user_id, user_type, reason)
  VALUES (v_uid, p_user_type, p_reason)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION submit_cancellation_request(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION submit_cancellation_request(text, text) TO authenticated;
