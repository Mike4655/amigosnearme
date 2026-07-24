-- Migration 040: get_customer_admin_data 완전 재작성
-- 목적: 필터 없이 auth.users 전체 반환 → 어떤 유저가 존재하는지 확인

CREATE OR REPLACE FUNCTION get_customer_admin_data()
RETURNS TABLE(
  id             uuid,
  owner_id       uuid,
  email          text,
  account_status text,
  created_at     timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id                                          AS id,
    u.id                                          AS owner_id,
    u.email::text                                 AS email,
    COALESCE(cp.account_status, 'active'::text)   AS account_status,
    COALESCE(cp.created_at, u.created_at)         AS created_at
  FROM auth.users u
  LEFT JOIN public.customer_profiles cp ON cp.owner_id = u.id
  WHERE u.email IS NOT NULL
  ORDER BY u.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION get_customer_admin_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_customer_admin_data() TO authenticated;
