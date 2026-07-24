-- Add preferred_lang to businesses table for Business Owner and Worker email language preference
ALTER TABLE businesses
  ADD COLUMN IF NOT EXISTS preferred_lang text NOT NULL DEFAULT 'es' CHECK (preferred_lang IN ('en', 'es'));
