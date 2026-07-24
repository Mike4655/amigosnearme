ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS staffing_type_other text DEFAULT NULL;
