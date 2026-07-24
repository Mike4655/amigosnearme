-- Migration 042: get_customer_admin_data 최종 버전
-- customer_profiles JOIN 제거 (400 에러 원인)
-- auth.users에서 admin/business/employer 제외 = customer

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
  WHERE u.email != 'collegeessayboard@gmail.com'
    AND NOT EXISTS (
      SELECT 1 FROM public.businesses b WHERE b.owner_id = u.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.employer_profiles ep WHERE ep.owner_id = u.id
    )
  ORDER BY u.created_at DESC;
$$;

REVOKE ALL ON FUNCTION get_customer_admin_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_customer_admin_data() TO authenticated;
