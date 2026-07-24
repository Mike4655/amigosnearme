-- Fix cancellation_requests: replace biz_id with user_id + user_type (§9.10)
ALTER TABLE cancellation_requests
  DROP COLUMN IF EXISTS biz_id,
  ADD COLUMN IF NOT EXISTS user_id   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS user_type text CHECK (user_type IN ('business','worker','customer','employer'));

CREATE INDEX IF NOT EXISTS idx_cancel_user ON cancellation_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_cancel_resolved ON cancellation_requests(resolved);

-- Admin RPC: returns cancellation_requests joined with auth.users email
CREATE OR REPLACE FUNCTION get_cancellation_admin_data()
RETURNS TABLE(
  id          uuid,
  user_id     uuid,
  email       text,
  user_type   text,
  reason      text,
  created_at  timestamptz,
  resolved    boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cr.id,
    cr.user_id,
    u.email::text,
    cr.user_type,
    cr.reason,
    cr.created_at,
    cr.resolved
  FROM cancellation_requests cr
  LEFT JOIN auth.users u ON u.id = cr.user_id
  ORDER BY cr.resolved ASC, cr.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION get_cancellation_admin_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_cancellation_admin_data() TO authenticated;
