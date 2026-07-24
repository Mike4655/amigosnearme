-- Migration 050: 이메일이 삭제된 business 계정인지 확인하는 공개 RPC

CREATE OR REPLACE FUNCTION is_deleted_business_email(p_email text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM auth.users u
    JOIN public.businesses b ON b.owner_id = u.id
    WHERE lower(u.email) = lower(p_email)
      AND b.account_status = 'deleted'
  );
$$;

REVOKE ALL ON FUNCTION is_deleted_business_email(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION is_deleted_business_email(text) TO anon, authenticated;
