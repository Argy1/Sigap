import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/driver_providers.dart';

/// **Layar 04 — Navigasi Aktif.**
///
/// Layar yang dilihat sambil mengemudi. Karena itu hanya ada SATU tombol aksi
/// besar di bawah, dan isinya berubah mengikuti tahap: "KONFIRMASI TIBA DI
/// LOKASI" lalu "SELESAIKAN PENJEMPUTAN". Menampilkan beberapa pilihan
/// sekaligus di layar ini adalah undangan salah tekan.
class ActiveTaskScreen extends ConsumerStatefulWidget {
  const ActiveTaskScreen({super.key});

  @override
  ConsumerState<ActiveTaskScreen> createState() => _ActiveTaskScreenState();
}

class _ActiveTaskScreenState extends ConsumerState<ActiveTaskScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String failMessage) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$failMessage: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final call = ref.watch(currentAssignmentProvider);
    final location = ref.watch(locationProvider);
    final broadcasting = ref.watch(locationBroadcastProvider);

    if (call == null) return const Scaffold(body: SizedBox.shrink());

    final myPos = location is LocationReady ? location.point : null;
    final meters = myPos == null ? null : haversineMeters(myPos, call.location);
    final eta = meters == null ? null : estimateEtaSeconds(meters);

    final arrived = call.status == CallStatus.arrived;

    return Scaffold(
      body: ConsoleBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                title: arrived ? 'Tiba di Lokasi Pasien' : 'Menuju Lokasi Pasien',
                subtitle: 'Status: Aktif · SOS #${call.callCode}',
                subtitleColor: c.vital,
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      DispatchMap(
                        height: 200,
                        margin: const EdgeInsets.symmetric(
                          horizontal: DispatchSpacing.screenH,
                        ),
                        userLocation: myPos,
                        markers: [
                          MapMarker(
                            id: 'patient',
                            position: call.location,
                            label: 'P',
                            tone: MarkerTone.siren,
                            title: call.patientName,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      ReadoutRow(
                        children: [
                          ReadoutCard(
                            label: 'SISA JARAK',
                            value: formatDistance(meters?.round()),
                          ),
                          ReadoutCard(
                            label: 'ESTIMASI',
                            value: formatDuration(eta),
                          ),
                        ],
                      ),

                      DispatchPanel(
                        margin: const EdgeInsets.fromLTRB(
                          DispatchSpacing.screenH,
                          10,
                          DispatchSpacing.screenH,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const PanelLabel('TUJUAN'),
                            const SizedBox(height: 4),
                            Text(
                              call.patientAddress ?? formatCoords(call.location),
                              style: DispatchType.bodyStyle(
                                size: 10.5,
                                weight: 700,
                                color: c.textPrimary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const PanelLabel('PASIEN'),
                            const SizedBox(height: 4),
                            Text(
                              '${call.patientName} · ${call.patientPhone ?? '—'}',
                              style: DispatchType.bodyStyle(
                                size: 10.5,
                                weight: 600,
                                color: c.textPrimary,
                              ),
                            ),
                            if (call.medical != null &&
                                call.medical!.allergies.isNotEmpty)
                              MedicalAlert(
                                text:
                                    '⚠ ALERGI ${call.medical!.allergies.join(', ').toUpperCase()}'
                                    '${call.medical!.bloodType != null ? ' · GOL. DARAH ${call.medical!.bloodType}' : ''}',
                              ),
                          ],
                        ),
                      ),

                      // Pulse stepper versi sopir — langkah pertama "TERIMA".
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DispatchSpacing.screenH,
                          14,
                          DispatchSpacing.screenH,
                          0,
                        ),
                        child: PulseStepper(
                          status: call.status,
                          steps: PulseStepper.driverSteps,
                        ),
                      ),

                      // Indikator penyiaran posisi: pasien sedang melihat
                      // pergerakan ini, jadi sopir perlu tahu kalau mati.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DispatchSpacing.screenH,
                          14,
                          DispatchSpacing.screenH,
                          0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: broadcasting ? c.vital : c.amber,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              broadcasting
                                  ? 'POSISI ANDA DIPANTAU PASIEN'
                                  : 'POSISI TIDAK TERKIRIM — CEK IZIN LOKASI',
                              style: DispatchType.monoStyle(
                                size: 7.5,
                                weight: 700,
                                tracking: 0.06,
                                color: broadcasting
                                    ? c.textSecondary
                                    : c.amberText,
                              ),
                            ),
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
                child: DispatchButton(
                  label: arrived
                      ? 'SELESAIKAN PENJEMPUTAN'
                      : 'KONFIRMASI TIBA DI LOKASI',
                  loading: _busy,
                  icon: arrived
                      ? Icons.check_circle_rounded
                      : Icons.place_rounded,
                  onPressed: _busy
                      ? null
                      : () => _run(
                            arrived
                                ? ref
                                    .read(currentAssignmentProvider.notifier)
                                    .complete
                                : ref
                                    .read(currentAssignmentProvider.notifier)
                                    .markArrived,
                            'Gagal memperbarui status',
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
