import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preview_app/preview_target.dart';

// Widget fallback yang ditampilkan kalau widget asli gagal total saat
// pumpWidget pertama (constructor / initState error / dsb), supaya
// golden file TETAP ter-generate (bukan kosong/tidak ada sama sekali).
class _PreviewFatalErrorBox extends StatelessWidget {
  final String message;
  const _PreviewFatalErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFEBEE),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFB71C1C), size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Widget gagal di-render',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFB71C1C)),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF424242)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Dart Preview', (WidgetTester tester) async {
    // Tangkap error Flutter framework (assertion, dsb) supaya tidak
    // langsung melempar keluar dari testWidgets sebelum golden ke-capture.
    final originalOnError = FlutterError.onError;
    Object? capturedFlutterError;
    FlutterError.onError = (FlutterErrorDetails details) {
      capturedFlutterError ??= details.exception;
      // tidak forward ke originalOnError supaya tidak dianggap test failure
    };

    await tester.binding.setSurfaceSize(const Size(420, 900));

    bool renderedOk = false;

    // ── Percobaan 1: render widget ASLI ─────────────────────────────────
    try {
      await tester.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(body: LoginPage())),
        ),
      );

      // Pump manual (bukan pumpAndSettle) supaya widget dengan animasi
      // infinite (loading spinner dst) tidak bikin test timeout.
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      renderedOk = true;
    } catch (e, st) {
      // pumpWidget / pump gagal total (constructor, initState, dependency
      // injection, dsb melempar exception synchronous/async tak tertangani).
      capturedFlutterError ??= e;
      renderedOk = false;
    }

    // Exception yang sempat ditangkap test framework (mis. error saat build()
    // yang dirender Flutter sebagai red error box) — anggap "sudah ditangani".
    final pendingException = tester.takeException();
    capturedFlutterError ??= pendingException;

    // ── Percobaan 2: kalau render asli gagal total, render fallback box ──
    if (!renderedOk) {
      final errMsg = capturedFlutterError?.toString() ?? 'Unknown error';
      final shortMsg = errMsg.length > 500 ? errMsg.substring(0, 500) : errMsg;

      try {
        await tester.pumpWidget(
          RepaintBoundary(
            child: _PreviewFatalErrorBox(shortMsg),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      } catch (_) {
        // Kalau bahkan fallback widget ini gagal di-render (seharusnya
        // hampir mustahil karena pakai widget Flutter standar), biarkan
        // expectLater di bawah yang melempar error final.
      }
    }

    FlutterError.onError = originalOnError;

    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/preview_output.png'),
    );

    await tester.binding.setSurfaceSize(null);
  });
}
