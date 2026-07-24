-- Migration 037: Admin data RPCs (SECURITY DEFINER — RLS 우회)
-- 이메일 기반 admin 인증은 JWT에 is_admin 클레임이 없으므로
-- RLS 정책 대신 SECURITY DEFINER 함수로 관리자 데이터 조회

-- ── 1. get_customer_admin_data 재정의 ────────────────────────────────
-- auth.users를 primary로 두고 customer_profiles를 LEFT JOIN
-- customer_profiles 행이 없어도 모든 customer 유저 반환
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
  ORDER BY u.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION get_customer_admin_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_customer_admin_data() TO authenticated;

-- ── 2. get_employer_admin_data 신규 생성 ─────────────────────────────
-- employer_profiles RLS(owner-only)를 우회하여 전체 목록 반환
-- credits_purchased: credit_transactions.credits_added 합산
CREATE OR REPLACE FUNCTION get_employer_admin_data()
RETURNS TABLE(
  id               uuid,
  owner_id         uuid,
  email            text,
  phone            text,
  display_name     text,
  credit_balance   int,
  account_status   text,
  created_at       timestamptz,
  credits_purchased int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ep.id,
    ep.owner_id,
    u.email::text,
    ep.phone,
    ep.display_name,
    ep.credit_balance,
    ep.account_status,
    ep.created_at,
    COALESCE((
      SELECT SUM(ct.credits_added)::int
      FROM public.credit_transactions ct
      WHERE ct.employer_id = ep.id
    ), 0) AS credits_purchased
  FROM public.employer_profiles ep
  JOIN auth.users u ON u.id = ep.owner_id
  ORDER BY ep.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION get_employer_admin_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_employer_admin_data() TO authenticated;

-- ── 3. get_employer_credit_transactions 신규 생성 ─────────────────────
-- Billing 탭 employer 크레딧 거래 내역 (credit_transactions RLS 우회)
CREATE OR REPLACE FUNCTION get_employer_credit_transactions()
RETURNS TABLE(
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
