-- Migration 041: customer_profiles JOIN 없이 auth.users만으로 재작성
-- 400 에러 원인 진단 — cp 참조 제거

CREATE OR REPLACE FUNCTION get_customer_admin_data()
RETURNS TABLE(
  id             uuid,
  owner_id       uuid,
  email          text,
  account_status text,
  created_at     timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT
    u.id          AS id,
    u.id          AS owner_id,
    u.email::text AS email,
    'active'::text AS account_status,
    u.created_at  AS created_at
  FROM auth.users u
  ORDER BY u.created_at DESC;
$$;

REVOKE ALL ON FUNCTION get_customer_admin_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_customer_admin_data() TO authenticated;
