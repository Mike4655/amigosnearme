-- Migration 021: business photos column + Storage bucket + RLS policies

-- 1. photos 컬럼 추가 (text[] — Supabase Storage public URL 배열)
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS photos text[] DEFAULT '{}';

-- 2. Storage bucket 생성 (public — profile.html에서 인증 없이 이미지 표시)
INSERT INTO storage.buckets (id, name, public)
VALUES ('business-photos', 'business-photos', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Storage RLS 정책 (DROP IF EXISTS로 중복 방지)
DROP POLICY IF EXISTS "business_photos_insert" ON storage.objects;
DROP POLICY IF EXISTS "business_photos_update" ON storage.objects;
DROP POLICY IF EXISTS "business_photos_delete" ON storage.objects;
DROP POLICY IF EXISTS "business_photos_select" ON storage.objects;

-- 3-1. 업로드: 본인 business 소유자만 가능
CREATE POLICY "business_photos_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'business-photos'
  AND (storage.foldername(name))[1] IN (
    SELECT id::text FROM businesses WHERE owner_id = auth.uid()
  )
);

-- 3-2. 업데이트/삭제: 본인 소유자만 가능
CREATE POLICY "business_photos_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'business-photos'
  AND (storage.foldername(name))[1] IN (
    SELECT id::text FROM businesses WHERE owner_id = auth.uid()
  )
);

CREATE POLICY "business_photos_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'business-photos'
  AND (storage.foldername(name))[1] IN (
    SELECT id::text FROM businesses WHERE owner_id = auth.uid()
  )
);

-- 3-3. 조회: 전체 공개 (public bucket이므로 anon도 가능)
CREATE POLICY "business_photos_select"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'business-photos');
