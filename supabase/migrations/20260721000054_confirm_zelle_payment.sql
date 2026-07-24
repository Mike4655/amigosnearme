-- Migration 054: Zelle 결제 확인 RPC
-- Admin이 Zelle 입금 확인 후 plan을 pending_plan 값으로 활성화

CREATE OR REPLACE FUNCTION confirm_zelle_payment(p_biz_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_plan text;
BEGIN
  IF auth.email() != 'collegeessayboard@gmail.com' THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;

  SELECT pending_plan INTO v_plan
  FROM public.businesses
  WHERE id = p_biz_id AND plan = 'pending_zelle';

  IF v_plan IS NULL THEN
    RAISE EXCEPTION 'No pending Zelle payment found for this business';
  END IF;

  UPDATE public.businesses
  SET plan         = v_plan,
      pending_plan = NULL
  WHERE id = p_biz_id;

  RETURN v_plan;
END;
$$;
