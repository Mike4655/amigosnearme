-- Migration 039: customer_profiles backfill + credit REF 생성
-- NOTE: customer_profiles.id = auth.users.id (owner reference, not a separate UUID)
--       owner_id 컬럼은 이미 이전 실행에서 ALTER TABLE로 추가됨

-- ── 1. customer_profiles backfill ────────────────────────────────────
-- id 컬럼 = 유저 UUID (FK to auth.users.id)
-- businesses/employer_profiles에 없는 유저 = customer로 등록
-- collegeessayboard@gmail.com (admin) 제외
INSERT INTO public.customer_profiles (id)
SELECT u.id
FROM auth.users u
WHERE u.email != 'collegeessayboard@gmail.com'
  AND NOT EXISTS (SELECT 1 FROM public.businesses b        WHERE b.owner_id = u.id)
  AND NOT EXISTS (SELECT 1 FROM public.employer_profiles ep WHERE ep.owner_id = u.id)
  AND NOT EXISTS (SELECT 1 FROM public.customer_profiles cp WHERE cp.id = u.id)
ON CONFLICT DO NOTHING;

-- ── 2. get_customer_admin_data RPC — id 기준 조인으로 재정의 ──────────
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
    u.id                                          AS id,
    u.id                                          AS owner_id,
    u.email::text                                 AS email,
    COALESCE(cp.account_status, 'active'::text)   AS account_status,
    COALESCE(cp.created_at, u.created_at)         AS created_at
  FROM auth.users u
  LEFT JOIN public.customer_profiles cp ON cp.id = u.id
  WHERE u.email != 'collegeessayboard@gmail.com'
    AND NOT EXISTS (SELECT 1 FROM public.businesses b        WHERE b.owner_id = u.id)
    AND NOT EXISTS (SELECT 1 FROM public.employer_profiles ep WHERE ep.owner_id = u.id)
  ORDER BY u.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION get_customer_admin_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_customer_admin_data() TO authenticated;

-- ── 3. credit_transactions: payment_ref 자동 생성 (NULL인 기존 거래) ──
UPDATE public.credit_transactions
SET payment_ref = 'cr-' || LEFT(id::text, 8)
WHERE payment_ref IS NULL;

-- ── 4. get_employer_credit_transactions RPC — transaction id 포함 ────
DROP FUNCTION IF EXISTS get_employer_credit_transactions();
CREATE OR REPLACE FUNCTION get_employer_credit_transactions()
RETURNS TABLE(
  tx_id        uuid,
  employer_id  uuid,
  email        text,
  display_name text,
  credits_added integer,
  amount_usd   numeric,
  payment_ref  text,
  created_at   timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ct.id,
    ct.employer_id,
    u.email::text,
    ep.display_name,
    ct.credits_added,
    ct.amount_usd,
    ct.payment_ref,
    ct.created_at
  FROM public.credit_transactions ct
  JOIN public.employer_profiles ep ON ep.id = ct.employer_id
  JOIN auth.users u ON u.id = ep.owner_id
  ORDER BY ct.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION get_employer_credit_transactions() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_employer_credit_transactions() TO authenticated;
