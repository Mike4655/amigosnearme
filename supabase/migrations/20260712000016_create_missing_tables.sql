-- Migration 016: employer_profiles + credit_transactions 실제 생성

CREATE TABLE IF NOT EXISTS public.employer_profiles (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id       uuid        NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  credit_balance integer     NOT NULL DEFAULT 0,
  account_status text        NOT NULL DEFAULT 'active'
                             CHECK (account_status IN ('active','suspended','deleted')),
  preferred_lang text        DEFAULT 'es',
  created_at     timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_employer_profiles_owner ON public.employer_profiles(owner_id);

ALTER TABLE public.employer_profiles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='employer_profiles' AND policyname='ep_own_select') THEN
    CREATE POLICY "ep_own_select" ON public.employer_profiles FOR SELECT USING (owner_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='employer_profiles' AND policyname='ep_own_insert') THEN
    CREATE POLICY "ep_own_insert" ON public.employer_profiles FOR INSERT WITH CHECK (owner_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='employer_profiles' AND policyname='ep_own_update') THEN
    CREATE POLICY "ep_own_update" ON public.employer_profiles FOR UPDATE USING (owner_id = auth.uid());
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.credit_transactions (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  employer_id   uuid        NOT NULL REFERENCES public.employer_profiles(id) ON DELETE CASCADE,
  amount_usd    numeric(10,2) NOT NULL,
  credits_added integer     NOT NULL,
  payment_ref   text,
  created_at    timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_credit_tx_employer ON public.credit_transactions(employer_id);

ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='credit_transactions' AND policyname='tx_own_select') THEN
    CREATE POLICY "tx_own_select" ON public.credit_transactions
      FOR SELECT USING (
        employer_id IN (SELECT id FROM public.employer_profiles WHERE owner_id = auth.uid())
      );
  END IF;
END $$;

-- 기존 employer 유저 일괄 마이그레이션
INSERT INTO public.employer_profiles (owner_id)
SELECT id FROM auth.users
WHERE raw_user_meta_data->>'user_type' = 'employer'
  AND id NOT IN (SELECT owner_id FROM public.employer_profiles)
ON CONFLICT (owner_id) DO NOTHING;
