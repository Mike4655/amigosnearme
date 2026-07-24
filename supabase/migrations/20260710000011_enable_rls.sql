-- =============================================
-- Migration 011: Enable RLS on tables flagged by Security Advisor
-- Tables: contact_log, reviews, staffing_contact_log,
--         cancellation_requests, email_log
-- =============================================

-- ── Admin 판별 헬퍼 ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(
    (auth.jwt() -> 'user_metadata' ->> 'is_admin')::boolean,
    false
  );
$$;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ── 1. contact_log ────────────────────────────────────────────────
ALTER TABLE public.contact_log ENABLE ROW LEVEL SECURITY;

-- 관리자: 전체 접근 (loadAnalytics 카운트, processCancellation 등)
CREATE POLICY "contact_log_admin_all" ON public.contact_log
  FOR ALL TO authenticated
  USING (is_admin());

-- 연락한 사람 (actor): 자신이 보낸 기록 조회
CREATE POLICY "contact_log_actor_select" ON public.contact_log
  FOR SELECT TO authenticated
  USING (actor_id = auth.uid());

-- 업체 오너: 자기 업체로 들어온 연락 조회 (dashboard.html loadRecentInquiries)
CREATE POLICY "contact_log_biz_owner_select" ON public.contact_log
  FOR SELECT TO authenticated
  USING (biz_id IN (
    SELECT id FROM businesses WHERE owner_id = auth.uid()
  ));

-- Employer가 Worker 연락 기록 조회 (employer-dashboard.html Activity 탭)
CREATE POLICY "contact_log_employer_select" ON public.contact_log
  FOR SELECT TO authenticated
  USING (actor_id = auth.uid());

-- 연락 기록 삽입 (actor_id = 본인)
CREATE POLICY "contact_log_insert" ON public.contact_log
  FOR INSERT TO authenticated
  WITH CHECK (actor_id = auth.uid());

-- ── 2. reviews ────────────────────────────────────────────────────
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- 누구나 리뷰 열람 (profile.html, search.html)
CREATE POLICY "reviews_public_select" ON public.reviews
  FOR SELECT
  USING (true);

-- 본인 리뷰 삽입
CREATE POLICY "reviews_insert" ON public.reviews
  FOR INSERT TO authenticated
  WITH CHECK (reviewer_id = auth.uid());

-- 관리자: 플래그 처리 등 전체 접근
CREATE POLICY "reviews_admin_all" ON public.reviews
  FOR ALL TO authenticated
  USING (is_admin());

-- ── 3. staffing_contact_log ───────────────────────────────────────
-- 현재 앱 코드에서 사용하지 않는 레거시 테이블
-- service_role(Edge Functions)만 접근 가능하도록 정책 없이 RLS 활성화
ALTER TABLE public.staffing_contact_log ENABLE ROW LEVEL SECURITY;

-- ── 4. cancellation_requests ──────────────────────────────────────
ALTER TABLE public.cancellation_requests ENABLE ROW LEVEL SECURITY;

-- 관리자: 전체 접근 (loadCancellations, processCancellation UPDATE)
CREATE POLICY "cancel_admin_all" ON public.cancellation_requests
  FOR ALL TO authenticated
  USING (is_admin());

-- 본인 탈퇴 신청 조회
CREATE POLICY "cancel_own_select" ON public.cancellation_requests
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- 탈퇴 신청 삽입 (user_id = 본인)
CREATE POLICY "cancel_insert" ON public.cancellation_requests
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- ── 5. email_log ──────────────────────────────────────────────────
-- Edge Function(service_role)만 사용 — 클라이언트 접근 불필요
-- 정책 없이 RLS 활성화 → service_role은 RLS 우회, anon/authenticated 차단
ALTER TABLE public.email_log ENABLE ROW LEVEL SECURITY;
