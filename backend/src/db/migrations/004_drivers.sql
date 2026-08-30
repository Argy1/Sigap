-- ============================================================================
-- 004 — drivers
-- Sopir terikat ke satu RS. Satu profil = maksimal satu baris driver.
-- ============================================================================

CREATE TABLE drivers (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id           uuid NOT NULL UNIQUE REFERENCES profiles (id) ON DELETE CASCADE,
  hospital_id          uuid NOT NULL REFERENCES hospitals (id) ON DELETE CASCADE,
  availability_status  text NOT NULL DEFAULT 'offline'
                       CHECK (availability_status IN ('available', 'busy', 'offline')),
  current_location     geography(Point, 4326),
  -- Tanpa timestamp ini, posisi sopir yang basi tidak bisa dibedakan dari yang
  -- segar — fatal untuk query "sopir terdekat yang tersedia".
  location_updated_at  timestamptz,
  vehicle_plate        text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX drivers_location_idx ON drivers USING gist (current_location);
-- Query "sopir terdekat" selalu memfilter kedua kolom ini lebih dulu.
CREATE INDEX drivers_hospital_availability_idx
  ON drivers (hospital_id, availability_status);

CREATE TRIGGER drivers_set_updated_at
  BEFORE UPDATE ON drivers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
