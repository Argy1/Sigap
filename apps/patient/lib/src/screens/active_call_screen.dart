import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/patient_providers.dart';

/// **Layar 03 — SOS Aktif / Live Tracking.**
///
/// Layar yang dipandangi orang dalam keadaan paling cemas. Prioritas isinya
/// disusun sesuai pertanyaan yang ada di kepala mereka, berurutan:
///   1. "Di mana ambulansnya?"   -> peta
///   2. "Berapa lama lagi?"      -> readout ETA besar
///   3. "Siapa yang menjemput?"  -> kartu sopir + tombol telepon
///   4. "Sudah sampai mana?"     -> pulse stepper
class ActiveCallScreen extends ConsumerWidget {
  const ActiveCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final call = ref.watch(activeCallProvider);
    final connected = ref.watch(socketConnectedProvider).value ?? false;

    if (call == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    // ETA & jarak dihitung dari posisi sopir yang bergerak. Selama sopir belum
    // mengirim posisi, tidak ada angka yang jujur untuk ditampilkan — lebih
    // baik "—" daripada perkiraan yang menyesatkan di saat genting.
    final driverPos = call.driverLocation;
    final meters =
        driverPos == null ? null : haversineMeters(driverPos, call.location);
    final etaSeconds = meters == null ? null : estimateEtaSeconds(meters);

    return Scaffold(
      body: ConsoleBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                title: switch (call.status) {
                  CallStatus.pending => 'Mencari Ambulans',
                  CallStatus.confirmed => 'Ambulans Ditugaskan',
                  CallStatus.enRoute => 'Ambulans Menuju Lokasi',
                  CallStatus.arrived => 'Ambulans Telah Tiba',
                  _ => 'Panggilan Selesai',
                },
                subtitle:
                    'Status: ${call.status.shortLabel} · SOS #${call.callCode}',
                subtitleColor: call.status == CallStatus.pending
                    ? c.amberText
                    : c.vital,
                trailing: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected ? c.vital : c.textTertiary,
                    boxShadow: connected
                        ? [
                            BoxShadow(
                              color: c.vital.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      DispatchMap(
                        height: 190,
                        margin: const EdgeInsets.symmetric(
                          horizontal: DispatchSpacing.screenH,
                        ),
                        userLocation: call.location,
                        markers: [
                          if (driverPos != null)
                            MapMarker(
                              id: 'driver',
                              position: driverPos,
                              label: '🚑',
                              tone: MarkerTone.vital,
                              title: call.driverName ?? 'Ambulans',
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      ReadoutRow(
                        children: [
                          ReadoutCard(
                            label: 'ESTIMASI TIBA',
                            value: formatDurationLong(etaSeconds),
                            valueSize: 18,
                            flex: 13,
                          ),
                          ReadoutCard(
                            label: 'JARAK',
                            value: formatDistance(meters?.round()),
                            flex: 10,
                          ),
                        ],
                      ),

                      // Kartu sopir muncul begitu ada yang ditugaskan.
                      if (call.driverName != null)
                        DispatchPanel(
                          margin: const EdgeInsets.fromLTRB(
                            DispatchSpacing.screenH,
                            10,
                            DispatchSpacing.screenH,
                            0,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              DispatchAvatar(
                                name: call.driverName!,
                                size: 36,
                                radius: 11,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      call.driverName!,
                                      style: DispatchType.bodyStyle(
                                        size: 10.5,
                                        weight: 700,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        call.hospitalName?.toUpperCase(),
                                        call.vehiclePlate,
                                      ].whereType<String>().join(' · '),
                                      style: DispatchType.monoStyle(
                                        size: 8,
                                        weight: 600,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c.vitalTint,
                                  border: Border.all(color: c.vitalBorder),
                                ),
                                child: Icon(
                                  Icons.phone_rounded,
                                  size: 14,
                                  color: c.vital,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DispatchPanel(
                          margin: const EdgeInsets.fromLTRB(
                            DispatchSpacing.screenH,
                            10,
                            DispatchSpacing.screenH,
                            0,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(c.amber),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  '${call.hospitalName ?? 'Rumah sakit'} sedang menugaskan sopir...',
                                  style: DispatchType.bodyStyle(
                                    size: 10,
                                    weight: 600,
                                    color: c.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ELEMEN TANDA TANGAN — pulse stepper garis EKG.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DispatchSpacing.screenH,
                          14,
                          DispatchSpacing.screenH,
                          0,
                        ),
                        child: PulseStepper(status: call.status),
                      ),

                      // Alamat & kondisi yang dilaporkan.
                      DispatchPanel(
                        margin: const EdgeInsets.fromLTRB(
                          DispatchSpacing.screenH,
                          14,
                          DispatchSpacing.screenH,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PanelLabel('LOKASI PENJEMPUTAN'),
                            const SizedBox(height: 4),
                            Text(
                              call.patientAddress ?? formatCoords(call.location),
                              style: DispatchType.bodyStyle(
                                size: 10.5,
                                weight: 600,
                                color: c.textPrimary,
                                height: 1.4,
                              ),
                            ),
                            if (call.conditionNote != null) ...[
                              const SizedBox(height: 10),
                              const PanelLabel('KONDISI DILAPORKAN'),
                              const SizedBox(height: 4),
                              Text(
                                call.conditionNote!,
                                style: DispatchType.bodyStyle(
                                  size: 10.5,
                                  weight: 600,
                                  color: c.textPrimary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DispatchSpacing.screenH,
                  4,
                  DispatchSpacing.screenH,
                  16,
                ),
                child: DispatchDangerButton(
                  label: 'BATALKAN PANGGILAN',
                  onPressed: () => _confirmCancel(context, ref),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final c = context.c;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.isDark ? const Color(0xFF11161F) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DispatchRadii.panel),
        ),
        title: Text(
          'Batalkan panggilan?',
          style: DispatchType.displayStyle(
            size: 14,
            weight: 700,
            color: c.textPrimary,
          ),
        ),
        content: Text(
          'Ambulans yang sedang menuju lokasi Anda akan dihentikan. '
          'Lakukan ini hanya kalau bantuan sudah tidak diperlukan.',
          style: DispatchType.bodyStyle(
            size: 11,
            weight: 500,
            color: c.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Tidak jadi',
              style: DispatchType.bodyStyle(
                size: 11,
                weight: 700,
                color: c.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Ya, batalkan',
              style: DispatchType.bodyStyle(
                size: 11,
                weight: 700,
                color: c.siren,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(activeCallProvider.notifier).cancel();
      ref.read(activeCallProvider.notifier).clear();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membatalkan: $e')),
        );
      }
    }
  }
}
