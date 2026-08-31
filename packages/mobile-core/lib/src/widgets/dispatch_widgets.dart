import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/dispatch_colors.dart';
import '../theme/dispatch_theme.dart';
import '../theme/dispatch_typography.dart';
import '../utils/format.dart';

/// Kumpulan widget sistem desain "Dispatch Console" untuk kedua aplikasi.
/// Semua nilai (radius, padding, ukuran font) disalin dari mockup.

// ---------------------------------------------------------------------------
// Panel & kartu
// ---------------------------------------------------------------------------

/// Panel dasar: latar surface + border tipis + radius 15.
class DispatchPanel extends StatelessWidget {
  const DispatchPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(15, 13, 15, 13),
    this.margin,
    this.radius = DispatchRadii.panel,
    this.borderColor,
    this.background,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? borderColor;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.surfaceBorder),
        boxShadow: c.cardShadow,
      ),
      child: child,
    );
  }
}

/// Label mono huruf kapital — "suara" khas readout konsol.
class PanelLabel extends StatelessWidget {
  const PanelLabel(this.text, {super.key, this.color, this.size = 8});

  final String text;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: DispatchType.monoStyle(
          size: size,
          weight: 700,
          tracking: 0.06,
          color: color ?? context.c.textSecondary,
        ),
      );
}

// ---------------------------------------------------------------------------
// ELEMEN TANDA TANGAN #3 — readout mono
// ---------------------------------------------------------------------------

/// Kartu kecil: label mono di atas, angka besar mono di bawah.
/// Dipakai untuk SEMUA angka penting — ETA, jarak, koordinat.
class ReadoutCard extends StatelessWidget {
  const ReadoutCard({
    super.key,
    required this.label,
    required this.value,
    this.valueSize = 12,
    this.tone = ReadoutTone.vital,
    this.flex = 1,
  });

  final String label;
  final String value;
  final double valueSize;
  final ReadoutTone tone;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = switch (tone) {
      ReadoutTone.vital => c.vital,
      ReadoutTone.siren => c.siren,
      ReadoutTone.amber => c.amberText,
      ReadoutTone.plain => c.textPrimary,
    };

    return DispatchPanel(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      radius: DispatchRadii.input,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: DispatchType.monoStyle(
              size: 7.5,
              weight: 700,
              tracking: 0.08,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: DispatchType.monoStyle(
              size: valueSize,
              weight: 700,
              color: color,
              tracking: 0.02,
            ),
          ),
        ],
      ),
    );
  }
}

enum ReadoutTone { vital, siren, amber, plain }

/// Baris readout — dipakai berpasangan di mockup (mis. RS TERDEKAT + EST. RESPON).
class ReadoutRow extends StatelessWidget {
  const ReadoutRow({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: DispatchSpacing.screenH),
        // IntrinsicHeight wajib: CrossAxisAlignment.stretch butuh tinggi yang
        // terbatas, sedangkan baris ini dipakai di dalam SingleChildScrollView
        // (layar SOS Aktif) yang tingginya tak terbatas. Tanpa ini, layar
        // paling penting di aplikasi justru yang crash.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                Expanded(
                  flex: children[i] is ReadoutCard
                      ? (children[i] as ReadoutCard).flex
                      : 1,
                  child: children[i],
                ),
                if (i != children.length - 1) const SizedBox(width: 9),
              ],
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Tombol
// ---------------------------------------------------------------------------

