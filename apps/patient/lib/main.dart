import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

import 'src/app.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        // Channel Android khusus App Pasien — terpisah dari App Sopir supaya
        // mematikan notifikasi salah satu app lewat pengaturan sistem tidak
        // ikut mematikan yang satunya.
        notificationServiceProvider.overrideWithValue(
          NotificationService(
            channelId: 'sigap_patient_channel',
            channelName: 'Sigap — Status Panggilan Darurat',
          ),
        ),
        // Kunci SharedPreferences khusus App Pasien.
        notificationPrefsProvider
            .overrideWith(() => NotificationPrefsNotifier('patient')),
      ],
      child: const PatientApp(),
    ),
  );
}
