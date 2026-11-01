-- jobs table
CREATE TABLE IF NOT EXISTS public.jobs (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title         text NOT NULL,
  category      text NOT NULL,
  city          text NOT NULL DEFAULT 'Atlanta',
  pay_range     text,
  work_type     text NOT NULL DEFAULT 'gig',  -- gig | part_time | full_time
  requirements  text,
  description   text,
  status        text NOT NULL DEFAULT 'open', -- open | closed
  posted_by     uuid REFERENCES auth.users(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

-- 공개 읽기 (open 상태만)
CREATE POLICY "jobs_public_read" ON public.jobs
  FOR SELECT USING (status = 'open');

-- Admin 전체 접근 (service role 또는 is_admin 체크)
CREATE POLICY "jobs_admin_all" ON public.jobs
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.businesses
      WHERE businesses.user_id = auth.uid()
      AND businesses.is_admin = true
    )
  );

-- updated_at 자동 갱신
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS jobs_updated_at ON public.jobs;
CREATE TRIGGER jobs_updated_at
  BEFORE UPDATE ON public.jobs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
