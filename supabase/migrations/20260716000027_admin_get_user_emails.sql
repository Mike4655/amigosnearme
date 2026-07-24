-- Migration 027: admin용 auth.users 이메일 조회 RPC
CREATE OR REPLACE FUNCTION public.admin_get_user_emails(p_user_ids uuid[])
RETURNS TABLE(user_id uuid, email text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = auth, public
AS $$
  SELECT id::uuid, email FROM auth.users WHERE id = ANY(p_user_ids);
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_user_emails(uuid[]) TO authenticated;
