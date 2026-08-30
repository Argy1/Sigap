import 'package:flutter/material.dart';

import '../theme/dispatch_colors.dart';

/// **ELEMEN TANDA TANGAN #1 — bracket reticle.**
///
/// Empat siku seperti bracket fokus kamera, mewakili "penguncian lokasi GPS".
/// Di mockup ini mengelilingi tombol SOS dan titik lokasi pengguna.
///
/// Ukuran dari design-reference: siku 24x24, garis 2px, radius sudut luar 8px.
/// Jangan diganti motif lain — ini identitas visual sistem desain.
class ReticleBracket extends StatelessWidget {
  const ReticleBracket({
    super.key,
    required this.size,
    this.child,
    this.armLength = 24,
    this.thickness = 2,
    this.color,
    this.opacity = 0.5,
    this.cornerRadius = 8,
  });

  /// Sisi kotak reticle keseluruhan (mockup: 196 untuk tombol SOS).
  final double size;
  final Widget? child;
  final double armLength;
  final double thickness;
  final Color? color;
  final double opacity;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.c.vital;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ReticlePainter(
              color: c.withValues(alpha: opacity),
              armLength: armLength,
              thickness: thickness,
              cornerRadius: cornerRadius,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  _ReticlePainter({
    required this.color,
    required this.armLength,
    required this.thickness,
    required this.cornerRadius,
  });

  final Color color;
  final double armLength;
  final double thickness;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final r = cornerRadius;
    final inset = thickness / 2;
    final w = size.width;
    final h = size.height;

    // Kiri atas
    canvas.drawPath(
      Path()
        ..moveTo(inset, armLength)
        ..lineTo(inset, inset + r)
        ..arcToPoint(Offset(inset + r, inset), radius: Radius.circular(r))
        ..lineTo(armLength, inset),
      paint,
    );
    // Kanan atas
    canvas.drawPath(
      Path()
        ..moveTo(w - armLength, inset)
        ..lineTo(w - inset - r, inset)
        ..arcToPoint(Offset(w - inset, inset + r), radius: Radius.circular(r))
        ..lineTo(w - inset, armLength),
      paint,
    );
    // Kiri bawah
    canvas.drawPath(
      Path()
        ..moveTo(inset, h - armLength)
        ..lineTo(inset, h - inset - r)
        ..arcToPoint(
          Offset(inset + r, h - inset),
          radius: Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(armLength, h - inset),
      paint,
    );
    // Kanan bawah
    canvas.drawPath(
      Path()
        ..moveTo(w - armLength, h - inset)
        ..lineTo(w - inset - r, h - inset)
        ..arcToPoint(
          Offset(w - inset, h - inset - r),
          radius: Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(w - inset, h - armLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ReticlePainter old) =>
      old.color != color ||
      old.armLength != armLength ||
      old.thickness != thickness ||
      old.cornerRadius != cornerRadius;
}
