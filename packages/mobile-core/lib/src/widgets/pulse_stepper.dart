import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/dispatch_colors.dart';
import '../theme/dispatch_typography.dart';

/// **ELEMEN TANDA TANGAN #2 — pulse-line stepper.**
///
/// Alur status digambar sebagai garis EKG/heartbeat LITERAL, bukan stepper
/// titik-garis biasa. Bentuknya disalin persis dari SVG path di
/// `/design-reference` (viewBox 0 0 240 40):
///
///   M0,20 L22,20 L30,4 L38,34 L46,20 L88,20 L96,4 L104,34 L112,20 ...
///
/// Tiap checkpoint duduk di PUNCAK gelombang (y=4), bukan di garis dasar —
/// itu yang membuatnya terbaca sebagai monitor tanda vital, bukan progress bar.
/// Jangan diganti motif lain.
class PulseStepper extends StatelessWidget {
  const PulseStepper({
    super.key,
    required this.status,
    this.steps = defaultSteps,
    this.height = 34,
  });

  final CallStatus status;
  final List<PulseStep> steps;
  final double height;

  /// Empat langkah golden path yang dilihat pasien.
  static const List<PulseStep> defaultSteps = [
    PulseStep('DIKONFIRMASI', [
      CallStatus.confirmed,
      CallStatus.enRoute,
      CallStatus.arrived,
      CallStatus.completed,
    ]),
    PulseStep('MENUJU', [
      CallStatus.enRoute,
      CallStatus.arrived,
      CallStatus.completed,
    ]),
    PulseStep('TIBA', [CallStatus.arrived, CallStatus.completed]),
    PulseStep('SELESAI', [CallStatus.completed]),
  ];

  /// Versi App Sopir — langkah pertama berbunyi "TERIMA", bukan "DIKONFIRMASI".
  static const List<PulseStep> driverSteps = [
    PulseStep('TERIMA', [
      CallStatus.confirmed,
      CallStatus.enRoute,
      CallStatus.arrived,
      CallStatus.completed,
    ]),
    PulseStep('MENUJU', [
      CallStatus.enRoute,
      CallStatus.arrived,
      CallStatus.completed,
    ]),
    PulseStep('KE RS', [CallStatus.arrived, CallStatus.completed]),
    PulseStep('SELESAI', [CallStatus.completed]),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final doneCount = steps.where((s) => s.reachedWhen.contains(status)).length;
    final activeIndex = doneCount < steps.length ? doneCount : -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height + 8,
          child: CustomPaint(
            painter: _PulsePainter(
              stepCount: steps.length,
              doneCount: doneCount,
              activeIndex: activeIndex,
              cancelled: status == CallStatus.cancelled,
              lineColor: c.textPrimary.withValues(alpha: 0.15),
              doneColor: c.vital,
              activeColor: c.amber,
              pendingColor: c.textPrimary.withValues(alpha: 0.25),
              cancelColor: c.siren,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < steps.length; i++)
              Text(
                steps[i].label,
                style: DispatchType.monoStyle(
                  size: 6.5,
                  weight: 700,
                  tracking: 0.02,
                  color: (i < doneCount || i == activeIndex)
                      ? c.textPrimary
                      : c.textTertiary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class PulseStep {
  const PulseStep(this.label, this.reachedWhen);

  final String label;

  /// Status yang menandai langkah ini sudah tercapai.
  final List<CallStatus> reachedWhen;
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.stepCount,
    required this.doneCount,
    required this.activeIndex,
    required this.cancelled,
    required this.lineColor,
    required this.doneColor,
    required this.activeColor,
    required this.pendingColor,
    required this.cancelColor,
  });

  final int stepCount;
  final int doneCount;
  final int activeIndex;
  final bool cancelled;
  final Color lineColor;
  final Color doneColor;
  final Color activeColor;
  final Color pendingColor;
  final Color cancelColor;

  /// Sistem koordinat asli mockup.
  static const double _vbW = 240;
  static const double _vbH = 40;

  /// Titik-titik path EKG dari design-reference, apa adanya.
  static const List<Offset> _points = [
    Offset(0, 20), Offset(22, 20), Offset(30, 4), Offset(38, 34),
    Offset(46, 20), Offset(88, 20), Offset(96, 4), Offset(104, 34),
    Offset(112, 20), Offset(154, 20), Offset(162, 4), Offset(170, 34),
    Offset(178, 20), Offset(220, 20), Offset(228, 4), Offset(236, 34),
    Offset(244, 20), Offset(240, 20),
  ];

  /// Posisi x puncak tiap checkpoint (y=4 di viewBox).
  static const List<double> _peaks = [34, 108, 174, 240];
  static const double _peakY = 4;

  @override
  void paint(Canvas canvas, Size size) {
    // Garis diregangkan mengikuti lebar (persis seperti preserveAspectRatio
    // ="none" di mockup), tapi checkpoint digambar sebagai lingkaran SEJATI
    // setelahnya — kalau ikut diregangkan, bulatannya jadi lonjong.
    const double dotPad = 6;
    final drawW = size.width - dotPad * 2;
    final sx = drawW / _vbW;
    final sy = (size.height - 8) / _vbH;

    Offset map(Offset p) => Offset(dotPad + p.dx * sx, 4 + p.dy * sy);

    final path = Path()..moveTo(map(_points.first).dx, map(_points.first).dy);
    for (final p in _points.skip(1)) {
      final m = map(p);
      path.lineTo(m.dx, m.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < stepCount && i < _peaks.length; i++) {
      final center = map(Offset(_peaks[i], _peakY));
      final done = i < doneCount;
      final active = i == activeIndex;

      final color = cancelled
          ? cancelColor
          : done
              ? doneColor
              : active
                  ? activeColor
                  : pendingColor;

      // Halo lembut pada langkah yang sedang berjalan — menarik mata ke
      // "di mana kita sekarang" tanpa animasi yang mengganggu.
      if (active) {
        canvas.drawCircle(
          center,
          9,
          Paint()..color = color.withValues(alpha: 0.22),
        );
      }
      canvas.drawCircle(center, active ? 5 : 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.doneCount != doneCount ||
      old.activeIndex != activeIndex ||
      old.cancelled != cancelled ||
      old.lineColor != lineColor;
}
