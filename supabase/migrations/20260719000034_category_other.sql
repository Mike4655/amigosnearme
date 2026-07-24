ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS category_other text DEFAULT NULL;
