import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/patient_providers.dart';

/// **Layar 02 — Beranda / SOS.**
///
/// Tombol SOS adalah elemen paling dominan di layar. Semua yang lain — baris
/// lokasi, readout RS terdekat — mendukungnya, tidak bersaing dengannya.
class SosHomeScreen extends ConsumerStatefulWidget {
  const SosHomeScreen({super.key});

  @override
  ConsumerState<SosHomeScreen> createState() => _SosHomeScreenState();
}

class _SosHomeScreenState extends ConsumerState<SosHomeScreen> {
  bool _sending = false;

  Future<void> _triggerSos() async {
    if (_sending) return;

    final location = ref.read(locationProvider);
    if (location is! LocationReady) {
      _showLocationProblem();
      return;
    }

    final auth = ref.read(authProvider);
    final isGuest = auth is AuthSignedOut;

    // Mode tamu wajib punya nama & nomor — tanpa itu RS tidak bisa menghubungi
    // balik, dan panggilannya jadi hampir tidak berguna secara operasional.
    GuestDetails? guest;
    if (isGuest) {
      guest = await _askGuestDetails();
      if (guest == null) return;
    }

    final note = await _askCondition();
    // Batal di dialog kondisi berarti batal mengirim.
    if (note == null) return;

    setState(() => _sending = true);
    try {
      final result = await ref.read(apiClientProvider).createEmergencyCall(
            location: location.point,
            conditionNote: note.isEmpty ? null : note,
            guestName: guest?.name,
            guestPhone: guest?.phone,
          );

      // Tamu perlu menyambungkan socket dengan call token yang baru diterima.
      if (isGuest) {
        await ref.read(authProvider.notifier).connectAsGuest();
      }

      ref.read(activeCallProvider.notifier).track(result.call);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim SOS: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showLocationProblem() {
    final location = ref.read(locationProvider);
    final message = location is LocationDenied
        ? location.message
        : 'Sedang mencari lokasi Anda. Coba lagi sebentar.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'COBA LAGI',
          onPressed: () => ref.read(locationProvider.notifier).refresh(),
        ),
      ),
    );
  }

  Future<GuestDetails?> _askGuestDetails() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    return showModalBottomSheet<GuestDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetShell(
        title: 'Data Penelepon',
        subtitle:
            'Rumah sakit perlu cara menghubungi Anda kembali. Isi sekali saja.',
        children: [
          const FieldLabel('NAMA PENELEPON', topGap: 4),
          DispatchTextField(controller: nameCtrl, hint: 'Nama Anda'),
          const FieldLabel('NOMOR HP AKTIF'),
          DispatchTextField(
            controller: phoneCtrl,
            hint: '08xxxxxxxxxx',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          DispatchButton(
            label: 'LANJUTKAN',
            onPressed: () {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (phone.length < 8) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Nomor HP wajib diisi agar bisa dihubungi'),
                  ),
                );
                return;
              }
              Navigator.pop(
                ctx,
                GuestDetails(name.isEmpty ? 'Penelepon Darurat' : name, phone),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<String?> _askCondition() async {
    final ctrl = TextEditingController();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetShell(
        title: 'Kondisi Pasien',
        subtitle:
            'Opsional, tapi sangat membantu tim medis bersiap sebelum tiba.',
        children: [
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preset in const [
                'Serangan jantung',
                'Kecelakaan',
                'Sesak napas',
                'Pingsan',
                'Pendarahan',
                'Stroke',
              ])
                DispatchChip(
                  label: preset.toUpperCase(),
                  onTap: () => Navigator.pop(ctx, preset),
                ),
            ],
          ),
          const FieldLabel('ATAU TULIS SENDIRI'),
          DispatchTextField(
            controller: ctrl,
            hint: 'Contoh: nyeri dada hebat sejak 10 menit lalu',
            maxLines: 3,
            minLines: 2,
          ),
          const SizedBox(height: 16),
          DispatchButton(
            label: 'KIRIM SOS SEKARANG',
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          ),
          const SizedBox(height: 8),
          // String kosong = kirim tanpa catatan; null = batal.
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx, ''),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Lewati, kirim tanpa keterangan',
                  style: DispatchType.bodyStyle(
                    size: 10,
                    weight: 600,
                    color: ctx.c.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final location = ref.watch(locationProvider);
    final hospitals = ref.watch(nearestHospitalsProvider);
    final connected = ref.watch(socketConnectedProvider).value ?? false;
    final auth = ref.watch(authProvider);
    final name = auth is AuthSignedIn ? auth.user.fullName : 'Tamu';

    final nearest = hospitals.value?.firstOrNull;

    return Column(
      children: [
        BrandHeader(
          connected: connected || auth is AuthSignedOut,
          trailing: DispatchAvatar(name: name),
        ),

        // Baris lokasi — "LOKASI TERKUNCI" adalah janji inti aplikasi ini.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DispatchSpacing.screenH,
            14,
            DispatchSpacing.screenH,
            0,
          ),
          child: Row(
            children: [
              Icon(Icons.place_rounded, size: 12, color: c.vital),
              const SizedBox(width: 7),
              Text(
                switch (location) {
                  LocationReady() => 'LOKASI TERKUNCI',
                  LocationLoading() => 'MENCARI LOKASI',
                  LocationDenied() => 'LOKASI TIDAK TERSEDIA',
                },
                style: DispatchType.monoStyle(
                  size: 8.5,
                  weight: 600,
                  tracking: 0.06,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  switch (location) {
                    LocationReady(:final point) => formatCoords(point),
                    LocationLoading() => '...',
                    LocationDenied() => 'KETUK UNTUK IZINKAN',
                  },
                  style: DispatchType.monoStyle(
                    size: 10,
                    weight: 600,
                    color: location is LocationDenied ? c.amberText : c.vital,
                    tracking: 0.02,
                  ),
                ),
              ),
              if (location is! LocationReady)
                GestureDetector(
                  onTap: () => ref.read(locationProvider.notifier).refresh(),
                  child: Icon(Icons.refresh_rounded, size: 15, color: c.vital),
                ),
            ],
          ),
        ),

        // Zona SOS — tombol mengambil ruang sebanyak mungkin.
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SosHoldButton(
                  onTriggered: _triggerSos,
                  enabled: !_sending,
                ),
                const SizedBox(height: 18),
                if (_sending)
                  Text(
                    'MENGIRIM PANGGILAN DARURAT...',
                    style: DispatchType.monoStyle(
                      size: 10,
                      weight: 700,
                      tracking: 0.08,
                      color: c.siren,
                    ),
                  )
                else
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Tekan & tahan untuk\n'),
                        TextSpan(
                          text: 'memanggil bantuan darurat',
                          style: DispatchType.bodyStyle(
                            size: 10.5,
                            weight: 700,
                            color: c.textPrimary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: DispatchType.bodyStyle(
                      size: 10.5,
                      weight: 500,
                      color: c.textSecondary,
                      height: 1.6,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Readout mono — RS terdekat & estimasi respons.
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ReadoutRow(
            children: [
              ReadoutCard(
                label: 'RS TERDEKAT',
                value: nearest == null
                    ? '—'
                    : formatDistance(nearest.distanceMeters),
              ),
              ReadoutCard(
                label: 'EST. RESPON',
                value: nearest == null
                    ? '—'
                    : '~${formatDuration(nearest.durationSeconds)}',
              ),
            ],
          ),
        ),

        if (nearest != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DispatchSpacing.screenH,
              8,
              DispatchSpacing.screenH,
              0,
            ),
            child: Text(
              nearest.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: DispatchType.monoStyle(
                size: 8,
                weight: 600,
                tracking: 0.06,
                color: c.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}

class GuestDetails {
  const GuestDetails(this.name, this.phone);

  final String name;
  final String phone;
}

/// Bungkus bottom sheet bergaya Dispatch Console.
class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.isDark ? const Color(0xFF11161F) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: c.surfaceBorder),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: c.inputBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              title,
              style: DispatchType.displayStyle(
                size: 14,
                weight: 700,
                color: c.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(
                subtitle!,
                style: DispatchType.bodyStyle(
                  size: 9.5,
                  weight: 500,
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}
