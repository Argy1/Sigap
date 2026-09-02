import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import 'screens/driver_login_screen.dart';
import 'screens/driver_shell.dart';

/// **Sigap Sopir** — memakai sistem desain yang sama persis dengan App
/// Pasien, seluruhnya lewat package `mobile_core`. Tidak ada satu pun warna
/// atau widget yang didefinisikan ulang di sini.
class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Sigap Sopir',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: buildDispatchTheme(Brightness.light),
      darkTheme: buildDispatchTheme(Brightness.dark),
      home: const _AppRoot(),
    );
  }
}

/// Boot intro tampil sekali di awal cold-start, lalu menyingkir ke [_Root]
/// yang sesungguhnya — lihat catatan yang sama di `apps/patient/lib/src/app.dart`.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _introDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_introDone) {
      return BootIntro(
        appName: 'SIGAP SOPIR',
        tagline: 'DISPATCH CONSOLE',
        icon: Icons.local_shipping_rounded,
        bootLines: const [
          'MENGHUBUNGKAN KE RUMAH SAKIT...',
          'MEMERIKSA GPS...',
          'SIAP BERTUGAS',
        ],
        onFinished: () {
          if (mounted) setState(() => _introDone = true);
        },
      );
    }
    return const _Root();
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
