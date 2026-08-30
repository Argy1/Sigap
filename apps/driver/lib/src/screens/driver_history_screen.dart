import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/driver_providers.dart';

/// **Layar 05 — Riwayat Penjemputan.**
///
/// Berbeda dari riwayat pasien: yang ditonjolkan di sini adalah DURASI tiap
/// penjemputan, karena itulah ukuran kinerja yang berarti bagi sopir.
class DriverHistoryScreen extends ConsumerWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final history = ref.watch(driverHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(title: 'Riwayat Penjemputan'),
        Expanded(
          child: history.when(
            loading: () => Center(
              child: Text(
                'MEMUAT RIWAYAT...',
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
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Gagal memuat riwayat.\n$e',
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
            data: (calls) {
              if (calls.isEmpty) {
                return const Column(
                  children: [
                    DispatchEmptyState(
                      title: 'Belum Ada Penjemputan',
                      description:
                          'Penjemputan yang sudah Anda selesaikan\nakan tercatat di sini',
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                );
              }
              return RefreshIndicator(
                color: c.vital,
                backgroundColor: c.surface,
                onRefresh: () async => ref.invalidate(driverHistoryProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  itemCount: calls.length,
                  itemBuilder: (context, i) => _Item(call: calls[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.call});

  final EmergencyCall call;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cancelled = call.status == CallStatus.cancelled;
    // Durasi tugas: dari sopir ditugaskan sampai penjemputan selesai.
    final duration = minutesBetween(call.confirmedAt, call.completedAt);
    final hospital = (call.hospitalName ?? 'RS').toUpperCase();

    return DispatchPanel(
      margin: const EdgeInsets.fromLTRB(
        DispatchSpacing.screenH,
        0,
        DispatchSpacing.screenH,
        9,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      radius: DispatchRadii.card,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cancelled ? c.sirenTint : c.vitalTint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              cancelled ? Icons.close_rounded : Icons.check_rounded,
              size: 15,
              color: cancelled ? c.siren : c.vital,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pasien di ${_shortAddress(call)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DispatchType.bodyStyle(
                    size: 10.5,
                    weight: 700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDateTime(call.createdAt)} · KE $hospital',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DispatchType.monoStyle(
                    size: 8,
                    weight: 600,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (duration != null)
            Text(
              '$duration MNT',
              style: DispatchType.monoStyle(
                size: 9,
                weight: 700,
                color: c.vital,
              ),
            )
          else
            StatusChip(status: call.status),
        ],
      ),
    );
  }

  /// Ambil ruas jalan saja dari alamat lengkap, agar muat satu baris.
  String _shortAddress(EmergencyCall call) {
    final addr = call.patientAddress;
    if (addr == null || addr.isEmpty) return formatCoords(call.location);
    return addr.split(',').first.trim();
  }
}
