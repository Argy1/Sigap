import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

/// **Layar 01 — Masuk & Registrasi.**
///
/// Catatan tentang kotak "MODE TAMU" di bawah: itu bukan pelengkap, itu inti
/// produk. Orang yang panik tidak akan mendaftar dulu. Karena itu jalur tamu
/// diberi tempat yang menonjol dan berwarna amber — terlihat, tapi tidak
/// mencuri dominasi dari alur normal.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  bool _isRegister = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider.notifier);
      if (_isRegister) {
        await auth.register(
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
        );
      } else {
        await auth.login(
          identifier: _phone.text.trim(),
          password: _password.text,
        );
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
                const SizedBox(height: 24),

                // Logo dikelilingi reticle — elemen tanda tangan yang sama
                // dengan yang mengelilingi tombol SOS.
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
                        Icons.favorite_rounded,
                        color: c.onVital,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  _isRegister ? 'Buat Akun Baru' : 'Selamat Datang',
                  textAlign: TextAlign.center,
                  style: DispatchType.displayStyle(
                    size: 16,
                    weight: 800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _isRegister
                      ? 'Daftar agar data medis Anda tersimpan\ndan langsung terkirim saat darurat'
                      : 'Masuk untuk mengakses layanan\npanggilan darurat ambulans',
                  textAlign: TextAlign.center,
                  style: DispatchType.bodyStyle(
                    size: 10,
                    weight: 500,
                    color: c.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),

                if (_isRegister) ...[
                  DispatchTextField(
                    controller: _name,
                    hint: 'Nama lengkap',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 9),
                ],

                DispatchTextField(
                  controller: _phone,
                  hint: '081234567890',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                ),
                const SizedBox(height: 9),
                DispatchTextField(
                  controller: _password,
                  hint: 'Kata sandi',
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  autofillHints: const [AutofillHints.password],
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
                  label: _isRegister ? 'DAFTAR' : 'LANJUTKAN',
                  loading: _busy,
                  onPressed: _busy ? null : _submit,
                ),

                // Pemisah "ATAU"
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: c.inputBorder, height: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'ATAU',
                          style: DispatchType.monoStyle(
                            size: 8,
                            weight: 700,
                            tracking: 0.06,
                            color: c.textTertiary,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: c.inputBorder, height: 1)),
                    ],
                  ),
                ),

                GestureDetector(
                  onTap: () => setState(() {
                    _isRegister = !_isRegister;
                    _error = null;
                  }),
                  child: Text(
                    _isRegister
                        ? 'Sudah punya akun? Masuk di sini'
                        : 'Daftar sebagai pengguna baru',
                    textAlign: TextAlign.center,
                    style: DispatchType.bodyStyle(
                      size: 10.5,
                      weight: 700,
                      color: c.vital,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // MODE TAMU — jalur tanpa akun.
                GestureDetector(
                  onTap: () => ref.read(authProvider.notifier).continueAsGuest(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: c.amberTint,
                      borderRadius: BorderRadius.circular(DispatchRadii.input),
                      border: Border.all(
                        color: c.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: '⚡ DARURAT SEKARANG? '),
                              const TextSpan(
                                text: 'Lewati langkah ini & gunakan ',
                              ),
                              TextSpan(
                                text: 'MODE TAMU',
                                style: DispatchType.bodyStyle(
                                  size: 9,
                                  weight: 800,
                                  color: c.amberText,
                                ),
                              ),
                              const TextSpan(
                                text: ' untuk kirim SOS langsung.',
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: DispatchType.bodyStyle(
                            size: 9,
                            weight: 600,
                            color: c.amberText,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'MASUK MODE TAMU',
                              style: DispatchType.monoStyle(
                                size: 9,
                                weight: 700,
                                tracking: 0.08,
                                color: c.amberText,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 15,
                              color: c.amberText,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Akun demo — supaya penguji bisa langsung mencoba.
                Text(
                  'AKUN DEMO · 081234567890 · SANDI: password123',
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
