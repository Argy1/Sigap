import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import 'src/app.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        // Channel Android khusus App Sopir — terpisah dari App Pasien supaya
        // mematikan notifikasi salah satu app lewat pengaturan sistem tidak
        // ikut mematikan yang satunya.
        notificationServiceProvider.overrideWithValue(
          NotificationService(
            channelId: 'sigap_driver_channel',
            channelName: 'Sigap Sopir — Tugas Penjemputan',
          ),
        ),
        // Kunci SharedPreferences khusus App Sopir.
        notificationPrefsProvider
            .overrideWith(() => NotificationPrefsNotifier('driver')),
      ],
      child: const DriverApp(),
    ),
  );
}
