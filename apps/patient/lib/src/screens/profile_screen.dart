import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/patient_providers.dart';
import 'medical_edit_screen.dart';

/// **Layar 06 — Profil / Hub.**
///
/// Mode tamu memakai layar yang sama, tapi isinya berbeda: alih-alih data
/// medis, dia melihat ajakan mendaftar dengan alasan yang konkret — data medis
/// yang tersimpan akan ikut terkirim otomatis ke rumah sakit saat SOS ditekan.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final auth = ref.watch(authProvider);
    final isGuest = auth is! AuthSignedIn;
    final user = auth is AuthSignedIn ? auth.user : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kepala profil
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DispatchSpacing.screenH,
              18,
              DispatchSpacing.screenH,
              0,
            ),
            child: Row(
              children: [
                DispatchAvatar(
                  name: user?.fullName ?? 'Tamu',
                  size: 46,
                  radius: 14,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.fullName ?? 'Mode Tamu',
                        style: DispatchType.displayStyle(
                          size: 13,
                          weight: 700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.phone ?? 'TIDAK MASUK AKUN',
                        style: DispatchType.monoStyle(
                          size: 8.5,
                          weight: 600,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          if (isGuest)
            DispatchPanel(
              margin: const EdgeInsets.symmetric(
                horizontal: DispatchSpacing.screenH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PanelLabel('MODE TAMU AKTIF'),
                  const SizedBox(height: 8),
                  Text(
                    'Anda bisa mengirim SOS tanpa akun. Tapi dengan mendaftar, '
                    'golongan darah dan riwayat alergi Anda ikut terkirim '
                    'otomatis ke rumah sakit — informasi yang bisa menentukan '
                    'tindakan pertama yang diberikan.',
                    style: DispatchType.bodyStyle(
                      size: 10,
                      weight: 500,
                      color: c.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DispatchButton(
                    label: 'DAFTAR / MASUK',
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                  ),
                ],
              ),
            )
          else
            _MedicalSummary(),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              DispatchSpacing.screenH,
              14,
              DispatchSpacing.screenH,
              0,
            ),
            child: const PanelLabel('PENGATURAN'),
          ),

          DispatchPanel(
            margin: const EdgeInsets.fromLTRB(
              DispatchSpacing.screenH,
              8,
              DispatchSpacing.screenH,
              0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              children: [
                _MenuItem(
                  icon: Icons.phone_rounded,
                  tint: c.vitalTint,
                  iconColor: c.vital,
                  label: 'Kontak Darurat',
                  onTap: isGuest
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const MedicalEditScreen(),
                            ),
                          ),
                ),
                _MenuItem(
                  icon: Icons.notifications_rounded,
                  tint: c.amberTint,
                  iconColor: c.amberText,
                  label: 'Notifikasi',
                  trailing: Text(
                    'AKTIF',
                    style: DispatchType.monoStyle(
                      size: 8,
                      weight: 700,
                      color: c.vital,
                    ),
                  ),
                ),
                _ThemeMenuItem(),
              ],
            ),
          ),

          if (!isGuest)
            DispatchPanel(
              margin: const EdgeInsets.fromLTRB(
                DispatchSpacing.screenH,
                10,
                DispatchSpacing.screenH,
                0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: _MenuItem(
                icon: Icons.logout_rounded,
                tint: c.sirenTint,
                iconColor: c.siren,
                label: 'Keluar',
                labelColor: c.siren,
                last: true,
                onTap: () => ref.read(authProvider.notifier).logout(),
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Ringkasan profil medis dengan pintasan ke layar edit.
class _MedicalSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final medical = ref.watch(medicalProfileProvider);

    return DispatchPanel(
      margin: const EdgeInsets.symmetric(horizontal: DispatchSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const PanelLabel('PROFIL MEDIS'),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const MedicalEditScreen(),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'UBAH',
                      style: DispatchType.monoStyle(
                        size: 8.5,
                        weight: 700,
                        color: c.vital,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: c.vital,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          medical.when(
            loading: () => Text(
              'MEMUAT...',
              style: DispatchType.monoStyle(
                size: 8,
                weight: 600,
                color: c.textSecondary,
              ),
            ),
            error: (e, _) => Text(
              'Gagal memuat data medis',
              style: DispatchType.bodyStyle(
                size: 10,
                weight: 500,
                color: c.textSecondary,
              ),
            ),
            data: (m) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MedField(
                    label: 'GOL. DARAH',
                    value: m.bloodType ?? 'Belum diisi',
                    color: m.bloodType == null ? c.textSecondary : c.textPrimary,
                  ),
                ),
                Expanded(
                  child: _MedField(
                    label: 'ALERGI',
                    value: m.allergies.isEmpty
                        ? 'Tidak ada'
                        : m.allergies.join(', '),
                    // Alergi diberi warna merah karena ini informasi yang bisa
                    // membahayakan kalau terlewat oleh tim medis.
                    color: m.allergies.isEmpty ? c.textPrimary : c.siren,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedField extends StatelessWidget {
  const _MedField({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: DispatchType.monoStyle(
            size: 7.5,
            weight: 700,
            tracking: 0.05,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: DispatchType.bodyStyle(size: 11, weight: 800, color: color),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
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
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: c.divider)),
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

/// Baris "Tampilan" dengan toggle gelap/terang.
class _ThemeMenuItem extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return _MenuItem(
      icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
      tint: c.divider,
      iconColor: c.textPrimary,
      label: 'Tampilan',
      last: true,
      onTap: () => ref.read(themeModeProvider.notifier).toggle(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isDark ? 'GELAP' : 'TERANG',
            style: DispatchType.monoStyle(
              size: 8,
              weight: 700,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(width: 9),
          DispatchToggle(
            value: isDark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }
}
