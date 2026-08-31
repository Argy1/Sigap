import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/patient_providers.dart';
import 'hospital_detail_screen.dart';

/// **Layar 04 — Peta & RS Terdekat.**
///
/// Ini layar informasi, bukan layar tindakan: pengguna melihat rumah sakit mana
/// saja yang ada di sekitarnya dan seberapa jauh. Sengaja TIDAK ada tombol
/// "pilih rumah sakit ini" — prinsip sistem ini adalah selalu mencari RS
/// terdekat secara otomatis saat SOS ditekan, bukan meminta orang panik
/// memilih dari daftar.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final location = ref.watch(locationProvider);
    final hospitals = ref.watch(nearestHospitalsProvider);
    final userPoint = location is LocationReady ? location.point : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Rumah Sakit Terdekat',
          subtitle: 'Diurutkan berdasarkan waktu tempuh',
        ),
        const SizedBox(height: 8),

        DispatchMap(
          height: 230,
          margin: const EdgeInsets.symmetric(
            horizontal: DispatchSpacing.screenH,
          ),
          userLocation: userPoint,
          markers: [
            for (final (i, h) in (hospitals.value ?? []).indexed)
              MapMarker(
                id: h.id,
                position: h.position,
                label: '${i + 1}',
                tone: i == 0 ? MarkerTone.vital : MarkerTone.muted,
                title: h.name,
              ),
          ],
          overlay: Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: c.isDark
                    ? c.ink.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: c.surfaceBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 13, color: c.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    userPoint == null
                        ? 'MENUNGGU LOKASI...'
                        : formatCoords(userPoint),
                    style: DispatchType.monoStyle(
                      size: 9,
                      weight: 600,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.fromLTRB(
              DispatchSpacing.screenH,
              14,
              DispatchSpacing.screenH,
              0,
            ),
            decoration: BoxDecoration(
              color: c.isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(top: BorderSide(color: c.surfaceBorder)),
            ),
            child: hospitals.when(
              loading: () => Center(
                child: Text(
                  'MENCARI RUMAH SAKIT...',
                  style: DispatchType.monoStyle(
                    size: 9,
                    weight: 700,
                    tracking: 0.1,
                    color: c.textSecondary,
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Gagal memuat daftar RS.\n$e',
                    textAlign: TextAlign.center,
                    style: DispatchType.bodyStyle(
                      size: 10,
                      weight: 500,
                      color: c.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        location is LocationReady
                            ? 'Belum ada rumah sakit terverifikasi\ndi sekitar lokasi Anda.'
                            : 'Menunggu izin lokasi untuk mencari\nrumah sakit terdekat.',
                        textAlign: TextAlign.center,
                        style: DispatchType.bodyStyle(
                          size: 10,
                          weight: 500,
                          color: c.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PanelLabel(
                      '${list.length} RS TERDEKAT · DIURUTKAN WAKTU TEMPUH',
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: list.length,
                        itemBuilder: (context, i) =>
                            _HospitalRow(hospital: list[i], rank: i + 1),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _HospitalRow extends StatelessWidget {
  const _HospitalRow({required this.hospital, required this.rank});

  final NearbyHospital hospital;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isNearest = rank == 1;

    // Material+InkWell (bukan cuma GestureDetector) supaya ada umpan balik
    // ripple saat disentuh — baris ini sekarang menuju halaman detail RS,
    // bukan cuma informasi statis. Tetap TIDAK ada tombol "pilih RS ini
    // untuk SOS" (lihat doc-comment MapScreen) — ini murni navigasi info.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => HospitalDetailScreen(hospital: hospital),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.divider)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isNearest
                      ? c.vital.withValues(alpha: 0.15)
                      : c.vital.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_rounded, size: 15, color: c.vital),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hospital.name,
                      style: DispatchType.bodyStyle(
                        size: 10,
                        weight: 700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      hospital.address.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DispatchType.monoStyle(
                        size: 7.5,
                        weight: 600,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatDistance(hospital.distanceMeters),
                    style: DispatchType.monoStyle(
                      size: 10.5,
                      weight: 700,
                      color: c.vital,
                      tracking: 0.02,
                    ),
                  ),
                  Text(
                    formatDuration(hospital.durationSeconds),
                    style: DispatchType.monoStyle(
                      size: 7.5,
                      weight: 600,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
