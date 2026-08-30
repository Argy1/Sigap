import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import '../api/api_client.dart';
import '../models/models.dart';
import '../theme/dispatch_colors.dart';
import '../theme/dispatch_theme.dart';
import '../theme/dispatch_typography.dart';

/// Satu penanda di peta.
class MapMarker {
  const MapMarker({
    required this.id,
    required this.position,
    required this.label,
    this.tone = MarkerTone.vital,
    this.title,
  });

  final String id;
  final LatLngPoint position;

  /// Teks di dalam pin — nomor urut atau satu huruf.
  final String label;
  final MarkerTone tone;
  final String? title;
}

enum MarkerTone { vital, siren, muted }

/// Peta aplikasi.
///
/// Dua implementasi, dipilih otomatis dari ada/tidaknya API key:
///
/// * `--dart-define=GOOGLE_MAPS_API_KEY=...` -> Google Maps sungguhan.
/// * tanpa key                               -> [ConsoleMap] di bawah.
///
/// Fallback-nya BUKAN placeholder darurat. Mockup di `/design-reference` memang
/// menggambarkan peta abstrak bergaya konsol (grid + garis jalan diagonal +
/// pin bracket), jadi tampilan fallback justru yang paling setia ke desain.
/// Posisi pin tetap dihitung dari koordinat asli; yang berbeda hanya latarnya.
class DispatchMap extends StatelessWidget {
  const DispatchMap({
    super.key,
    this.markers = const [],
    this.userLocation,
    this.height = 180,
    this.margin,
    this.overlay,
    this.radius = DispatchRadii.panel,
  });

  final List<MapMarker> markers;

  /// Titik pengguna — digambar sebagai dot putih bercincin, bukan pin.
  final LatLngPoint? userLocation;
  final double height;
  final EdgeInsetsGeometry? margin;

  /// Konten yang ditumpuk di atas peta (mis. kotak pencarian).
  final Widget? overlay;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final map = hasGoogleMaps
        ? _GoogleMapView(markers: markers, userLocation: userLocation)
        : ConsoleMap(markers: markers, userLocation: userLocation);

    return Container(
      height: height,
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.c.mapBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: context.c.surfaceBorder),
      ),
      child: Stack(children: [Positioned.fill(child: map), ?overlay]),
    );
  }
}

// ---------------------------------------------------------------------------
// Fallback: peta skematik bergaya mockup
// ---------------------------------------------------------------------------

class ConsoleMap extends StatelessWidget {
  const ConsoleMap({super.key, this.markers = const [], this.userLocation});

