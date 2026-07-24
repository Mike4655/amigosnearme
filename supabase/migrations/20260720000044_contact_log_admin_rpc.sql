-- Migration 044: contact_log admin RPC
-- remote DB는 customer_id (actor_id로 rename 미적용) → alias 처리
-- 동시에 contact_log.actor_id 컬럼 rename 보장

ALTER TABLE public.contact_log RENAME COLUMN customer_id TO actor_id;

CREATE OR REPLACE FUNCTION get_contact_log_admin()
RETURNS TABLE(
  id         uuid,
  biz_id     uuid,
  actor_id   uuid,
  limit_hit  boolean,
  created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT cl.id, cl.biz_id, cl.actor_id, cl.limit_hit, cl.created_at
  FROM public.contact_log cl
  ORDER BY cl.created_at DESC;
$$;

REVOKE ALL ON FUNCTION get_contact_log_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_contact_log_admin() TO authenticated;
