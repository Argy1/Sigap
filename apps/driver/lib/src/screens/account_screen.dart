import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/driver_providers.dart';

/// **Layar Akun sopir.**
///
/// Tab ini ada di bilah navigasi mockup, tapi layarnya sendiri tidak digambar.
/// Isinya dibuat seperlunya dan tetap konsisten dengan sistem desain:
/// identitas, penugasan RS, dan pengaturan dasar.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final auth = ref.watch(authProvider);
    final profile = ref.watch(driverProfileProvider);
    final user = auth is AuthSignedIn ? auth.user : null;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final status = profile.value?.availabilityStatus;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  name: user?.fullName ?? '?',
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
                        user?.fullName ?? 'Sopir',
                        style: DispatchType.displayStyle(
                          size: 13,
                          weight: 700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.phone ?? 'Nomor tidak tercatat',
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

          DispatchPanel(
            margin: const EdgeInsets.fromLTRB(
              DispatchSpacing.screenH,
              14,
              DispatchSpacing.screenH,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PanelLabel('PENUGASAN'),
                const SizedBox(height: 9),
                _Field(
                  label: 'RUMAH SAKIT',
                  value: user?.hospitalName ?? 'Belum tertaut',
                ),
                const SizedBox(height: 9),
                _Field(
                  label: 'PLAT KENDARAAN',
                  value: profile.value?.vehiclePlate ?? 'Belum diisi',
                ),
                const SizedBox(height: 9),
                _Field(
                  label: 'STATUS SAAT INI',
                  value: status?.label ?? 'Memuat...',
                  valueColor:
                      status == AvailabilityStatus.available ? c.vital : null,
                ),
              ],
            ),
          ),

          DispatchPanel(
            margin: const EdgeInsets.fromLTRB(
              DispatchSpacing.screenH,
              10,
              DispatchSpacing.screenH,
              0,
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.divider,
                    borderRadius: BorderRadius.circular(DispatchRadii.icon),
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    size: 14,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    isDark ? 'Tampilan Gelap' : 'Tampilan Terang',
                    style: DispatchType.bodyStyle(
                      size: 10.5,
                      weight: 700,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                DispatchToggle(
                  value: isDark,
                  onChanged: (_) =>
                      ref.read(themeModeProvider.notifier).toggle(),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              DispatchSpacing.screenH,
              14,
              DispatchSpacing.screenH,
              20,
            ),
            child: DispatchDangerButton(
              label: 'KELUAR',
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
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
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: DispatchType.bodyStyle(
              size: 10.5,
              weight: 700,
              color: valueColor ?? c.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
