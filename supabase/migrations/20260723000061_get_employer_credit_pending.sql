-- Migration 061: Admin용 employer credit pending 조회 RPC
-- (employer_profiles에 RLS가 있어 admin이 직접 SELECT 불가 → SECURITY DEFINER RPC로 우회)

DROP FUNCTION IF EXISTS public.get_employer_credit_pending();
CREATE OR REPLACE FUNCTION public.get_employer_credit_pending()
RETURNS TABLE (
  id                    uuid,
  owner_id              uuid,
  display_name          text,
  pending_credits       integer,
  pending_package_id    text,
  pending_payment_method text,
  pending_submitted_at  timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- admin 전용: collegeessayboard@gmail.com
  IF (SELECT email FROM auth.users WHERE id = auth.uid()) != 'collegeessayboard@gmail.com' THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  RETURN QUERY
  SELECT
    ep.id,
    ep.owner_id,
    ep.display_name,
    ep.pending_credits,
    ep.pending_package_id,
    ep.pending_payment_method,
    ep.pending_submitted_at
  FROM public.employer_profiles ep
  WHERE ep.pending_credits IS NOT NULL
  ORDER BY ep.pending_submitted_at DESC NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_employer_credit_pending() TO authenticated;
