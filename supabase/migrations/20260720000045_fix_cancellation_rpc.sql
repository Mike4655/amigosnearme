-- Migration 045: get_cancellation_admin_data RPC 재생성 (remote 누락 보완)

ALTER TABLE public.cancellation_requests
  ADD COLUMN IF NOT EXISTS user_id   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS user_type text CHECK (user_type IN ('business','worker','customer','employer'));

CREATE OR REPLACE FUNCTION get_cancellation_admin_data()
RETURNS TABLE(
  id         uuid,
  user_id    uuid,
  email      text,
  user_type  text,
  reason     text,
  created_at timestamptz,
  resolved   boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT
    cr.id,
    cr.user_id,
    u.email::text,
    cr.user_type,
    cr.reason,
    cr.created_at,
    cr.resolved
  FROM public.cancellation_requests cr
  LEFT JOIN auth.users u ON u.id = cr.user_id
  ORDER BY cr.resolved ASC, cr.created_at DESC;
$$;

REVOKE ALL ON FUNCTION get_cancellation_admin_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_cancellation_admin_data() TO authenticated;
