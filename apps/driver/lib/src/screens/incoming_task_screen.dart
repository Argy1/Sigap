import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/driver_providers.dart';

/// **Layar 03 — Tugas Masuk.**
///
/// Layar keputusan: TERIMA atau TOLAK. Sopir melihatnya sambil mungkin sedang
/// berdiri di dekat ambulans, jadi informasinya disusun agar terbaca sekilas —
/// jarak dulu, lalu lokasi, lalu kondisi, lalu peringatan medis merah.
///
/// Peringatan alergi/golongan darah sengaja diberi warna siren: itu satu-satunya
/// informasi di layar ini yang, kalau terlewat, bisa berakibat fatal.
class IncomingTaskScreen extends ConsumerStatefulWidget {
  const IncomingTaskScreen({super.key});

  @override
  ConsumerState<IncomingTaskScreen> createState() => _IncomingTaskScreenState();
}

class _IncomingTaskScreenState extends ConsumerState<IncomingTaskScreen> {
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

    if (call == null) return const Scaffold(body: SizedBox.shrink());

    final myPos = location is LocationReady ? location.point : null;
    final meters = myPos == null ? null : haversineMeters(myPos, call.location);
    final eta = meters == null ? null : estimateEtaSeconds(meters);

    final medical = call.medical;
    final medicalWarning = <String>[
      if (medical != null && medical.allergies.isNotEmpty)
        'ALERGI ${medical.allergies.join(', ').toUpperCase()}',
      if (medical?.bloodType != null) 'GOL. DARAH ${medical!.bloodType}',
    ].join(' · ');

    return Scaffold(
      body: ConsoleBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                title: 'Tugas Baru Masuk',
                subtitle: 'Status: Baru · Perlu Respon · SOS #${call.callCode}',
                subtitleColor: c.amberText,
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      DispatchMap(
                        height: 180,
                        margin: const EdgeInsets.symmetric(
                          horizontal: DispatchSpacing.screenH,
                        ),
                        userLocation: myPos,
                        markers: [
                          MapMarker(
                            id: 'patient',
                            position: call.location,
                            label: '!',
                            tone: MarkerTone.siren,
                            title: call.patientName,
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
                            _Row(
                              label: 'JARAK KE LOKASI',
                              value: meters == null
                                  ? 'Menunggu GPS'
                                  : '${formatDistance(meters.round())} · ≈ ${formatDuration(eta)}',
                              valueColor: c.vital,
                            ),
                            _Row(
                              label: 'LOKASI PASIEN',
                              value: call.patientAddress ??
                                  formatCoords(call.location),
                            ),
                            _Row(
                              label: 'PASIEN',
                              value: call.patientName +
                                  (call.isGuest ? ' (tamu)' : ''),
                            ),
                            _Row(
                              label: 'KONTAK',
                              value: call.patientPhone ?? '—',
                            ),
                            _Row(
                              label: 'KONDISI',
                              value: call.conditionNote ?? 'Tidak disebutkan',
                              last: true,
                            ),

                            // Peringatan medis — satu-satunya elemen merah di
                            // layar ini selain tombol batal.
                            if (medicalWarning.isNotEmpty)
                              MedicalAlert(text: '⚠ $medicalWarning'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Aksi: TOLAK sempit, TERIMA lebar — proporsi dari mockup
              // (flex 1 : 2). Tindakan yang benar diberi target lebih besar.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DispatchSpacing.screenH,
                  14,
                  DispatchSpacing.screenH,
                  16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DispatchOutlineButton(
                        label: 'TOLAK',
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  ref
                                      .read(currentAssignmentProvider.notifier)
                                      .reject,
                                  'Gagal menolak tugas',
                                ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      flex: 2,
                      child: DispatchButton(
                        label: 'TERIMA TUGAS',
                        loading: _busy,
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  ref
                                      .read(currentAssignmentProvider.notifier)
                                      .accept,
                                  'Gagal menerima tugas',
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris label mono + nilai — pola `.pc-row` di mockup.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.valueColor,
    this.last = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DispatchType.monoStyle(
              size: 7.5,
              weight: 700,
              tracking: 0.05,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: DispatchType.bodyStyle(
                size: 10,
                weight: 700,
                color: valueColor ?? c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
