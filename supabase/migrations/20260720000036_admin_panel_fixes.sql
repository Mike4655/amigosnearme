-- Migration 036: Admin panel fixes
-- 1. employer_profiles: admin SELECT policy 추가
-- 2. credit_transactions: admin SELECT policy 추가
-- 3. get_customer_admin_data: auto-backfill + 모든 customer 반환

-- ── 1. employer_profiles admin policy ───────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='employer_profiles' AND policyname='ep_admin_all'
  ) THEN
    CREATE POLICY "ep_admin_all" ON public.employer_profiles
      FOR ALL TO authenticated
      USING (
        coalesce((auth.jwt() -> 'user_metadata' ->> 'is_admin')::boolean, false)
      );
  END IF;
END $$;

-- ── 2. credit_transactions admin policy ─────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='credit_transactions' AND policyname='tx_admin_select'
  ) THEN
    CREATE POLICY "tx_admin_select" ON public.credit_transactions
      FOR SELECT TO authenticated
      USING (
        coalesce((auth.jwt() -> 'user_metadata' ->> 'is_admin')::boolean, false)
      );
  END IF;
END $$;

-- ── 3. get_customer_admin_data: auto-backfill customer_profiles ──────
-- migration 005 이후 가입한 customer는 customer_profiles 행이 없으므로
-- 함수 호출 시 자동 생성 후 반환
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
SET search_path = ''
AS $$
BEGIN
  -- 누락된 customer_profiles 행 자동 생성
  INSERT INTO public.customer_profiles (owner_id)
  SELECT u.id
  FROM auth.users u
  WHERE u.raw_user_meta_data->>'user_type' = 'customer'
    AND NOT EXISTS (
      SELECT 1 FROM public.customer_profiles cp WHERE cp.owner_id = u.id
    )
  ON CONFLICT (owner_id) DO NOTHING;

  RETURN QUERY
  SELECT
    cp.id,
    cp.owner_id,
    u.email::text,
    cp.account_status,
    cp.created_at
  FROM public.customer_profiles cp
  JOIN auth.users u ON u.id = cp.owner_id
  ORDER BY cp.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION get_customer_admin_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_customer_admin_data() TO authenticated;
