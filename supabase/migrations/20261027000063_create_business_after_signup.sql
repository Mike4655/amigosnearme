-- signUp() 직후 세션 없이도 businesses 레코드를 생성하는 SECURITY DEFINER 함수
-- 이메일 인증(Confirm email ON) 상태에서 signUp → 인증 전에도 businesses INSERT 가능하도록
-- anon 호출 가능, user_id+email 동시 검증으로 위변조 방지
CREATE OR REPLACE FUNCTION create_business_after_signup(
  p_user_id               uuid,
  p_email                 text,
  p_business_name         text,
  p_is_worker             boolean   DEFAULT false,
  p_plan                  text      DEFAULT 'free',
  p_pending_plan          text      DEFAULT NULL,
  p_whatsapp_phone        text      DEFAULT '',
  p_description           text      DEFAULT '',
  p_description_es        text      DEFAULT '',
  p_description_en        text      DEFAULT '',
  p_preferred_lang        text      DEFAULT 'es',
  p_trade_name            text      DEFAULT '',
  p_business_type         text      DEFAULT NULL,
  p_insured               boolean   DEFAULT false,
  p_categories            jsonb     DEFAULT '[]',
  p_service_area          text      DEFAULT '',
  p_languages             jsonb     DEFAULT '["es"]',
  p_payment_methods       jsonb     DEFAULT '[]',
  p_hours                 jsonb     DEFAULT '[]',
  p_staffing_types        jsonb     DEFAULT '[]',
  p_staffing_availability jsonb     DEFAULT '[]',
  p_staffing_type_other   text      DEFAULT '',
  p_category_other        text      DEFAULT ''
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_verified_id uuid;
  v_biz_id      uuid;
BEGIN
  -- user_id 와 email 이 auth.users 에서 일치하는지 검증 (위변조 방지)
  SELECT id INTO v_verified_id
  FROM auth.users
  WHERE id = p_user_id
    AND lower(email) = lower(p_email);

  IF v_verified_id IS NULL THEN
    RAISE EXCEPTION 'Invalid user_id or email';
  END IF;

  -- 이미 businesses 레코드가 있으면 기존 id 반환 (중복 방지)
  SELECT id INTO v_biz_id
  FROM public.businesses
  WHERE owner_id = p_user_id;

  IF v_biz_id IS NOT NULL THEN
    RETURN v_biz_id;
  END IF;

  -- businesses 레코드 생성
  INSERT INTO public.businesses (
    owner_id, business_name, trade_name,
    plan, pending_plan, public_email,
    whatsapp_phone, description, description_es, description_en,
    preferred_lang, business_type, insured, is_worker,
    categories, service_area, languages, payment_methods, hours,
    staffing_types, staffing_availability,
    staffing_type_other, category_other,
    account_status, contacts_used_month, contacts_month_reset,
    contact_credits
  ) VALUES (
    p_user_id, p_business_name, p_trade_name,
    p_plan, p_pending_plan, p_email,
    p_whatsapp_phone, p_description, p_description_es, p_description_en,
    p_preferred_lang, p_business_type, p_insured, p_is_worker,
    p_categories::text[], p_service_area, p_languages::text[], p_payment_methods::jsonb, p_hours::jsonb,
    p_staffing_types::text[], p_staffing_availability::text[],
    p_staffing_type_other, p_category_other,
    'active', 0, CURRENT_DATE,
    CASE WHEN p_plan = 'free' THEN 3 ELSE 0 END
  )
  RETURNING id INTO v_biz_id;

  RETURN v_biz_id;
END;
$$;

REVOKE ALL ON FUNCTION create_business_after_signup FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_business_after_signup TO anon, authenticated;
