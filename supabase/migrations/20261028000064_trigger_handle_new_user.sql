-- auth.users에 신규 사용자 INSERT 시 자동으로 businesses 레코드 생성
-- worker / business 타입만 생성 — employer / customer는 생성하지 않음
-- worker의 경우 is_worker=true로 생성 → auto-confirm-worker가 정상 동작
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_type     text;
  v_is_worker     boolean;
  v_business_name text;
  v_plan          text;
  v_email         text;
BEGIN
  v_email     := NEW.email;
  v_user_type := COALESCE(NEW.raw_user_meta_data->>'user_type', 'business');

  -- employer / customer는 businesses 레코드 불필요
  IF v_user_type IN ('employer', 'customer') THEN
    RETURN NEW;
  END IF;

  v_is_worker     := (v_user_type = 'worker');
  v_business_name := COALESCE(NULLIF(NEW.raw_user_meta_data->>'business_name', ''), v_email);
  v_plan          := COALESCE(NULLIF(NEW.raw_user_meta_data->>'plan', ''), 'free');

  INSERT INTO public.businesses (
    owner_id, business_name, public_email, is_worker,
    plan, account_status, preferred_lang,
    whatsapp_phone, description, description_es, description_en,
    contacts_used_month, contacts_month_reset, contact_credits
  ) VALUES (
    NEW.id,
    v_business_name,
    v_email,
    v_is_worker,
    v_plan,
    'active',
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'preferred_lang', ''), 'es'),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'description', ''),
    COALESCE(NEW.raw_user_meta_data->>'description', ''),
    '',
    0,
    CURRENT_DATE,
    CASE WHEN v_plan = 'free' THEN 3 ELSE 0 END
  )
  ON CONFLICT (owner_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