/// Tombol utama — gradien hijau. Hijau adalah warna SEMUA aksi positif di
/// sistem ini ("Terima Tugas", "Verifikasi", "Simpan"), bukan dekorasi.
class DispatchButton extends StatelessWidget {
  const DispatchButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onPressed != null && !loading;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(DispatchRadii.button),
          child: Ink(
            decoration: BoxDecoration(
              gradient: DispatchColors.vitalGradient,
              borderRadius: BorderRadius.circular(DispatchRadii.button),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: c.vital.withValues(alpha: 0.28),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              child: loading
                  ? SizedBox(
                      height: 15,
                      width: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(c.onVital),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 15, color: c.onVital),
                          const SizedBox(width: 7),
                        ],
                        Text(
                          label.toUpperCase(),
                          style: DispatchType.displayStyle(
                            size: 11,
                            weight: 700,
                            color: c.onVital,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol garis netral.
class DispatchOutlineButton extends StatelessWidget {
  const DispatchOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(DispatchRadii.button),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(DispatchRadii.button),
        child: Container(
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DispatchRadii.button),
            border: Border.all(color: c.inputBorder, width: 1.5),
          ),
          child: Text(
            label,
            style: DispatchType.bodyStyle(
              size: 10.5,
              weight: 700,
              color: c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol garis MERAH — hanya untuk membatalkan / tindakan darurat.
class DispatchDangerButton extends StatelessWidget {
  const DispatchDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.isDark ? Colors.transparent : c.surface,
      borderRadius: BorderRadius.circular(DispatchRadii.button),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(DispatchRadii.button),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DispatchRadii.button),
            border: Border.all(
              color: DispatchColors.sirenRaw.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: DispatchType.bodyStyle(
              size: 10.5,
              weight: 700,
              color: c.siren,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input
// ---------------------------------------------------------------------------

class DispatchTextField extends StatelessWidget {
  const DispatchTextField({
    super.key,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLines: obscure ? 1 : maxLines,
      minLines: minLines,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      cursorColor: c.vital,
      style: DispatchType.bodyStyle(
        size: 11.5,
        weight: 500,
        color: c.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: DispatchType.bodyStyle(
          size: 11.5,
          weight: 500,
          color: c.textTertiary,
        ),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DispatchRadii.input),
          borderSide: BorderSide(color: c.inputBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DispatchRadii.input),
          borderSide: BorderSide(color: c.inputBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DispatchRadii.input),
          borderSide: BorderSide(color: c.vital, width: 1.5),
        ),
      ),
    );
  }
}

/// Label form mono di atas input.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.topGap = 12});

  final String text;
  final double topGap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: topGap, bottom: 7),
        child: PanelLabel(text),
      );
}

/// Chip pilihan — dipakai untuk golongan darah & alergi di Profil Medis.
class DispatchChip extends StatelessWidget {
  const DispatchChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.dashed = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? DispatchColors.vitalGradient : null,
          color: selected ? null : c.surface,
          borderRadius: BorderRadius.circular(DispatchRadii.chip),
          border: Border.all(
            color: selected ? Colors.transparent : c.inputBorder,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: DispatchType.monoStyle(
            size: 9,
            weight: 700,
            color: selected ? c.onVital : c.textSecondary,
            tracking: 0.02,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.long = false});

  final CallStatus status;
  final bool long;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (status) {
      CallStatus.pending => (c.amberTint, c.amberText),
      CallStatus.cancelled => (c.sirenTint, c.siren),
      _ => (c.vitalTint, c.vital),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DispatchRadii.statusChip),
      ),
      child: Text(
        (long ? status.label : status.shortLabel).toUpperCase(),
        style: DispatchType.monoStyle(
          size: 7.5,
          weight: 700,
          color: fg,
          tracking: 0.04,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header & identitas
// ---------------------------------------------------------------------------

/// Baris merek dengan titik hijau berdenyut — indikator "sistem aktif".
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.label = 'Sistem Aktif',
    this.connected = true,
    this.trailing,
  });

  final String label;
  final bool connected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DispatchSpacing.screenH,
        16,
        DispatchSpacing.screenH,
        0,
      ),
      child: Row(
        children: [
          _LiveDot(active: connected),
          const SizedBox(width: 7),
          Text(
            (connected ? label : 'Menyambung Ulang...').toUpperCase(),
            style: DispatchType.monoStyle(
              size: 8.5,
              weight: 700,
              tracking: 0.1,
              color: c.textSecondary,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.active});

  final bool active;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = widget.active ? c.vital : c.textTertiary;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(
            alpha: widget.active ? 0.4 + _ctrl.value * 0.6 : 1,
          ),
          boxShadow: widget.active
              ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
              : null,
        ),
      ),
    );
  }
}

