-- Migration 019: increment_contact_count — anon 허용 복원
-- 이유: profile.html은 비로그인 고객도 WhatsApp/Form 연락 가능.
--       Migration 012에서 추가된 auth 체크로 인해 비로그인 고객의 contact가
--       카운트되지 않아 비즈니스 plan 한도 로직이 무의미해지는 버그 수정.
--       보안 대신 정확한 카운팅을 우선시 (plan 한도가 비즈니스 수익 모델의 핵심).

CREATE OR REPLACE FUNCTION public.increment_contact_count(p_biz_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.businesses
  SET contacts_used_month = contacts_used_month + 1
  WHERE id = p_biz_id;
END;
$$;

-- anon + authenticated 모두 허용 (비로그인 고객 카운팅 포함)
REVOKE ALL  ON FUNCTION public.increment_contact_count(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_contact_count(uuid) TO anon, authenticated;
