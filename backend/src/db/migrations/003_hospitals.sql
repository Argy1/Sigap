-- ============================================================================
-- 003 — hospitals
--
-- Registrasi mandiri RS bersifat NON-BLOCKING: baris langsung dibuat dengan
-- verification_status = 'unverified'. Admin memverifikasi belakangan; hanya RS
-- 'verified' yang ikut dalam pencarian RS terdekat.
-- ============================================================================

CREATE TABLE hospitals (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                text NOT NULL,
  address             text NOT NULL,
  location            geography(Point, 4326) NOT NULL,
  phone               text,
  verification_status text NOT NULL DEFAULT 'unverified'
                      CHECK (verification_status IN ('unverified', 'verified', 'rejected')),
  verified_at         timestamptz,
  created_by          uuid REFERENCES profiles (id) ON DELETE SET NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

-- Index GiST — inti dari query KNN "ORDER BY location <-> :point".
-- Tanpa ini, pencarian RS terdekat berubah jadi full table scan.
CREATE INDEX hospitals_location_idx ON hospitals USING gist (location);
CREATE INDEX hospitals_verification_idx ON hospitals (verification_status);

CREATE TRIGGER hospitals_set_updated_at
  BEFORE UPDATE ON hospitals
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Staff RS terikat ke satu RS. Kolom ini milik `profiles`, tapi baru bisa
-- ditambahkan setelah tabel hospitals lahir (urutan dependensi FK).
ALTER TABLE profiles
  ADD COLUMN hospital_id uuid REFERENCES hospitals (id) ON DELETE SET NULL;

CREATE INDEX profiles_hospital_idx ON profiles (hospital_id)
  WHERE hospital_id IS NOT NULL;
