import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import 'screens/driver_login_screen.dart';
import 'screens/driver_shell.dart';

/// App Sopir Ambulans — memakai sistem desain yang sama persis dengan App
/// Pasien, seluruhnya lewat package `mobile_core`. Tidak ada satu pun warna
/// atau widget yang didefinisikan ulang di sini.
class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Sopir Ambulans Bogor',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: buildDispatchTheme(Brightness.light),
      darkTheme: buildDispatchTheme(Brightness.dark),
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return switch (auth) {
      AuthLoading() => const _Splash(),
      // Tidak ada mode tamu di sini: sopir selalu terikat ke satu rumah sakit.
      AuthSignedOut() => const DriverLoginScreen(),
      AuthSignedIn() => const DriverShell(),
    };
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: ConsoleBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReticleBracket(
                size: 110,
                child: Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: DispatchColors.vitalGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.local_shipping_rounded,
                    color: c.onVital,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'MEMUAT KONSOL SOPIR...',
                style: DispatchType.monoStyle(
                  size: 9,
                  weight: 700,
                  tracking: 0.15,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
