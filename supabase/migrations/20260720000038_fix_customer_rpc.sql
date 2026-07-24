-- Migration 038: get_customer_admin_data — OR 조건으로 포용 범위 확장
-- user_type='customer' 메타데이터가 없어도 customer_profiles 행이 있으면 반환
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
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(cp.id, gen_random_uuid())          AS id,
    u.id                                         AS owner_id,
    u.email::text                                AS email,
    COALESCE(cp.account_status, 'active'::text)  AS account_status,
    COALESCE(cp.created_at, u.created_at)        AS created_at
  FROM auth.users u
  LEFT JOIN public.customer_profiles cp ON cp.owner_id = u.id
  WHERE u.raw_user_meta_data->>'user_type' = 'customer'
     OR cp.id IS NOT NULL
  ORDER BY u.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION get_customer_admin_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_customer_admin_data() TO authenticated;
