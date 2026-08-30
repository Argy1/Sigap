import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dispatch_colors.dart';
import '../theme/dispatch_typography.dart';
import 'reticle_bracket.dart';

/// **Tombol SOS — elemen paling dominan di seluruh aplikasi.**
///
/// TEKAN & TAHAN, bukan sekali tap. Ini keputusan keselamatan, bukan gaya:
/// satu sentuhan tak sengaja di saku tidak boleh mengerahkan ambulans.
/// Durasi tahan [holdDuration] memberi waktu membatalkan, sementara cincin
/// yang terisi memberi umpan balik bahwa sistem sedang menghitung — bukan
/// membeku.
///
/// Susunan visual dari mockup (dari luar ke dalam):
///   reticle 196 -> glow radial 156 -> ring1 156 -> ring2 132 -> tombol 108
class SosHoldButton extends StatefulWidget {
  const SosHoldButton({
    super.key,
    required this.onTriggered,
    this.holdDuration = const Duration(milliseconds: 1500),
    this.enabled = true,
    this.label = 'SOS',
    this.subLabel = 'TAHAN',
  });

  /// Dipanggil hanya setelah tahan penuh selesai.
  final VoidCallback onTriggered;
  final Duration holdDuration;
  final bool enabled;
  final String label;
  final String subLabel;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton>
    with TickerProviderStateMixin {
  /// Mengisi selama jari ditahan; mundur cepat kalau dilepas lebih awal.
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
    reverseDuration: const Duration(milliseconds: 220),
  );

  /// Denyut cincin luar yang berjalan terus — menandakan sistem siaga.
  late final AnimationController _idlePulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  bool _fired = false;

  /// Timer pendinginan setelah SOS terkirim, agar tombol tidak terpicu dua kali
  /// beruntun. Disimpan sebagai field (bukan Future.delayed lepas) supaya bisa
  /// dibatalkan saat dispose — kalau tidak, timer tetap hidup setelah widget
  /// hilang dan menyentuh state yang sudah dibuang.
  Timer? _cooldown;

  @override
  void initState() {
    super.initState();
    _hold.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_fired) {
        _fired = true;
        HapticFeedback.heavyImpact();
        widget.onTriggered();
        // Reset supaya tombol siap dipakai lagi.
        _hold.reverse();
        _cooldown?.cancel();
        _cooldown = Timer(const Duration(milliseconds: 400), () {
          if (mounted) _fired = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    _hold.dispose();
    _idlePulse.dispose();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled) return;
    HapticFeedback.mediumImpact();
    _hold.forward();
  }

  void _cancel() {
    if (_hold.status == AnimationStatus.forward) {
      HapticFeedback.selectionClick();
      _hold.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_hold, _idlePulse]),
        builder: (context, _) {
          final t = _hold.value;
          final idle = _idlePulse.value;

          return ReticleBracket(
            size: 196,
            // Bracket ikut mengencang saat ditahan — penguatan visual bahwa
            // lokasi sedang "dikunci".
            opacity: 0.5 + t * 0.5,
            child: SizedBox(
              width: 196,
              height: 196,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glow merah — memuncak saat tahan hampir selesai.
                  Container(
                    width: 156 + t * 24,
                    height: 156 + t * 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          DispatchColors.sirenRaw.withValues(
                            alpha: (c.isDark ? 0.32 : 0.22) + t * 0.25,
                          ),
                          DispatchColors.sirenRaw.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.7],
                      ),
                    ),
                  ),

                  // Cincin siaga yang mengembang perlahan saat idle.
                  Opacity(
                    opacity: (1 - idle) * 0.5 * (1 - t),
                    child: Container(
                      width: 132 + idle * 48,
                      height: 132 + idle * 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DispatchColors.sirenRaw.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),

                  // ring1 (156) & ring2 (132) — nilai persis dari mockup.
                  _Ring(
                    size: 156,
                    color: DispatchColors.sirenRaw
                        .withValues(alpha: c.isDark ? 0.28 : 0.30),
                  ),
                  _Ring(
                    size: 132,
                    color: DispatchColors.sirenRaw
                        .withValues(alpha: c.isDark ? 0.40 : 0.42),
                  ),

                  // Cincin progres tahan — inilah yang memberi tahu pengguna
                  // berapa lama lagi.
                  if (t > 0)
                    SizedBox(
                      width: 132,
                      height: 132,
                      child: CircularProgressIndicator(
                        value: t,
                        strokeWidth: 3.5,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation(
                          DispatchColors.sirenRaw,
                        ),
                      ),
                    ),

                  // Tombol inti.
                  Transform.scale(
                    scale: 1 - t * 0.06,
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: DispatchColors.sirenGradient,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: DispatchColors.sirenRaw
                                .withValues(alpha: c.isDark ? 0.5 : 0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.label,
                            style: DispatchType.displayStyle(
                              size: 19,
                              weight: 800,
                              color: Colors.white,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t > 0 ? 'TERUS TAHAN' : widget.subLabel,
                            style: DispatchType.monoStyle(
                              size: 7,
                              weight: 700,
                              color: Colors.white.withValues(alpha: 0.9),
                              tracking: 0.18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color),
        ),
      );
}
