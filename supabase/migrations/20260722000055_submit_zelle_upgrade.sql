-- Migration 055: submit_zelle_upgrade RPC
-- 업체 오너가 Zelle 결제 완료를 신고 → plan='pending_zelle', pending_plan=target_plan
CREATE OR REPLACE FUNCTION submit_zelle_upgrade(p_biz_id uuid, p_plan text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
BEGIN
  -- 호출자 본인 소유 업체만 허용
  IF NOT EXISTS (
    SELECT 1 FROM public.businesses WHERE id = p_biz_id AND owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;

  IF p_plan NOT IN ('basic', 'premium') THEN
    RAISE EXCEPTION 'Invalid plan: %', p_plan;
  END IF;

  UPDATE public.businesses
    SET plan = 'pending_zelle', pending_plan = p_plan
    WHERE id = p_biz_id;
END;
$$;

REVOKE ALL ON FUNCTION submit_zelle_upgrade(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION submit_zelle_upgrade(uuid, text) TO authenticated;
