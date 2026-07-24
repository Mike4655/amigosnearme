-- Migration 052: get_cancellation_admin_data에 biz_name 추가

DROP FUNCTION IF EXISTS get_cancellation_admin_data();
CREATE OR REPLACE FUNCTION get_cancellation_admin_data()
RETURNS TABLE(
  id         uuid,
  user_id    uuid,
  email      text,
  biz_name   text,
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
    COALESCE(
      b.trade_name,
      b.business_name,
      ep.display_name,
      u.raw_user_meta_data->>'display_name',
      u.raw_user_meta_data->>'business_name',
      u.email::text
    )::text AS biz_name,
    cr.user_type,
    cr.reason,
    cr.created_at,
    cr.resolved
  FROM public.cancellation_requests cr
  LEFT JOIN auth.users u ON u.id = cr.user_id
  LEFT JOIN public.businesses b ON b.owner_id = cr.user_id
  LEFT JOIN public.employer_profiles ep ON ep.owner_id = cr.user_id
  ORDER BY cr.resolved ASC, cr.created_at DESC;
$$;

REVOKE ALL ON FUNCTION get_cancellation_admin_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_cancellation_admin_data() TO authenticated;
