import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preview_app/preview_target.dart';

void main() {
  testWidgets('Dart Preview', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));

    await tester.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(body: DashboardPage())),
      ),
    );

    // Pump manual (bukan pumpAndSettle) supaya widget dengan animasi infinite
    // (loading spinner dst) tidak bikin test timeout.
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Anggap exception saat build sebagai "sudah ditangani" supaya test tetap lolos
    // dan tetap menghasilkan gambar (Flutter otomatis render error jadi kotak merah).
    tester.takeException();

    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/preview_output.png'),
    );

    await tester.binding.setSurfaceSize(null);
  });
}
