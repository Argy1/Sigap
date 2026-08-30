import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/patient_providers.dart';

/// **Layar 05 — Riwayat Panggilan.**
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final history = ref.watch(callHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(title: 'Riwayat Panggilan'),
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
                      title: 'Belum Ada Riwayat',
                      description:
                          'Semua panggilan darurat yang pernah\nAnda buat akan tercatat di sini',
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                );
              }

              return RefreshIndicator(
                color: c.vital,
                backgroundColor: c.surface,
                onRefresh: () async => ref.invalidate(callHistoryProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  itemCount: calls.length,
                  itemBuilder: (context, i) => _HistoryItem(call: calls[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.call});

  final EmergencyCall call;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cancelled = call.status == CallStatus.cancelled;
    final response = minutesBetween(call.createdAt, call.arrivedAt);

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
                  call.hospitalName ?? 'Rumah sakit tidak tercatat',
                  style: DispatchType.bodyStyle(
                    size: 10.5,
                    weight: 700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDateTime(call.createdAt)} · #${call.callCode}',
                  style: DispatchType.monoStyle(
                    size: 8,
                    weight: 600,
                    color: c.textSecondary,
                  ),
                ),
                // Waktu respons hanya ditampilkan kalau memang terukur —
                // ini angka yang jadi bukti kinerja layanan.
                if (response != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'DIJEMPUT DALAM $response MENIT',
                    style: DispatchType.monoStyle(
                      size: 7.5,
                      weight: 700,
                      tracking: 0.04,
                      color: c.vital,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(status: call.status),
        ],
      ),
    );
  }
}
