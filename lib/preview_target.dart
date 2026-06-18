import 'package:flutter/material.dart';

class PreviewPlaceholder extends StatelessWidget {
  const PreviewPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1D2E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF252840),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3D4166), width: 1.5),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF7C83FF), size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'dashboard_page.dart',
                      style: const TextStyle(
                        color: Color(0xFFE0E0FF),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Multi-file widget\nTidak bisa di-preview langsung',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF9094B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}