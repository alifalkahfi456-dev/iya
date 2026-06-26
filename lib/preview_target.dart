import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MemeGeneratorPage extends StatefulWidget {
  // CONSTRUCTOR CONST
  const MemeGeneratorPage({super.key});

  @override
  State<MemeGeneratorPage> createState() => _MemeGeneratorPageState();
}

class _MemeGeneratorPageState extends State<MemeGeneratorPage> {
  String? _imageUrl;
  bool _isLoading = false;

  Future<void> fetchMeme() async {
    setState(() {
      _isLoading = true;
      _imageUrl = null;
    });

    try {
      // PAKAI HEADER BIAR GAK ERROR 403
      final response = await http.get(
        Uri.parse('https://api-faa.my.id/faa/meme'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );

      // CEK APAKAH RESPONNYA GAMBAR LANGSUNG ATAU JSON
      if (response.statusCode == 200) {
        // Cek tipe konten dari header server
        String contentType = response.headers['content-type'] ?? '';

        if (contentType.contains('image')) {
          // Kalau server ngirim gambar langsung (penyebab Error JFIF tadi)
          // Kita kasih URL dengan timestamp biar gak kena cache
          setState(() {
            _imageUrl = 'https://api-faa.my.id/faa/meme?t=${DateTime.now().millisecondsSinceEpoch}';
            _isLoading = false;
          });
        } else {
          // Kalau server ngirim JSON
          final data = json.decode(response.body);
          setState(() {
            _imageUrl = data['url'] ?? data['result'];
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a0a0a),
      appBar: AppBar(
        title: const Text("MEME RED FIX"),
        backgroundColor: Colors.red[900],
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : fetchMeme,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
              ),
              child: Text(_isLoading ? "LOADING..." : "BUAT MEME"),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF2d0d0d),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.red[900]!, width: 2),
                ),
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.red)
                      : _imageUrl != null
                          ? Image.network(
                              _imageUrl!,
                              // Tambahin header di Image.network juga biar aman!
                              headers: const {
                                'User-Agent': 'Mozilla/5.0',
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  const Text("Gambar gagal tampil"),
                            )
                          : const Text("Klik tombol di atas"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}