-- area_requests: Worker가 "Other Area" 수기 입력 시 관리자 검토용 기록 테이블
CREATE TABLE IF NOT EXISTS public.area_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requested_area text NOT NULL,
  business_id   uuid REFERENCES public.businesses(id) ON DELETE SET NULL,
  owner_email   text,
  status        text NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_note    text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  reviewed_at   timestamptz
);

-- 관리자만 읽기/쓰기 (service_role key), anon/authenticated는 INSERT만 허용
ALTER TABLE public.area_requests ENABLE ROW LEVEL SECURITY;

-- Worker 본인이 제출 시 INSERT 가능
CREATE POLICY "area_requests_insert" ON public.area_requests
  FOR INSERT TO authenticated WITH CHECK (true);

-- 본인 레코드 조회 가능
CREATE POLICY "area_requests_select_own" ON public.area_requests
  FOR SELECT TO authenticated
  USING (owner_email = auth.jwt() ->> 'email');
