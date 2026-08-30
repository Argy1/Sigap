import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/patient_providers.dart';
import 'active_call_screen.dart';
import 'history_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'sos_home_screen.dart';

/// Kerangka App Pasien: 4 tab (Beranda, Peta, Riwayat, Profil).
///
/// Satu perilaku penting: kalau ada panggilan darurat yang sedang berjalan,
/// layar pelacakan MENGGANTIKAN seluruh shell — termasuk bilah navigasinya.
/// Saat ambulans sedang menuju, tidak ada apa pun di aplikasi ini yang lebih
/// penting untuk dilihat, dan membiarkan pengguna tersesat ke tab lain di saat
/// panik adalah kegagalan desain.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    // Pulihkan panggilan yang mungkin masih berjalan dari sesi sebelumnya.
    Future.microtask(
      () => ref.read(activeCallProvider.notifier).restoreActive(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCall = ref.watch(activeCallProvider);
    final tab = ref.watch(patientTabProvider);
    final isGuest =
        ref.watch(authProvider) is AuthSignedOut; // mode tamu

    if (activeCall != null && activeCall.status.isActive) {
      return const ActiveCallScreen();
    }

    // Mode tamu hanya punya dua tab yang berarti — Riwayat & Profil butuh akun.
    final destinations = isGuest
        ? const [
            NavDestination(icon: Icons.home_rounded, label: 'Beranda'),
            NavDestination(icon: Icons.place_rounded, label: 'Peta'),
            NavDestination(icon: Icons.person_rounded, label: 'Akun'),
          ]
        : const [
            NavDestination(icon: Icons.home_rounded, label: 'Beranda'),
            NavDestination(icon: Icons.place_rounded, label: 'Peta'),
            NavDestination(icon: Icons.schedule_rounded, label: 'Riwayat'),
            NavDestination(icon: Icons.favorite_rounded, label: 'Profil'),
          ];

    final safeTab = tab.clamp(0, destinations.length - 1);

    final screens = isGuest
        ? const [SosHomeScreen(), MapScreen(), ProfileScreen()]
        : const [
            SosHomeScreen(),
            MapScreen(),
            HistoryScreen(),
            ProfileScreen(),
          ];

    return Scaffold(
      body: ConsoleBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: screens[safeTab]),
              DispatchNavBar(
                currentIndex: safeTab,
                destinations: destinations,
                onTap: (i) => ref.read(patientTabProvider.notifier).set(i),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
