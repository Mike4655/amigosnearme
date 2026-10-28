-- Migration 062: 이메일이 이미 활성/정지 계정으로 존재하는지 확인하는 공개 RPC
-- 가입 시 pre-check용 — anon(비로그인) 상태에서도 호출 가능

CREATE OR REPLACE FUNCTION is_email_already_registered(p_email text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM auth.users
    WHERE lower(email) = lower(p_email)
  );
$$;

REVOKE ALL ON FUNCTION is_email_already_registered(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION is_email_already_registered(text) TO anon, authenticated;
