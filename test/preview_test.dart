import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preview_app/preview_target.dart';

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
    final originalOnError = FlutterError.onError;
    Object? capturedFlutterError;
    FlutterError.onError = (FlutterErrorDetails details) {
      capturedFlutterError ??= details.exception;
    };

    await tester.binding.setSurfaceSize(const Size(420, 900));

    bool renderedOk = false;

    try {
      await tester.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(body: ControlCenterPage())),
        ),
      );

      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      renderedOk = true;
    } catch (e, st) {
      capturedFlutterError ??= e;
      renderedOk = false;
    }

    final pendingException = tester.takeException();
    capturedFlutterError ??= pendingException;

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
      } catch (_) {}
    }

    FlutterError.onError = originalOnError;

    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/preview_output.png'),
    );

    await tester.binding.setSurfaceSize(null);
  });
}
