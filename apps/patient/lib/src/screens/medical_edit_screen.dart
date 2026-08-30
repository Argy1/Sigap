import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/patient_providers.dart';

/// **Layar 07 — Edit Profil Medis.**
///
/// Data di layar ini bukan sekadar kelengkapan profil: isinya di-*snapshot* ke
/// dalam panggilan darurat dan tampil langsung di layar sopir sebagai
/// peringatan merah ("⚠ ALERGI PENISILIN · GOL. DARAH O+"). Karena itu alergi
/// diperlakukan sebagai daftar chip, bukan satu kotak teks bebas — daftar bisa
/// dibaca sekilas oleh orang yang sedang mengemudi.
class MedicalEditScreen extends ConsumerStatefulWidget {
  const MedicalEditScreen({super.key});

  @override
  ConsumerState<MedicalEditScreen> createState() => _MedicalEditScreenState();
}

class _MedicalEditScreenState extends ConsumerState<MedicalEditScreen> {
  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  String? _bloodType;
  List<String> _allergies = [];
  final _history = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();

  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _history.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  void _hydrate(MedicalProfile m) {
    if (_loaded) return;
    _loaded = true;
    _bloodType = m.bloodType;
    _allergies = [...m.allergies];
    _history.text = m.medicalHistory ?? '';
    _contactName.text = m.emergencyContactName ?? '';
    _contactPhone.text = m.emergencyContactPhone ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).updateMedical(
            MedicalProfile(
              bloodType: _bloodType,
              allergies: _allergies,
              medicalHistory:
                  _history.text.trim().isEmpty ? null : _history.text.trim(),
              emergencyContactName: _contactName.text.trim().isEmpty
                  ? null
                  : _contactName.text.trim(),
              emergencyContactPhone: _contactPhone.text.trim().isEmpty
                  ? null
                  : _contactPhone.text.trim(),
            ),
          );
      ref.invalidate(medicalProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil medis tersimpan')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addAllergy() async {
    final ctrl = TextEditingController();
    final c = context.c;

    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.isDark ? const Color(0xFF11161F) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DispatchRadii.panel),
        ),
        title: Text(
          'Tambah Alergi',
          style: DispatchType.displayStyle(
            size: 13,
            weight: 700,
            color: c.textPrimary,
          ),
        ),
        content: DispatchTextField(
          controller: ctrl,
          hint: 'Contoh: Penisilin',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: DispatchType.bodyStyle(
                size: 11,
                weight: 700,
                color: c.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(
              'Tambah',
              style: DispatchType.bodyStyle(
                size: 11,
                weight: 700,
                color: c.vital,
              ),
            ),
          ),
        ],
      ),
    );

    if (value != null && value.isNotEmpty && !_allergies.contains(value)) {
      setState(() => _allergies = [..._allergies, value]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final medical = ref.watch(medicalProfileProvider);

    return Scaffold(
      body: ConsoleBackground(
        child: SafeArea(
          child: medical.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Gagal memuat profil medis.\n$e',
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
            data: (m) {
              _hydrate(m);

              return Column(
                children: [
                  PageHeader(
                    title: 'Profil Medis',
                    onBack: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        DispatchSpacing.screenH,
                        6,
                        DispatchSpacing.screenH,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Penjelasan singkat kenapa data ini penting —
                          // orang mengisi form dengan lebih serius kalau tahu
                          // ke mana datanya pergi.
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: c.vitalTint,
                              borderRadius: BorderRadius.circular(
                                DispatchRadii.input,
                              ),
                              border: Border.all(color: c.vitalBorder),
                            ),
                            child: Text(
                              'Data ini otomatis terkirim ke rumah sakit dan sopir '
                              'ambulans setiap kali Anda menekan SOS.',
                              style: DispatchType.bodyStyle(
                                size: 9.5,
                                weight: 600,
                                color: c.vital,
                                height: 1.5,
                              ),
                            ),
                          ),

                          const FieldLabel('GOLONGAN DARAH'),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final bt in _bloodTypes)
                                DispatchChip(
                                  label: bt,
                                  selected: _bloodType == bt,
                                  onTap: () => setState(
                                    () => _bloodType = _bloodType == bt ? null : bt,
                                  ),
                                ),
                            ],
                          ),

                          const FieldLabel('ALERGI'),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final a in _allergies)
                                DispatchChip(
                                  label: '${a.toUpperCase()}  ✕',
                                  selected: true,
                                  onTap: () => setState(
                                    () => _allergies =
                                        _allergies.where((x) => x != a).toList(),
                                  ),
                                ),
                              DispatchChip(
                                label: '+ TAMBAH',
                                onTap: _addAllergy,
                              ),
                            ],
                          ),

                          const FieldLabel('RIWAYAT PENYAKIT (OPSIONAL)'),
                          DispatchTextField(
                            controller: _history,
                            hint: 'Hipertensi, riwayat jantung...',
                            maxLines: 4,
                            minLines: 2,
                          ),

                          const FieldLabel('KONTAK DARURAT'),
                          DispatchTextField(
                            controller: _contactName,
                            hint: 'Nama kontak',
                          ),
                          const SizedBox(height: 9),
                          DispatchTextField(
                            controller: _contactPhone,
                            hint: 'Nomor telepon',
                            keyboardType: TextInputType.phone,
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DispatchSpacing.screenH,
                      12,
                      DispatchSpacing.screenH,
                      16,
                    ),
                    child: DispatchButton(
                      label: 'SIMPAN PERUBAHAN',
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
