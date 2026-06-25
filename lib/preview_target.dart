import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PreviewPlaceholder extends StatelessWidget {
  const PreviewPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1D2E),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF252840),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3D4166), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C83FF).withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C83FF).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF7C83FF), size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'admin_page.dart',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFE0E0FF),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Multi-file widget',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF7C83FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kirim semua file yang di-import\nuntuk preview penuh',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF9094B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}