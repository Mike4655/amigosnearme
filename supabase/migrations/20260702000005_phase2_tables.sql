-- =============================================
-- Migration 005: Phase 2 — page_views, customer_profiles,
--                cancellation_requests 스키마 교체
-- =============================================

-- 1. page_views 테이블 (§5.2)
CREATE TABLE IF NOT EXISTS page_views (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  biz_id     uuid        NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  viewer_id  uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  viewed_at  timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_page_views_biz_id    ON page_views(biz_id);
CREATE INDEX IF NOT EXISTS idx_page_views_viewed_at ON page_views(viewed_at);

-- 2. customer_profiles 테이블 (§9.2)
CREATE TABLE IF NOT EXISTS customer_profiles (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id       uuid        NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  account_status text        NOT NULL DEFAULT 'active'
                             CHECK (account_status IN ('active','suspended','deleted')),
  created_at     timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_customer_profiles_owner ON customer_profiles(owner_id);

-- 3. 기존 Customer 마이그레이션 (Phase 1 기간 중 가입한 Customer 보완)
INSERT INTO customer_profiles (owner_id)
SELECT id FROM auth.users
WHERE raw_user_meta_data->>'user_type' = 'customer'
  AND id NOT IN (SELECT owner_id FROM customer_profiles);

-- 4. cancellation_requests 스키마 교체 (biz_id → user_id/user_type)
--    기존 테이블에 신규 컬럼 추가 후 biz_id 제거
ALTER TABLE cancellation_requests
  ADD COLUMN IF NOT EXISTS user_id   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS user_type text CHECK (user_type IN ('business','worker','customer','employer'));

-- biz_id 컬럼 제거 (기존 데이터 없으므로 안전)
ALTER TABLE cancellation_requests DROP COLUMN IF EXISTS biz_id;
