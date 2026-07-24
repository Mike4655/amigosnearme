-- Migration 056: businesses_plan_check 에 'pending_zelle' 추가
ALTER TABLE public.businesses DROP CONSTRAINT IF EXISTS businesses_plan_check;
ALTER TABLE public.businesses ADD CONSTRAINT businesses_plan_check
  CHECK (plan IN ('free', 'basic', 'premium', 'pending_zelle'));
