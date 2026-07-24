-- Admin RPC: returns customer_profiles joined with auth.users email.
-- SECURITY DEFINER so authenticated users (admin) can read auth.users.
CREATE OR REPLACE FUNCTION get_customer_admin_data()
RETURNS TABLE(
  id            uuid,
  owner_id      uuid,
  email         text,
  account_status text,
  created_at    timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cp.id,
    cp.owner_id,
    u.email::text,
    cp.account_status,
    cp.created_at
  FROM customer_profiles cp
  JOIN auth.users u ON u.id = cp.owner_id
  ORDER BY cp.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION get_customer_admin_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_customer_admin_data() TO authenticated;
