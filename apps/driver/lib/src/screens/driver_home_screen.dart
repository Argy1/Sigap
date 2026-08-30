import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/driver_providers.dart';

/// **Layar 02 — Beranda / Menunggu Tugas.**
///
/// Toggle Tersedia/Tidak Tersedia adalah elemen utama layar ini. Statusnya
/// menentukan apakah sopir ini ikut muncul di daftar saran RS — jadi harus
/// terlihat jelas dan tidak bisa salah baca.
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _updating = false;

  Future<void> _toggle(bool available) async {
    setState(() => _updating = true);
    try {
      await ref.read(apiClientProvider).setAvailability(
            available
                ? AvailabilityStatus.available
                : AvailabilityStatus.offline,
          );
      ref.invalidate(driverProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final auth = ref.watch(authProvider);
    final profile = ref.watch(driverProfileProvider);
    final connected = ref.watch(socketConnectedProvider).value ?? false;
    final user = auth is AuthSignedIn ? auth.user : null;

    final status = profile.value?.availabilityStatus;
    final isAvailable = status == AvailabilityStatus.available;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kepala: identitas sopir
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
                size: 40,
                radius: 12,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SOPIR AMBULANS',
                      style: DispatchType.monoStyle(
                        size: 8,
                        weight: 600,
                        tracking: 0.06,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      user?.fullName ?? '—',
                      style: DispatchType.bodyStyle(
                        size: 12.5,
                        weight: 700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      [
                        user?.hospitalName?.toUpperCase(),
                        profile.value?.vehiclePlate,
                      ].whereType<String>().join(' · '),
                      style: DispatchType.monoStyle(
                        size: 7.5,
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

        // Panel status — elemen utama layar ini
        DispatchPanel(
          margin: const EdgeInsets.fromLTRB(
            DispatchSpacing.screenH,
            14,
            DispatchSpacing.screenH,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Status: ${status?.label ?? '—'}',
                      style: DispatchType.bodyStyle(
                        size: 11,
                        weight: 700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      switch (status) {
                        AvailabilityStatus.available => 'SIAP MENERIMA TUGAS',
                        AvailabilityStatus.busy => 'SEDANG MENANGANI PANGGILAN',
                        _ => 'TIDAK AKAN MENERIMA TUGAS',
                      },
                      style: DispatchType.monoStyle(
                        size: 8,
                        weight: 600,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_updating)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(c.vital),
                  ),
                )
              else
                DispatchToggle(
                  value: isAvailable,
                  // Status `busy` dikendalikan sistem, bukan sopir — saat
                  // sedang bertugas toggle dinonaktifkan.
                  onChanged: status == AvailabilityStatus.busy ? null : _toggle,
                ),
            ],
          ),
        ),

        // Keadaan menunggu
        if (isAvailable)
          const DispatchEmptyState(
            title: 'Menunggu Tugas...',
            description:
                'Anda akan mendapat notifikasi\nbegitu ada panggilan darurat masuk',
            icon: Icons.schedule_rounded,
            showLiveDot: true,
          )
        else
          const DispatchEmptyState(
            title: 'Anda Sedang Tidak Aktif',
            description:
                'Aktifkan status di atas agar bisa\nmenerima panggilan darurat',
            icon: Icons.nightlight_round,
          ),

        // Indikator koneksi realtime — sopir perlu tahu kalau dia terputus,
        // karena saat terputus tugas baru tidak akan sampai.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DispatchSpacing.screenH,
            0,
            DispatchSpacing.screenH,
            8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? c.vital : c.siren,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                connected ? 'TERHUBUNG REALTIME' : 'TERPUTUS — MENYAMBUNG ULANG',
                style: DispatchType.monoStyle(
                  size: 7.5,
                  weight: 700,
                  tracking: 0.08,
                  color: connected ? c.textSecondary : c.siren,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
