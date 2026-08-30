import 'package:flutter/material.dart';

/// Palet sistem desain **"Dispatch Console"**.
///
/// Semua nilai disalin langsung dari `/design-reference/patient-app-*.html`
/// dan `/design-reference/driver-app-*.html`. Jangan mengubah angka di sini
/// tanpa memperbarui berkas mockup-nya juga.
///
/// ATURAN YANG TIDAK BOLEH DILANGGAR:
///
/// 1. **Merah (`siren`) HANYA** untuk tombol SOS, pembatalan, dan status
///    darurat/error. Tidak boleh dipakai untuk CTA biasa — kalau merah muncul
///    di mana-mana, ia berhenti berarti "darurat".
///
/// 2. **Hijau mode terang bukan hasil invert.** `#39E991` di-*deepen* jadi
///    `#0F9D6E` karena hijau terang tidak terbaca di atas latar terang.
///    Menyalin mentah nilai mode gelap akan merusak keterbacaan.
@immutable
class DispatchColors extends ThemeExtension<DispatchColors> {
  const DispatchColors({
    required this.ink,
    required this.ink2,
    required this.surface,
    required this.surfaceBorder,
    required this.mapBg,
    required this.vital,
    required this.vitalTint,
    required this.vitalBorder,
    required this.onVital,
    required this.siren,
    required this.sirenTint,
    required this.amber,
    required this.amberText,
    required this.amberTint,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.inputBorder,
    required this.cardShadow,
    required this.isDark,
  });

  /// Latar utama layar.
  final Color ink;

  /// Latar sekunder (peta, panel dalam).
  final Color ink2;

  /// Latar kartu/panel.
  final Color surface;
  final Color surfaceBorder;
  final Color mapBg;

  /// Hijau brand — warna semua aksi positif, bukan sekadar dekorasi.
  final Color vital;
  final Color vitalTint;
  final Color vitalBorder;

  /// Warna teks di ATAS latar hijau.
  final Color onVital;

  /// Merah darurat — lihat aturan di dokumentasi kelas.
  final Color siren;
  final Color sirenTint;

  final Color amber;
  final Color amberText;
  final Color amberTint;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color inputBorder;
  final List<BoxShadow> cardShadow;
  final bool isDark;