  final List<MapMarker> markers;
  final LatLngPoint? userLocation;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final points = <LatLngPoint>[
      ...markers.map((m) => m.position),
      ?userLocation,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final project = _Projector(points);

        return Stack(
          children: [
            // Latar: garis pindai + dua garis jalan diagonal, persis seperti
            // `.map-dark` di mockup.
            Positioned.fill(
              child: CustomPaint(
                painter: _ConsoleMapPainter(
                  bg: c.mapBg,
                  scan: c.vital.withValues(alpha: c.isDark ? 0.03 : 0.05),
                  road: c.vital.withValues(alpha: c.isDark ? 0.13 : 0.16),
                  roadSoft: c.vital.withValues(alpha: c.isDark ? 0.08 : 0.10),
                ),
              ),
            ),

            if (userLocation != null)
              _positioned(
                project(userLocation!, size),
                const Size(21, 21),
                _UserDot(),
              ),

            for (final m in markers)
              _positioned(
                project(m.position, size),
                const Size(28, 34),
                _Pin(marker: m),
                anchorBottom: true,
              ),

            // Jujur ke pengguna tentang mode peta, tanpa mengganggu.
            Positioned(
              right: 8,
              bottom: 6,
              child: Text(
                'PETA SKEMATIK',
                style: DispatchType.monoStyle(
                  size: 6.5,
                  weight: 700,
                  tracking: 0.12,
                  color: c.textTertiary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _positioned(
    Offset pos,
    Size childSize,
    Widget child, {
    bool anchorBottom = false,
  }) {
    return Positioned(
      left: pos.dx - childSize.width / 2,
      top: anchorBottom ? pos.dy - childSize.height : pos.dy - childSize.height / 2,
      child: child,
    );
  }
}

/// Memproyeksikan lat/lng ke piksel dalam kotak peta.
///
/// Bounding box dihitung dari titik-titik yang ada lalu diberi padding, jadi
/// semua penanda selalu terlihat berapa pun sebarannya. Jangkauan minimum
/// mencegah pembagian nol saat hanya ada satu titik.
class _Projector {
  _Projector(List<LatLngPoint> points) {
    if (points.isEmpty) {
      _latMid = -6.5944;
      _lngMid = 106.7892;
      _latSpan = _minSpan;
      _lngSpan = _minSpan;
      return;
    }
    final lats = points.map((p) => p.lat);
    final lngs = points.map((p) => p.lng);
    final latMin = lats.reduce(math.min);
    final latMax = lats.reduce(math.max);
    final lngMin = lngs.reduce(math.min);
    final lngMax = lngs.reduce(math.max);

    _latMid = (latMin + latMax) / 2;
    _lngMid = (lngMin + lngMax) / 2;
    _latSpan = math.max(latMax - latMin, _minSpan) * 1.5;
    _lngSpan = math.max(lngMax - lngMin, _minSpan) * 1.5;
  }

  /// ~1.3 km — skala kota, cukup untuk satu SOS dan RS terdekatnya.
  static const double _minSpan = 0.012;

  late final double _latMid;
  late final double _lngMid;
  late final double _latSpan;
  late final double _lngSpan;

  Offset call(LatLngPoint p, Size size) => Offset(
        ((p.lng - _lngMid) / _lngSpan + 0.5) * size.width,
        // Lintang naik ke atas; sumbu Y layar naik ke bawah -> dibalik.
        (0.5 - (p.lat - _latMid) / _latSpan) * size.height,
      );
}

class _ConsoleMapPainter extends CustomPainter {
  _ConsoleMapPainter({
    required this.bg,
    required this.scan,
    required this.road,
    required this.roadSoft,
  });

  final Color bg;
  final Color scan;
  final Color road;
  final Color roadSoft;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    // Garis pindai horizontal tiap 4px.
    final scanPaint = Paint()
      ..color = scan
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // Dua "jalan" diagonal — sesuai linear-gradient miring di mockup.
    canvas.drawLine(
      Offset(-size.width * 0.1, size.height * 0.95),
      Offset(size.width * 0.85, -size.height * 0.1),
      Paint()
        ..color = road
        ..strokeWidth = size.height * 0.05,
    );
    canvas.drawLine(
      Offset(-size.width * 0.05, size.height * 0.25),
      Offset(size.width * 1.05, size.height * 0.78),
      Paint()
        ..color = roadSoft
        ..strokeWidth = size.height * 0.04,
    );
  }

  @override
  bool shouldRepaint(_ConsoleMapPainter old) => old.bg != bg || old.road != road;
}

/// Pin bentuk tetesan — replikasi `.map-pin` di mockup.
class _Pin extends StatelessWidget {
  const _Pin({required this.marker});

  final MapMarker marker;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = switch (marker.tone) {
      MarkerTone.siren => DispatchColors.sirenRaw,
      MarkerTone.vital => c.vital,
      MarkerTone.muted => c.vital.withValues(alpha: 0.5),
    };
    final fg = marker.tone == MarkerTone.siren
        ? Colors.white
        : (c.isDark ? const Color(0xFF04140C) : Colors.white);

    return Tooltip(
      message: marker.title ?? marker.label,
      child: SizedBox(
        width: 28,
        height: 34,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: -math.pi / 4,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Text(
                    marker.label,
                    style: DispatchType.monoStyle(
                      size: 10,
                      weight: 800,
                      color: fg,
                      tracking: 0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Titik lokasi pengguna — dot putih dengan cincin, seperti `.map-userdot`.
class _UserDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 21,
      height: 21,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.textPrimary.withValues(alpha: 0.18),
      ),
      child: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.isDark ? c.textPrimary : const Color(0xFF0A0E14),
          border: Border.all(color: c.isDark ? c.ink : Colors.white, width: 3),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Google Maps — hanya dirender kalau API key tersedia
// ---------------------------------------------------------------------------

class _GoogleMapView extends StatelessWidget {
  const _GoogleMapView({required this.markers, this.userLocation});

  final List<MapMarker> markers;
  final LatLngPoint? userLocation;

  static const _bogorCenter = gmaps.LatLng(-6.5944, 106.7892);

  @override
  Widget build(BuildContext context) {
    final points = <LatLngPoint>[
      ...markers.map((m) => m.position),
      ?userLocation,
    ];

    final center = points.isEmpty
        ? _bogorCenter
        : gmaps.LatLng(
            points.map((p) => p.lat).reduce((a, b) => a + b) / points.length,
            points.map((p) => p.lng).reduce((a, b) => a + b) / points.length,
          );

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(target: center, zoom: 14),
      myLocationEnabled: userLocation != null,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      markers: {
        for (final m in markers)
          gmaps.Marker(
            markerId: gmaps.MarkerId(m.id),
            position: gmaps.LatLng(m.position.lat, m.position.lng),
            infoWindow: gmaps.InfoWindow(title: m.title ?? m.label),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
              switch (m.tone) {
                MarkerTone.siren => gmaps.BitmapDescriptor.hueRose,
                _ => gmaps.BitmapDescriptor.hueGreen,
              },
            ),
          ),
      },
    );
  }
}
