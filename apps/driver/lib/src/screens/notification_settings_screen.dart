import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import '../providers/driver_providers.dart';

/// **Layar Pengaturan Notifikasi — App Sopir.**
///
/// Notifikasi di sini bersifat LOKAL: hanya muncul selama aplikasi masih
/// hidup di perangkat (sedang dibuka atau di-*background*). Kalau aplikasi
/// di-*force-close* total, notifikasi tidak akan masuk — itu butuh
/// infrastruktur push (Firebase Cloud Messaging) yang sengaja tidak dibangun
/// di sini. Tombol "Tes Notifikasi" membuktikan mekanisme lokal ini
/// benar-benar berfungsi di perangkat sopir.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _busy = false;
  bool? _permissionGranted;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted =
        await ref.read(notificationServiceProvider).hasPermission();
    if (mounted) setState(() => _permissionGranted = granted);
  }

  Future<void> _enableMaster() async {
    setState(() => _busy = true);
    try {
      final granted =
          await ref.read(notificationServiceProvider).requestPermission();
      setState(() => _permissionGranted = granted);

      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Izin notifikasi ditolak. Tugas baru tetap masuk ke aplikasi, '
                'tapi tanpa notifikasi Android kalau layar sedang mati.',
              ),
            ),
          );
        }
        return;
      }

      await ref.read(notificationPrefsProvider.notifier).setMasterEnabled(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _busy = true);
    try {
      final granted =
          await ref.read(notificationServiceProvider).requestPermission();
      setState(() => _permissionGranted = granted);

      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Izin notifikasi belum diberikan — buka Pengaturan sistem '
                'untuk mengaktifkannya secara manual.',
              ),
            ),
          );
        }
        return;
      }

      await ref.read(notificationServiceProvider).show(
            id: 0,
            title: 'Sigap Sopir — Tes Notifikasi',
            body: 'Kalau Anda melihat ini, notifikasi tugas baru akan '
                'sampai dengan baik ke perangkat Anda.',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifikasi uji coba terkirim')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final prefs = ref.watch(notificationPrefsProvider);
    final prefsNotifier = ref.read(notificationPrefsProvider.notifier);

    return Scaffold(
      body: ConsoleBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                title: 'Pengaturan Notifikasi',
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
                      if (_permissionGranted == false)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: c.amberTint,
                            borderRadius:
                                BorderRadius.circular(DispatchRadii.input),
                          ),
                          child: Text(
                            'Izin notifikasi belum diberikan di pengaturan '
                            'sistem Android. Nyalakan toggle di bawah atau '
                            'tekan "Tes Notifikasi" untuk memintanya.',
                            style: DispatchType.bodyStyle(
                              size: 9.5,
                              weight: 600,
                              color: c.amberText,
                              height: 1.5,
                            ),
                          ),
                        ),

                      DispatchPanel(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Notifikasi Sigap Sopir',
                                    style: DispatchType.bodyStyle(
                                      size: 11,
                                      weight: 700,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Muncul selama aplikasi masih berjalan '
                                    'di perangkat ini',
                                    style: DispatchType.monoStyle(
                                      size: 7.5,
                                      weight: 600,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DispatchToggle(
                              value: prefs.masterEnabled,
                              onChanged: _busy
                                  ? null
                                  : (value) {
                                      if (value) {
                                        _enableMaster();
                                      } else {
                                        prefsNotifier.setMasterEnabled(false);
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      const PanelLabel('KATEGORI'),
                      const SizedBox(height: 8),

                      DispatchPanel(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Opacity(
                          opacity: prefs.masterEnabled ? 1 : 0.4,
                          child: Column(
                            children: [
                              for (final (i, category)
                                  in driverNotificationCategories.indexed)
                                _CategoryRow(
                                  category: category,
                                  value: prefs.isCategoryEnabled(category.id),
                                  enabled: prefs.masterEnabled && !_busy,
                                  last: i ==
                                      driverNotificationCategories.length - 1,
                                  onChanged: (value) => prefsNotifier
                                      .setCategoryEnabled(category.id, value),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      DispatchButton(
                        label: 'TES NOTIFIKASI',
                        icon: Icons.notifications_active_rounded,
                        loading: _busy,
                        onPressed: _busy ? null : _sendTestNotification,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Menekan tombol ini mengirim satu notifikasi contoh '
                        'segera, apa pun status kategori di atas — gunanya '
                        'membuktikan notifikasi benar-benar bisa muncul di '
                        'perangkat Anda.',
                        textAlign: TextAlign.center,
                        style: DispatchType.bodyStyle(
                          size: 9,
                          weight: 500,
                          color: c.textSecondary,
                          height: 1.6,
                        ),
                      ),
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.value,
    required this.enabled,
    required this.last,
    required this.onChanged,
  });

  final NotificationCategory category;
  final bool value;
  final bool enabled;
  final bool last;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.label,
                  style: DispatchType.bodyStyle(
                    size: 10.5,
                    weight: 700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.description,
                  style: DispatchType.bodyStyle(
                    size: 9,
                    weight: 500,
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          DispatchToggle(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
