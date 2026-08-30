-- ============================================================================
-- 002 — profiles + refresh_tokens + patient_profiles
--
-- `profiles` adalah tabel identitas tunggal untuk keempat role. Karena auth
-- dibangun manual (bukan BaaS), kredensial ikut tinggal di sini sebagai KOLOM
-- tambahan — bukan sebagai tabel `users` terpisah, supaya jumlah tabel domain
-- tetap 5 sesuai spesifikasi di CLAUDE.md.
--
-- Identitas login:
--   - patient / driver        -> `phone` (mockup: "081234567890", "ID Sopir / No. HP")
--   - hospital_staff / admin  -> `email`
-- Endpoint login menerima `identifier` dan mencocokkan ke salah satunya.
-- ============================================================================

CREATE TABLE profiles (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role          text NOT NULL
                CHECK (role IN ('patient', 'hospital_staff', 'driver', 'admin')),
  full_name     text NOT NULL,
  phone         text UNIQUE,
  email         text UNIQUE,
  password_hash text NOT NULL,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),

  -- Setiap profil harus punya minimal satu cara login.
  CONSTRAINT profiles_identifier_present CHECK (phone IS NOT NULL OR email IS NOT NULL)
);

CREATE INDEX profiles_role_idx ON profiles (role);

CREATE TRIGGER profiles_set_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- refresh_tokens — tabel INFRASTRUKTUR, bukan tabel domain.
--
-- Token disimpan sebagai hash (bukan token mentah) supaya bocornya database
-- tidak otomatis berarti bocornya seluruh sesi. Menyimpan baris memungkinkan
-- rotasi + revoke per-perangkat, yang mustahil kalau refresh token stateless.
-- ---------------------------------------------------------------------------
CREATE TABLE refresh_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id  uuid NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
  token_hash  text NOT NULL UNIQUE,
  user_agent  text,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX refresh_tokens_profile_idx ON refresh_tokens (profile_id)
  WHERE revoked_at IS NULL;

-- ---------------------------------------------------------------------------
-- patient_profiles — data medis, sengaja dipisah dari `profiles`.
-- profile_id sekaligus PRIMARY KEY: relasi 1:1, tidak mungkin ganda.
-- ---------------------------------------------------------------------------
CREATE TABLE patient_profiles (
  profile_id              uuid PRIMARY KEY REFERENCES profiles (id) ON DELETE CASCADE,
  blood_type              text CHECK (blood_type IN
                            ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  -- Mockup layar 07 menampilkan alergi sebagai chip GANDA -> array adalah
  -- model yang benar, bukan satu string dengan pemisah koma.
  allergies               text[] NOT NULL DEFAULT ARRAY[]::text[],
  medical_history         text,
  emergency_contact_name  text,
  emergency_contact_phone text,
  updated_at              timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER patient_profiles_set_updated_at
  BEFORE UPDATE ON patient_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
