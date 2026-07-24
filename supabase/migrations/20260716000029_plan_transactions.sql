-- Migration 029: plan_transactions 테이블 — Business 플랜 결제 히스토리
CREATE TABLE IF NOT EXISTS plan_transactions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  biz_id          uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  plan            text NOT NULL,          -- 'basic' | 'premium'
  amount_usd      numeric(10,2) NOT NULL,
  payment_ref     text,                   -- Braintree transaction ID
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- RLS: authenticated users can read (admin dashboard uses anon key + logged-in session)
-- writes via Edge Function (service role)
ALTER TABLE plan_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_read_plan_transactions"
  ON plan_transactions FOR SELECT
  TO authenticated
  USING (true);