/// Avatar inisial.
class DispatchAvatar extends StatelessWidget {
  const DispatchAvatar({
    super.key,
    required this.name,
    this.size = 32,
    this.radius = DispatchRadii.avatar,
  });

  final String name;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF141C29) : c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: c.isDark
              ? Colors.white.withValues(alpha: 0.1)
              : c.vital.withValues(alpha: 0.3),
          width: c.isDark ? 1 : 1.5,
        ),
      ),
      child: Text(
        initials(name),
        style: DispatchType.displayStyle(
          size: size * 0.31,
          weight: 700,
          color: c.vital,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// Kepala halaman: tombol kembali (opsional) + judul + sub-judul mono.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.subtitleColor,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Color? subtitleColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DispatchSpacing.screenH,
        16,
        DispatchSpacing.screenH,
        4,
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(DispatchRadii.icon),
                  border: Border.all(color: c.inputBorder),
                  boxShadow: c.cardShadow,
                ),
                child: Icon(Icons.chevron_left, size: 18, color: c.textPrimary),
              ),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: DispatchType.displayStyle(
                    size: 14,
                    weight: 700,
                    color: c.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!.toUpperCase(),
                    style: DispatchType.monoStyle(
                      size: 8,
                      weight: 600,
                      tracking: 0.04,
                      color: subtitleColor ?? c.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Keadaan kosong dengan ikon dalam kotak bulat.
class DispatchEmptyState extends StatelessWidget {
  const DispatchEmptyState({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.showLiveDot = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool showLiveDot;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLiveDot) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.vital,
                    boxShadow: [
                      BoxShadow(
                        color: c.vital.withValues(alpha: 0.18),
                        blurRadius: 0,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.isDark ? c.vital.withValues(alpha: 0.08) : c.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.vitalBorder),
                  boxShadow: c.cardShadow,
                ),
                child: Icon(icon, size: 26, color: c.vital),
              ),
              const SizedBox(height: 14),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: DispatchType.displayStyle(
                  size: 12.5,
                  weight: 700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: DispatchType.bodyStyle(
                  size: 9.5,
                  weight: 500,
                  color: c.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toggle Tersedia/Tidak Tersedia — elemen utama Beranda App Sopir.
class DispatchToggle extends StatelessWidget {
  const DispatchToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 25,
        decoration: BoxDecoration(
          gradient: value ? DispatchColors.vitalGradient : null,
          color: value ? null : c.inputBorder,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value
                  ? c.onVital
                  : (c.isDark ? const Color(0xFF5A6472) : const Color(0xFF8A9088)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu baris menu dengan ikon berlatar bulat, label, dan slot `trailing`
/// opsional (mis. status "AKTIF" atau chevron). Dipakai di layar
/// Profil (App Pasien) dan Akun (App Sopir) — dipromosikan ke sini dari
/// widget privat App Pasien supaya kedua app memakai komponen yang sama
/// persis, bukan menduplikasi ~60 baris kode per app.
class DispatchMenuItem extends StatelessWidget {
  const DispatchMenuItem({
    super.key,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.label,
    this.onTap,
    this.trailing,
    this.labelColor,
    this.last = false,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? labelColor;

  /// True kalau ini item terakhir dalam grup — menghilangkan garis pembatas
  /// bawah supaya tidak dobel dengan tepi panel yang membungkusnya.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: DispatchType.bodyStyle(
                  size: 10.5,
                  weight: 700,
                  color: labelColor ?? c.textPrimary,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Kotak peringatan medis merah — dipakai di layar Tugas Masuk App Sopir.
class MedicalAlert extends StatelessWidget {
  const MedicalAlert({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.sirenTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: DispatchColors.sirenRaw.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        text,
        style: DispatchType.monoStyle(
          size: 8.5,
          weight: 700,
          color: c.siren,
          tracking: 0.02,
        ),
      ),
    );
  }
}
