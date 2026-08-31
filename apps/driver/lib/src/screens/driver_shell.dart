import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/driver_providers.dart';
import 'account_screen.dart';
import 'active_task_screen.dart';
import 'driver_history_screen.dart';
import 'driver_home_screen.dart';
import 'incoming_task_screen.dart';

/// Kerangka App Sopir: 3 tab (Beranda, Riwayat, Akun).
///
/// Tugas aktif MENGGANTIKAN seluruh shell, sama seperti di App Pasien. Sopir
/// yang sedang mengemudi tidak boleh perlu mencari-cari tab yang benar.
class DriverShell extends ConsumerWidget {
  const DriverShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignment = ref.watch(currentAssignmentProvider);
    final tab = ref.watch(driverTabProvider);

    // Menyalakan penyiaran lokasi selama ada tugas aktif. Cukup di-`watch`
    // di sini — providernya sendiri yang menyalakan & mematikan stream GPS.
    ref.watch(locationBroadcastProvider);

    if (assignment != null) {
      // Baru ditugaskan (belum diterima) -> layar keputusan Terima/Tolak.
      if (assignment.status == CallStatus.confirmed) {
        return const IncomingTaskScreen();
      }
      // Sudah berjalan -> layar navigasi aktif.
      if (assignment.status.isActive) {
        return const ActiveTaskScreen();
      }
    }

    const screens = [
      DriverHomeScreen(),
      DriverHistoryScreen(),
      AccountScreen(),
    ];

    return Scaffold(
      body: ConsoleBackground(
        // SafeArea default (bottom: true) sengaja dipakai: Android 15+ (target
        // SDK 36 di sini) memaksa edge-to-edge dan tidak bisa di-opt-out. Kalau
        // bottom di-set false, DispatchNavBar dirender sampai ke bawah gestur
        // sistem dan tombolnya tidak bisa disentuh. ConsoleBackground tetap
        // membungkus di luar SafeArea, jadi gradiennya tetap full-bleed —
        // yang ter-inset cuma isi Column ini (termasuk nav bar).
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: screens[tab.clamp(0, screens.length - 1)]),
              DispatchNavBar(
                currentIndex: tab.clamp(0, screens.length - 1),
                destinations: const [
                  NavDestination(icon: Icons.home_rounded, label: 'Beranda'),
                  NavDestination(
                    icon: Icons.schedule_rounded,
                    label: 'Riwayat',
                  ),
                  NavDestination(icon: Icons.person_rounded, label: 'Akun'),
                ],
                onTap: (i) => ref.read(driverTabProvider.notifier).set(i),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
