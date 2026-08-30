-- ============================================================================
-- 001 — Ekstensi
-- PostGIS wajib: seluruh kolom lokasi memakai tipe geography(Point,4326),
-- bukan sepasang kolom lat/lng terpisah.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid()

-- Fungsi bantu: menjaga kolom updated_at selalu akurat tanpa perlu diingat
-- di setiap query UPDATE.
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $fn$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;
