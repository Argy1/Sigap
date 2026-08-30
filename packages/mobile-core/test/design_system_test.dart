import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_core/mobile_core.dart';

/// Uji golden untuk elemen tanda tangan sistem desain "Dispatch Console".
///
/// Tujuannya bukan sekadar "tidak error", tapi MENGUNCI tampilan: kalau nanti
/// seseorang mengganti pulse stepper jadi stepper titik-garis biasa, atau
/// menghapus bracket reticle, uji ini gagal — bukan berlalu diam-diam.
///
/// Perbarui golden dengan sengaja:
///   flutter test --update-goldens packages/mobile-core
void main() {
  Widget harness(Widget child, {required Brightness brightness, Size? size}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildDispatchTheme(brightness),
      home: Builder(
        builder: (context) => Scaffold(
          body: ConsoleBackground(
            child: Center(
              child: SizedBox(
                width: size?.width,
                height: size?.height,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final brightness in [Brightness.dark, Brightness.light]) {
    final mode = brightness == Brightness.dark ? 'dark' : 'light';

    group('mode $mode', () {
      testWidgets('tombol SOS + bracket reticle', (tester) async {
        await tester.binding.setSurfaceSize(const Size(280, 260));
        await tester.pumpWidget(
          harness(
            SosHoldButton(onTriggered: () {}),
            brightness: brightness,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await expectLater(
          find.byType(SosHoldButton),
          matchesGoldenFile('goldens/sos_button_$mode.png'),
        );
      });

      testWidgets('pulse stepper — garis EKG', (tester) async {
        await tester.binding.setSurfaceSize(const Size(300, 180));
        await tester.pumpWidget(
          harness(
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulseStepper(status: CallStatus.enRoute),
                  SizedBox(height: 14),
                  PulseStepper(status: CallStatus.completed),
                ],
              ),
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(Column).first,
          matchesGoldenFile('goldens/pulse_stepper_$mode.png'),
        );
      });

      testWidgets('readout mono + chip status', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 200));
        await tester.pumpWidget(
          harness(
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReadoutRow(
                  children: [
                    ReadoutCard(label: 'RS TERDEKAT', value: '1.2 KM'),
                    ReadoutCard(label: 'EST. RESPON', value: '~5 MNT'),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatusChip(status: CallStatus.pending),
                    SizedBox(width: 6),
                    StatusChip(status: CallStatus.enRoute),
                    SizedBox(width: 6),
                    StatusChip(status: CallStatus.cancelled),
                  ],
                ),
              ],
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(Column).first,
          matchesGoldenFile('goldens/readouts_$mode.png'),
        );
      });

      testWidgets('peta konsol dengan pin', (tester) async {
        await tester.binding.setSurfaceSize(const Size(300, 220));
        await tester.pumpWidget(
          harness(
            const DispatchMap(
              height: 190,
              userLocation: LatLngPoint(-6.5971, 106.8060),
              markers: [
                MapMarker(
                  id: '1',
                  position: LatLngPoint(-6.5871, 106.7856),
                  label: '1',
                ),
                MapMarker(
                  id: '2',
                  position: LatLngPoint(-6.5905, 106.7965),
                  label: '2',
                  tone: MarkerTone.siren,
                ),
              ],
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(DispatchMap),
          matchesGoldenFile('goldens/console_map_$mode.png'),
        );
      });
    });
  }

  // -------------------------------------------------------------------------
  // Uji perilaku — bukan tampilan
  // -------------------------------------------------------------------------

  testWidgets('tombol SOS TIDAK terpicu oleh satu tap', (tester) async {
    var fired = false;
    await tester.binding.setSurfaceSize(const Size(280, 260));
    await tester.pumpWidget(
      harness(
        SosHoldButton(onTriggered: () => fired = true),
        brightness: Brightness.dark,
      ),
    );

    // Satu ketukan cepat — persis gerakan tidak sengaja yang harus diabaikan.
    await tester.tap(find.byType(SosHoldButton));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      fired,
      isFalse,
      reason: 'SOS tidak boleh terkirim hanya karena layar tersentuh sekali',
    );
  });

  testWidgets('tombol SOS terpicu setelah ditahan penuh', (tester) async {
    var fired = false;
    await tester.binding.setSurfaceSize(const Size(280, 260));
    await tester.pumpWidget(
      harness(
        SosHoldButton(onTriggered: () => fired = true),
        brightness: Brightness.dark,
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosHoldButton)),
    );
    // Animasi harus dimajukan bertahap: satu pump besar hanya memajukan jam
    // sekali dan tidak menjalankan seluruh siklus AnimationController.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    // Lewati juga masa pendinginan 400 ms supaya tidak ada timer tersisa.
    await tester.pump(const Duration(milliseconds: 500));

    expect(fired, isTrue, reason: 'Tahan penuh harus mengirim SOS');
  });

  test('status panggilan aktif dikenali dengan benar', () {
    expect(CallStatus.pending.isActive, isTrue);
    expect(CallStatus.enRoute.isActive, isTrue);
    expect(CallStatus.arrived.isActive, isTrue);
    expect(CallStatus.completed.isActive, isFalse);
    expect(CallStatus.cancelled.isActive, isFalse);
  });

  test('estimasi ETA klien sama dengan rumus fallback backend', () {
    // 2 km garis lurus -> 2.7 km jalan -> ~304 detik @ 32 km/jam.
    final eta = estimateEtaSeconds(2000);
    expect(eta, closeTo(304, 2));
  });

  test('format angka mengikuti gaya readout konsol', () {
    expect(formatDistance(850), '850 M');
    expect(formatDistance(1240), '1.2 KM');
    expect(formatDuration(420), '7 MNT');
    expect(formatDurationLong(420), '7 MENIT');
    expect(initials('Ahmad Ridwan'), 'AR');
    expect(formatCoords(const LatLngPoint(-6.5971, 106.806)), '-6.5971, 106.8060');
  });
}
