-- Migration 046: get_customer_admin_data에 name 필드 추가

DROP FUNCTION IF EXISTS get_customer_admin_data();
CREATE OR REPLACE FUNCTION get_customer_admin_data()
RETURNS TABLE(
  id             uuid,
  owner_id       uuid,
  email          text,
  full_name      text,
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
    COALESCE(
      u.raw_user_meta_data->>'full_name',
      u.raw_user_meta_data->>'name',
      ''
    )::text       AS full_name,
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
