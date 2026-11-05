-- Employer self-service job posting support
ALTER TABLE jobs
  ADD COLUMN IF NOT EXISTS posted_by_employer boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS employer_biz_id    uuid REFERENCES employer_profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS contact_phone      text,
  ADD COLUMN IF NOT EXISTS contact_whatsapp   text,
  ADD COLUMN IF NOT EXISTS contact_email      text,
  ADD COLUMN IF NOT EXISTS title_es           text,
  ADD COLUMN IF NOT EXISTS description_en     text,
  ADD COLUMN IF NOT EXISTS description_es     text,
  ADD COLUMN IF NOT EXISTS state              text;

-- Employers can insert their own jobs
CREATE POLICY "Employers can insert own jobs" ON jobs
  FOR INSERT TO authenticated
  WITH CHECK (
    posted_by_employer = true
    AND employer_biz_id IN (
      SELECT id FROM businesses WHERE owner_id = auth.uid() AND is_worker = false
    )
  );

-- Employers can update/delete their own jobs
CREATE POLICY "Employers can update own jobs" ON jobs
  FOR UPDATE TO authenticated
  USING (
    employer_biz_id IN (
      SELECT id FROM businesses WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY "Employers can delete own jobs" ON jobs
  FOR DELETE TO authenticated
  USING (
    employer_biz_id IN (
      SELECT id FROM businesses WHERE owner_id = auth.uid()
    )
  );
