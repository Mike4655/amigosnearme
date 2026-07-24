-- Migration 031: 업체주가 자신의 업체에 달린 리뷰를 flag할 수 있도록 허용
DROP POLICY IF EXISTS "reviews_flag_by_owner" ON public.reviews;
CREATE POLICY "reviews_flag_by_owner" ON public.reviews
  FOR UPDATE TO authenticated
  USING (
    biz_id IN (
      SELECT id FROM businesses WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    biz_id IN (
      SELECT id FROM businesses WHERE owner_id = auth.uid()
    )
  );
