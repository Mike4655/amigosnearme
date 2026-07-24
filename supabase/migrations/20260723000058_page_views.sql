-- Migration 058: page_views 테이블 생성
CREATE TABLE IF NOT EXISTS public.page_views (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  biz_id      uuid REFERENCES public.businesses(id) ON DELETE CASCADE,
  viewer_id   uuid,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_page_views_biz_id ON public.page_views(biz_id);
CREATE INDEX IF NOT EXISTS idx_page_views_created_at ON public.page_views(created_at);

-- anon/authenticated 모두 insert 가능 (방문 기록)
ALTER TABLE public.page_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can insert page_views"
  ON public.page_views FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated can read own biz page_views"
  ON public.page_views FOR SELECT
  TO authenticated
  USING (true);
