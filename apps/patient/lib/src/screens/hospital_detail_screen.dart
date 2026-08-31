import 'package:flutter/material.dart';
import 'package:mobile_core/mobile_core.dart';

/// **Layar Detail Rumah Sakit** — dibuka dari daftar RS terdekat di layar
/// Peta.
///
/// Menerima `NearbyHospital` LANGSUNG dari layar Peta (bukan API call baru):
/// objek itu sudah membawa semua yang dibutuhkan halaman ini (nama, alamat,
/// telepon, posisi, jarak, estimasi waktu). Endpoint `GET /hospitals/:id`
/// yang ada di backend khusus staff RS/admin, jadi memang tidak dipakai di
/// sini — pasien tidak perlu API terpisah untuk info yang sudah di tangan.
///
/// Ini murni layar INFORMASI, bukan tindakan: tidak ada tombol "pilih RS ini
/// untuk SOS" — sistem selalu otomatis memilih RS terdekat saat SOS ditekan.
class HospitalDetailScreen extends StatelessWidget {
  const HospitalDetailScreen({super.key, required this.hospital});

  final NearbyHospital hospital;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Scaffold(
      body: ConsoleBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                title: hospital.name,
                subtitle: hospital.source == 'google'
                    ? 'Jarak tempuh jalan sebenarnya'
                    : 'Estimasi jarak',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    DispatchSpacing.screenH,
                    6,
                    DispatchSpacing.screenH,
                    20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DispatchMap(
                        height: 170,
                        markers: [
                          MapMarker(
                            id: hospital.id,
                            position: hospital.position,
                            label: '1',
                            title: hospital.name,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      ReadoutRow(
                        children: [
                          ReadoutCard(
                            label: 'JARAK TEMPUH',
                            value: formatDistance(hospital.distanceMeters),
                          ),
                          ReadoutCard(
                            label: 'ESTIMASI WAKTU',
                            value: formatDuration(hospital.durationSeconds),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      DispatchPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const PanelLabel('ALAMAT'),
                            const SizedBox(height: 5),
                            Text(
                              hospital.address,
                              style: DispatchType.bodyStyle(
                                size: 11,
                                weight: 600,
                                color: c.textPrimary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const PanelLabel('TELEPON'),
                            const SizedBox(height: 5),
                            Text(
                              hospital.phone ?? 'Tidak tersedia',
                              style: DispatchType.monoStyle(
                                size: 11,
                                weight: 700,
                                color: hospital.phone == null
                                    ? c.textTertiary
                                    : c.vital,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (hospital.phone != null) ...[
                        const SizedBox(height: 20),
                        DispatchButton(
                          label: 'TELEPON RUMAH SAKIT',
                          icon: Icons.phone_rounded,
                          onPressed: () =>
                              callPhoneNumber(context, hospital.phone!),
                        ),
                      ],
                    ],
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
