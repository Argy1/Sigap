import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';

/// **Sigap** — App Pasien.
///
/// Mode GELAP adalah default. Bukan mengikuti setelan sistem: sistem desain ini
/// dirancang gelap sebagai dasar, dan layar darurat yang menyala terang di
/// tengah malam justru menyilaukan saat paling tidak dibutuhkan.
class PatientApp extends ConsumerWidget {
  const PatientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Sigap',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: buildDispatchTheme(Brightness.light),
      darkTheme: buildDispatchTheme(Brightness.dark),
      home: const _AppRoot(),
    );
  }
}

/// Boot intro tampil sekali di awal cold-start, lalu menyingkir ke [_Root]
/// yang sesungguhnya. Dipisah dari pengecekan auth di bawahnya supaya intro
/// selalu tampil utuh (durasi tetap, bisa di-skip) tanpa peduli auth restore
/// di baliknya sudah selesai atau belum.
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
        appName: 'SIGAP',
        tagline: 'DISPATCH CONSOLE',
        icon: Icons.favorite_rounded,
        bootLines: const [
          'MENGINISIALISASI SISTEM SIGAP...',
          'MEMERIKSA LAYANAN LOKASI...',
          'SIAP MELAYANI DARURAT',
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
      // Mode tamu masuk ke shell yang sama — SOS harus bisa ditekan tanpa akun.
      AuthSignedOut(asGuest: true) => const HomeShell(),
      AuthSignedOut() => const AuthScreen(),
      AuthSignedIn() => const HomeShell(),
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
                    Icons.favorite_rounded,
                    color: c.onVital,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'MEMUAT KONSOL...',
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