  /// Gradien hijau — IDENTIK di kedua mode. Ini warna brand, bukan warna latar.
  static const LinearGradient vitalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF39E991), Color(0xFF0EA972)],
  );

  /// Gradien tombol SOS — juga identik di kedua mode.
  static const RadialGradient sirenGradient = RadialGradient(
    center: Alignment(-0.36, -0.44), // 32% 28% dari mockup
    radius: 0.95,
    colors: [Color(0xFFFF6B85), Color(0xFFFF3355), Color(0xFFC81E44)],
    stops: [0.0, 0.45, 1.0],
  );

  /// Merah mentah — untuk gradien & glow yang sama di kedua mode.
  static const Color sirenRaw = Color(0xFFFF3355);

  /// Aksen ungu Panel Admin (dipakai dashboard web; disimpan di sini agar
  /// definisi palet tetap satu sumber).
  static const Color admin = Color(0xFF9333EA);

  // ---------------------------------------------------------------------
  // MODE GELAP — dasar & signature sistem desain ini.
  // ---------------------------------------------------------------------
  static const DispatchColors dark = DispatchColors(
    ink: Color(0xFF0A0E14),
    ink2: Color(0xFF0D131E),
    surface: Color(0x0AFFFFFF), // rgba(255,255,255,0.04)
    surfaceBorder: Color(0x14FFFFFF), // rgba(255,255,255,0.08)
    mapBg: Color(0xFF0D131E),
    vital: Color(0xFF39E991),
    vitalTint: Color(0x1F39E991), // 0.12
    vitalBorder: Color(0x3339E991), // 0.20
    onVital: Color(0xFF04140C),
    siren: Color(0xFFFF3355),
    sirenTint: Color(0x1FFF3355),
    amber: Color(0xFFFFB020),
    amberText: Color(0xFFFFB020),
    amberTint: Color(0x1FFFB020),
    textPrimary: Color(0xFFF4F6F8),
    textSecondary: Color(0x66F4F6F8), // 0.40
    textTertiary: Color(0x52F4F6F8), // 0.32
    divider: Color(0x0FFFFFFF), // 0.06
    inputBorder: Color(0x1AFFFFFF), // 0.10
    cardShadow: <BoxShadow>[],
    isDark: true,
  );

  // ---------------------------------------------------------------------
  // MODE TERANG — nilai di-deepen, bukan di-invert.
  // ---------------------------------------------------------------------
  static const DispatchColors light = DispatchColors(
    ink: Color(0xFFF2F5F3),
    ink2: Color(0xFFE4EDE9),
    surface: Color(0xFFFFFFFF), // solid, bukan overlay transparan
    surfaceBorder: Color(0x120A140F), // rgba(10,20,15,0.07)
    mapBg: Color(0xFFE4EDE9),
    vital: Color(0xFF0F9D6E), // di-deepen dari #39E991
    vitalTint: Color(0x1A0F9D6E), // 0.10
    vitalBorder: Color(0x380F9D6E), // 0.22
    onVital: Color(0xFF04140C),
    siren: Color(0xFFE11D48), // versi lebih gelap untuk teks
    sirenTint: Color(0x1AFF3355),
    amber: Color(0xFFFFB020),
    amberText: Color(0xFFB45309),
    amberTint: Color(0x26FFB020), // 0.15
    textPrimary: Color(0xFF0A0E14),
    textSecondary: Color(0x730A0E14), // 0.45
    textTertiary: Color(0x590A0E14), // 0.35
    divider: Color(0x0F0A140F),
    inputBorder: Color(0x1F0A140F), // 0.12
    cardShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x0A0A140F),
        blurRadius: 14,
        offset: Offset(0, 4),
      ),
    ],
    isDark: false,
  );

  @override
  DispatchColors copyWith({
    Color? ink,
    Color? ink2,
    Color? surface,
    Color? surfaceBorder,
    Color? mapBg,
    Color? vital,
    Color? vitalTint,
    Color? vitalBorder,
    Color? onVital,
    Color? siren,
    Color? sirenTint,
    Color? amber,
    Color? amberText,
    Color? amberTint,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? divider,
    Color? inputBorder,
    List<BoxShadow>? cardShadow,
    bool? isDark,
  }) {
    return DispatchColors(
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      surface: surface ?? this.surface,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      mapBg: mapBg ?? this.mapBg,
      vital: vital ?? this.vital,
      vitalTint: vitalTint ?? this.vitalTint,
      vitalBorder: vitalBorder ?? this.vitalBorder,
      onVital: onVital ?? this.onVital,
      siren: siren ?? this.siren,
      sirenTint: sirenTint ?? this.sirenTint,
      amber: amber ?? this.amber,
      amberText: amberText ?? this.amberText,
      amberTint: amberTint ?? this.amberTint,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      divider: divider ?? this.divider,
      inputBorder: inputBorder ?? this.inputBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  DispatchColors lerp(ThemeExtension<DispatchColors>? other, double t) {
    if (other is! DispatchColors) return this;
    return DispatchColors(
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      mapBg: Color.lerp(mapBg, other.mapBg, t)!,
      vital: Color.lerp(vital, other.vital, t)!,
      vitalTint: Color.lerp(vitalTint, other.vitalTint, t)!,
      vitalBorder: Color.lerp(vitalBorder, other.vitalBorder, t)!,
      onVital: Color.lerp(onVital, other.onVital, t)!,
      siren: Color.lerp(siren, other.siren, t)!,
      sirenTint: Color.lerp(sirenTint, other.sirenTint, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberText: Color.lerp(amberText, other.amberText, t)!,
      amberTint: Color.lerp(amberTint, other.amberTint, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Akses cepat palet dari BuildContext mana pun.
extension DispatchColorsX on BuildContext {
  DispatchColors get c => Theme.of(this).extension<DispatchColors>()!;
}
