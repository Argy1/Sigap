import 'package:flutter/material.dart';

import '../theme/dispatch_colors.dart';
import '../theme/dispatch_typography.dart';
import 'dispatch_nav_bar.dart' show ConsoleBackground;
import 'reticle_bracket.dart';

/// **Layar boot — intro sebelum konten utama app.**
///
/// Bukan splash generik (logo diam lalu hilang): ini simulasi "konsol
/// dispatch menyala", memakai elemen tanda tangan yang sama seperti dua
/// layar lain — [ReticleBracket] mengunci ke tengah, lalu garis EKG (motif
/// yang sama seperti `PulseStepper`) menggambar dirinya sendiri, seakan
/// tanda vital baru menyala.
///
/// Satu [AnimationController] menggerakkan seluruh tahapan lewat [Interval]
/// supaya semuanya selalu presisi sinkron — pola yang sama seperti
/// `SosHoldButton`. Bisa di-skip kapan saja dengan tap/klik: ini aplikasi
/// darurat, animasi tidak boleh menahan orang yang buru-buru.
class BootIntro extends StatefulWidget {
  const BootIntro({
    super.key,
    required this.appName,
    required this.tagline,
    required this.bootLines,
    required this.icon,
    required this.onFinished,
    this.duration = const Duration(milliseconds: 2000),
  });

  /// Wordmark besar, mis. "SIGAP".
  final String appName;

  /// Sub-judul mono di bawah wordmark, mis. "DISPATCH CONSOLE".
  final String tagline;

  /// 2-3 baris teks HUD yang muncul bertahap, mis. "MENGINISIALISASI SISTEM...".
  final List<String> bootLines;

  final IconData icon;

  final VoidCallback onFinished;

  final Duration duration;

  @override
  State<BootIntro> createState() => _BootIntroState();
}

class _BootIntroState extends State<BootIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onFinished();
  }

  Animation<double> _stage(double start, double end, {Curve curve = Curves.easeOut}) {
    return CurvedAnimation(parent: _ctrl, curve: Interval(start, end, curve: curve));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    final reticleOpacity = _stage(0.04, 0.26);
    final reticleScale = _stage(0.04, 0.34, curve: Curves.easeOutBack);
    final iconOpacity = _stage(0.14, 0.32);
    final pulseProgress = _stage(0.50, 0.90, curve: Curves.easeInOut);
    final wordmarkOpacity = _stage(0.70, 0.96);
    final wordmarkSlide = _stage(0.70, 0.98, curve: Curves.easeOutCubic);
    final bgOpacity = _stage(0.0, 0.12);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Opacity(
            opacity: bgOpacity.value,
            child: Scaffold(
              body: ConsoleBackground(
                child: SafeArea(
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Opacity(
                              opacity: reticleOpacity.value,
                              child: Transform.scale(
                                scale: 0.85 + reticleScale.value * 0.15,
                                child: ReticleBracket(
                                  size: 116,
                                  child: Opacity(
                                    opacity: iconOpacity.value,
                                    child: Container(
                                      width: 62,
                                      height: 62,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        gradient: DispatchColors.vitalGradient,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: c.vital.withValues(alpha: 0.35),
                                            blurRadius: 24,
                                            spreadRadius: -2,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        widget.icon,
                                        color: c.onVital,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            for (var i = 0; i < widget.bootLines.length; i++)
                              _BootLine(
                                text: widget.bootLines[i],
                                anim: _stage(
                                  0.26 + i * 0.10,
                                  0.36 + i * 0.10,
                                ),
                              ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: 220,
                              height: 34,
                              child: CustomPaint(
                                painter: _BootPulsePainter(
                                  progress: pulseProgress.value,
                                  color: c.vital,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Opacity(
                              opacity: wordmarkOpacity.value,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - wordmarkSlide.value)),
                                child: Column(
                                  children: [
                                    Text(
                                      widget.appName,
                                      style: DispatchType.displayStyle(
                                        size: 26,
                                        weight: 800,
                                        color: c.textPrimary,
                                        letterSpacing: 0.02,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.tagline,
                                      style: DispatchType.monoStyle(
                                        size: 9,
                                        weight: 700,
                                        tracking: 0.22,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 18,
                        child: Center(
                          child: Opacity(
                            opacity: wordmarkOpacity.value,
                            child: Text(
                              'KETUK UNTUK LEWATI',
                              style: DispatchType.monoStyle(
                                size: 7.5,
                                weight: 600,
                                tracking: 0.14,
                                color: c.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BootLine extends StatelessWidget {
  const _BootLine({required this.text, required this.anim});

  final String text;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        return Opacity(
          opacity: anim.value,
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - anim.value)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                text,
                style: DispatchType.monoStyle(
                  size: 9,
                  weight: 600,
                  tracking: 0.06,
                  color: c.textSecondary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Menggambar garis EKG yang sama seperti `PulseStepper` (path signature
/// sistem desain), tapi di sini digambar progresif dari kiri ke kanan lewat
/// `PathMetrics` — efek "tanda vital baru menyala" untuk momen boot.
///
/// Koordinat sengaja diduplikasi dari `pulse_stepper.dart` (bukan diimpor —
/// path-nya `private` di sana): keduanya harus tetap sinkron manual kalau
/// motif EKG tanda tangan ini pernah diubah.
class _BootPulsePainter extends CustomPainter {
  _BootPulsePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const double _vbW = 240;
  static const double _vbH = 40;

  static const List<Offset> _points = [
    Offset(0, 20), Offset(22, 20), Offset(30, 4), Offset(38, 34),
    Offset(46, 20), Offset(88, 20), Offset(96, 4), Offset(104, 34),
    Offset(112, 20), Offset(154, 20), Offset(162, 4), Offset(170, 34),
    Offset(178, 20), Offset(220, 20), Offset(228, 4), Offset(236, 34),
    Offset(244, 20), Offset(240, 20),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final sx = size.width / _vbW;
    final sy = size.height / _vbH;
    Offset map(Offset p) => Offset(p.dx * sx, p.dy * sy);

    final full = Path()..moveTo(map(_points.first).dx, map(_points.first).dy);
    for (final p in _points.skip(1)) {
      final m = map(p);
      full.lineTo(m.dx, m.dy);
    }

    final metrics = full.computeMetrics().toList();
    final totalLen = metrics.fold<double>(0, (sum, m) => sum + m.length);
    final target = totalLen * progress.clamp(0.0, 1.0);

    final drawn = Path();
    var consumed = 0.0;
    for (final m in metrics) {
      if (consumed >= target) break;
      final remaining = target - consumed;
      if (remaining >= m.length) {
        drawn.addPath(m.extractPath(0, m.length), Offset.zero);
      } else {
        drawn.addPath(m.extractPath(0, remaining), Offset.zero);
      }
      consumed += m.length;
    }

    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Titik terang di ujung garis yang sedang "berdenyut" — memperkuat
    // kesan tanda vital baru menyala, bukan sekadar progress bar.
    if (progress < 1.0 && drawn.computeMetrics().isNotEmpty) {
      final tip = drawn.computeMetrics().last;
      final pos = tip.getTangentForOffset(tip.length)?.position;
      if (pos != null) {
        canvas.drawCircle(
          pos,
          4,
          Paint()..color = color.withValues(alpha: 0.9),
        );
        canvas.drawCircle(
          pos,
          8,
          Paint()..color = color.withValues(alpha: 0.25),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BootPulsePainter old) =>
      old.progress != progress || old.color != color;
}
