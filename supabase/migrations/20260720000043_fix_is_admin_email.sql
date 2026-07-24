-- Migration 043: is_admin() 이메일 기반으로 수정
-- 기존: JWT user_metadata.is_admin 클레임 체크 → admin 로그인 시 항상 false
-- 변경: auth.email() 직접 비교 → 이메일 기반 admin 인증과 일치

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT auth.email() = 'collegeessayboard@gmail.com';
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
