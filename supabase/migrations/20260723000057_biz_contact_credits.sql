-- Migration 057: Business contact credits system
-- Adds contact_credits column and RPCs for credit-based contact system

-- 1. Add contact_credits column (default 0)
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS contact_credits integer NOT NULL DEFAULT 0;

-- 2. Add pending_ach to plan check constraint
ALTER TABLE public.businesses
  DROP CONSTRAINT IF EXISTS businesses_plan_check;

ALTER TABLE public.businesses
  ADD CONSTRAINT businesses_plan_check CHECK (
    plan IN ('free','basic','premium','pending_zelle','pending_ach')
  );

-- 3. decrement_biz_credit — called when a customer contacts a business
DROP FUNCTION IF EXISTS decrement_biz_credit(uuid);
CREATE OR REPLACE FUNCTION decrement_biz_credit(p_biz_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  UPDATE public.businesses
  SET contact_credits = GREATEST(0, contact_credits - 1)
  WHERE id = p_biz_id;
END;
$$;

-- Allow anon/authenticated to call decrement (customers are often anon)
GRANT EXECUTE ON FUNCTION decrement_biz_credit(uuid) TO anon, authenticated;

-- 4. confirm_biz_credit_purchase — Admin confirms Zelle/ACH payment → adds credits + sets plan
CREATE OR REPLACE FUNCTION confirm_biz_credit_purchase(p_biz_id uuid, p_method text DEFAULT 'zelle')
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_pending_plan text;
  v_credits      integer;
  v_expected_plan text;
BEGIN
  IF auth.email() != 'collegeessayboard@gmail.com' THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;

  v_expected_plan := CASE p_method WHEN 'ach' THEN 'pending_ach' ELSE 'pending_zelle' END;

  SELECT pending_plan INTO v_pending_plan
  FROM public.businesses
  WHERE id = p_biz_id AND plan = v_expected_plan;

  IF v_pending_plan IS NULL THEN
    RAISE EXCEPTION 'No pending % payment found for this business', p_method;
  END IF;

  v_credits := CASE v_pending_plan WHEN 'premium' THEN 50 ELSE 20 END;

  UPDATE public.businesses
  SET plan          = v_pending_plan,
      pending_plan  = NULL,
      contact_credits = contact_credits + v_credits
  WHERE id = p_biz_id;

  RETURN v_pending_plan;
END;
$$;

GRANT EXECUTE ON FUNCTION confirm_biz_credit_purchase(uuid, text) TO authenticated;
