-- ============================================================================
-- 005 — emergency_calls (jantung sistem)
-- ============================================================================

-- Kode panggilan yang terbaca manusia ("SOS #A102") — muncul di 3 layar mockup,
-- jadi ini data yang benar-benar dipakai, bukan dekorasi.
CREATE SEQUENCE emergency_call_code_seq START 101;

CREATE TABLE emergency_calls (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  call_code         text NOT NULL UNIQUE
                    DEFAULT ('A' || lpad(nextval('emergency_call_code_seq')::text, 3, '0')),

  -- NULL = mode tamu (SOS tanpa login). Ini disengaja dan wajib didukung.
  patient_id        uuid REFERENCES profiles (id) ON DELETE SET NULL,
  hospital_id       uuid REFERENCES hospitals (id) ON DELETE SET NULL,
  driver_id         uuid REFERENCES drivers (id) ON DELETE SET NULL,

  -- Snapshot lokasi SAAT kejadian — bukan alamat rumah pasien.
  patient_location  geography(Point, 4326) NOT NULL,
  patient_address   text,                       -- hasil reverse geocoding

  -- Mode tamu tidak punya profil, tapi RS tetap butuh nama & nomor untuk
  -- dihubungi balik. Tanpa dua kolom ini, kartu SOS di dashboard kosong.
  guest_name        text,
  guest_phone       text,

  -- Kondisi medis yang dilihat responder pada saat itu. Di-snapshot (bukan
  -- di-join) supaya (a) mode tamu tetap bisa mengisinya dan (b) riwayat tidak
  -- ikut berubah kalau pasien mengedit profil medisnya kemudian.
  medical_snapshot  jsonb,

  status            text NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','confirmed','en_route','arrived','completed','cancelled')),
  condition_note    text,
  cancel_reason     text,

  created_at        timestamptz NOT NULL DEFAULT now(),
  confirmed_at      timestamptz,
  en_route_at       timestamptz,
  arrived_at        timestamptz,
  completed_at      timestamptz,
  cancelled_at      timestamptz,
  updated_at        timestamptz NOT NULL DEFAULT now(),

  -- Setiap panggilan harus bisa dihubungi balik: lewat profil pasien, atau
  -- lewat nomor tamu.
  CONSTRAINT emergency_calls_contactable
    CHECK (patient_id IS NOT NULL OR guest_phone IS NOT NULL)
);

CREATE INDEX emergency_calls_location_idx ON emergency_calls USING gist (patient_location);
-- Dashboard RS: "panggilan aktif di RS saya".
CREATE INDEX emergency_calls_hospital_status_idx ON emergency_calls (hospital_id, status);
-- Layar Riwayat pasien.
CREATE INDEX emergency_calls_patient_idx ON emergency_calls (patient_id, created_at DESC);
-- Layar Riwayat sopir.
CREATE INDEX emergency_calls_driver_idx ON emergency_calls (driver_id, created_at DESC);

CREATE TRIGGER emergency_calls_set_updated_at
  BEFORE UPDATE ON emergency_calls
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
