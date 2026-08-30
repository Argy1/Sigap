import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

/// **Layar 01 — Masuk Sopir.**
///
/// Tidak ada tautan "daftar" di layar ini, dan itu disengaja: akun sopir dibuat
/// oleh staff rumah sakitnya lewat dashboard web. Sopir yang bisa mendaftar
/// sendiri berarti siapa pun bisa mengaku sebagai sopir ambulans sebuah RS.
class DriverLoginScreen extends ConsumerStatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  ConsumerState<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends ConsumerState<DriverLoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(
            identifier: _identifier.text.trim(),
            password: _password.text,
          );

      // Aplikasi ini khusus sopir. Menolak di sini memberi pesan yang jelas,
      // daripada membiarkan pasien masuk ke layar yang semua endpoint-nya 403.
      final auth = ref.read(authProvider);
      if (auth is AuthSignedIn && auth.user.role != Role.driver) {
        await ref.read(authProvider.notifier).logout();
        setState(() {
          _error =
              'Akun ini bukan akun sopir ambulans. Gunakan aplikasi pasien.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Scaffold(
      body: ConsoleBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: ReticleBracket(
                    size: 104,
                    armLength: 20,
                    child: Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: DispatchColors.vitalGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: c.vital.withValues(alpha: 0.3),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.local_shipping_rounded,
                        color: c.onVital,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Portal Sopir Ambulans',
                  textAlign: TextAlign.center,
                  style: DispatchType.displayStyle(
                    size: 15,
                    weight: 800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Masuk menggunakan akun yang\ndiberikan oleh rumah sakit Anda',
                  textAlign: TextAlign.center,
                  style: DispatchType.bodyStyle(
                    size: 10,
                    weight: 500,
                    color: c.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),

                DispatchTextField(
                  controller: _identifier,
                  hint: 'ID Sopir / No. HP',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 9),
                DispatchTextField(
                  controller: _password,
                  hint: 'Kata Sandi',
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: c.sirenTint,
                      borderRadius: BorderRadius.circular(DispatchRadii.input),
                      border: Border.all(
                        color: DispatchColors.sirenRaw.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: DispatchType.bodyStyle(
                        size: 9.5,
                        weight: 600,
                        color: c.siren,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                DispatchButton(
                  label: 'MASUK',
                  loading: _busy,
                  onPressed: _busy ? null : _submit,
                ),

                const SizedBox(height: 24),
                Text(
                  'AKUN DEMO · 081211110001 · SANDI: password123',
                  textAlign: TextAlign.center,
                  style: DispatchType.monoStyle(
                    size: 7.5,
                    weight: 600,
                    tracking: 0.04,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
