-- Migration 048: customer_profiles에 account_status 컬럼 추가 + 상태 변경 RPC

ALTER TABLE public.customer_profiles
  ADD COLUMN IF NOT EXISTS account_status text NOT NULL DEFAULT 'active'
    CHECK (account_status IN ('active','suspended','deleted'));

-- 기존 get_customer_admin_data를 account_status 실제 컬럼 값으로 업데이트
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
      u.raw_user_meta_data->>'display_name',
      u.raw_user_meta_data->>'full_name',
      u.raw_user_meta_data->>'name',
      ''
    )::text       AS full_name,
    COALESCE(cp.account_status, 'active')::text AS account_status,
    u.created_at  AS created_at
  FROM auth.users u
  LEFT JOIN public.customer_profiles cp ON cp.id = u.id
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

-- Admin 전용 Customer 상태 변경 RPC
CREATE OR REPLACE FUNCTION set_customer_account_status(
  p_customer_id uuid,
  p_status      text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF auth.email() != 'collegeessayboard@gmail.com' THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;
  IF p_status NOT IN ('active','suspended','deleted') THEN
    RAISE EXCEPTION 'Invalid status';
  END IF;

  -- customer_profiles row가 없으면 생성 후 업데이트
  INSERT INTO public.customer_profiles (id, account_status)
  VALUES (p_customer_id, p_status)
  ON CONFLICT (id) DO UPDATE SET account_status = EXCLUDED.account_status;
END;
$$;

REVOKE ALL ON FUNCTION set_customer_account_status(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION set_customer_account_status(uuid, text) TO authenticated;
