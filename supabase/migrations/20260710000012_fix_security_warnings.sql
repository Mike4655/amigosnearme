-- =============================================
-- Migration 012: Fix Security Advisor Warnings
-- 1. Function Search Path Mutable (update_updated_at, increment_contact_count)
-- 2. Public/Authenticated SECURITY DEFINER 권한 제한
-- =============================================

-- ── 1. update_updated_at — search_path 고정 ───────────────────────
-- Supabase가 생성한 표준 updated_at 트리거 함수
-- RETURNS trigger이므로 EXECUTE 권한 문제는 없음, search_path만 수정
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ── 2. increment_contact_count — 재정의 (search_path + 권한 제한) ──
-- search_path 고정 + anon 제거 + 내부 auth 체크 추가
CREATE OR REPLACE FUNCTION public.increment_contact_count(p_biz_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- 비로그인 호출 차단 (Warning #4 해소: 내부 auth 체크)
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.businesses
  SET contacts_used_month = contacts_used_month + 1
  WHERE id = p_biz_id;
END;
$$;

-- anon 권한 제거 (Warning #3 해소: Public Can Execute 제거)
REVOKE ALL ON FUNCTION public.increment_contact_count(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.increment_contact_count(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.increment_contact_count(uuid) TO authenticated;

-- ── NOTE: Warning #5 — Leaked Password Protection ─────────────────
-- SQL로 설정 불가. Supabase Dashboard에서 수동 활성화 필요:
-- Authentication → Providers → Email → "Leaked Password Protection" 토글 ON
-- ──────────────────────────────────────────────────────────────────
