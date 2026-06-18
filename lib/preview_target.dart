import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class AiChatPage extends StatefulWidget {
  final String username;
  
  // PERBAIKAN: Hapus 'const' jika ingin menggunakan nilai default yang dinamis
  // Atau tetap gunakan const karena "User" adalah string literal (konstan)
  const AiChatPage({super.key, this.username = "User"});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  // --- KONFIGURASI API ---
  // Masukkan HANYA KUNCI API di sini, bukan URL lengkap
  final String _apiKey = "AIzaSyDbako5aNhO-6NvqDmHJ0mqP3LmqmBXDE0"; 
  
  // --- Controllers ---
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late VideoPlayerController _videoController;

  // --- State ---
  final List<Map<String, dynamic>> _messages = [
    {
      "role": "model",
      "text": "Halo! Saya Nesvada infinity AI (Gemini Powered). Ada yang bisa saya bantu?",
      "time": "Now"
    }
  ];
   
  bool _isVideoInitialized = false;
  bool _isTyping = false; 

  // --- Colors (Neon Theme) ---
  final Color _glassBorder = Colors.white.withOpacity(0.2);
  final Color _bubbleUser = const Color(0xFF00E5FF).withOpacity(0.2); // Cyan Neon
  final Color _bubbleAi = const Color(0xFFD500F9).withOpacity(0.2);   // Purple Neon

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  void _initVideo() {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse('https://a.top4top.io/m_3680epux71.mp4'), // Background Cyberpunk
    )..initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
          _videoController.setVolume(0);
          _videoController.setLooping(true);
          _videoController.play();
        });
      });
  }

  // --- LOGIC REAL AI (GEMINI API) ---
  Future<void> _sendMessage() async {
    String text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    
    // 1. Tampilkan Pesan User
    setState(() {
      _messages.add({
        "role": "user",
        "text": text,
        "time": "Now"
      });
      _isTyping = true;
    });
    _scrollToBottom();

    // 2. Panggil API Gemini
    try {
      String reply = await _fetchGeminiResponse(text);
      
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            "role": "model",
            "text": reply,
            "time": "Now"
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            "role": "model",
            "text": "Maaf, terjadi kesalahan: $e",
            "time": "Now"
          });
        });
        _scrollToBottom();
      }
    }
  }

  Future<String> _fetchGeminiResponse(String userInput) async {
    // URL Endpoint yang BENAR (API Key digabung di sini)
    final String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey";
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": userInput}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && 
            data['candidates'].isNotEmpty && 
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null) {
              
          return data['candidates'][0]['content']['parts'][0]['text'];
        }
      } else {
        // Debugging: Cetak error jika status bukan 200
        debugPrint("Gemini Error: ${response.statusCode} - ${response.body}");
        return "Gagal mendapatkan respon (Status: ${response.statusCode}). Coba periksa koneksi atau API Key.";
      }
    } catch (e) {
      return "Error koneksi: $e";
    }
    
    return "Maaf, saya tidak mengerti.";
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // ResizeToAvoidBottomInset agar keyboard tidak menutupi input
      resizeToAvoidBottomInset: true, 
      body: Stack(
        children: [
          // 1. Background Video
          Positioned.fill(
            child: _isVideoInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  )
                : Container(color: Colors.black),
          ),

          // 2. Dark Overlay
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.7))),

          // 3. Content
          SafeArea(
            child: Column(
              children: [
                // HEADER
                _buildHeader(),

                // CHAT LIST
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return _buildChatBubble(msg, isUser);
                    },
                  ),
                ),

                // INPUT AREA
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(bottom: BorderSide(color: _glassBorder)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD500F9).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD500F9)),
                ),
                child: const Icon(Icons.psychology, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Nesvada infinity AI", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      const Text("Gemini 1.5 Flash", 
                        style: TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Nama
            if (!isUser)
              const Padding(
                padding: EdgeInsets.only(left: 5, bottom: 4),
                child: Text("Nesvada infinity AI", 
                  style: TextStyle(color: Color(0xFFD500F9), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            
            // Bubble
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? _bubbleUser : _bubbleAi,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(15),
                  topRight: const Radius.circular(15),
                  bottomLeft: Radius.circular(isUser ? 15 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 15),
                ),
                border: Border.all(
                  color: isUser ? const Color(0xFF00E5FF).withOpacity(0.3) : const Color(0xFFD500F9).withOpacity(0.3),
                  width: 1
                )
              ),
              child: SelectableText( 
                msg['text'], 
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _bubbleAi,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
            bottomRight: Radius.circular(15),
          ),
          border: Border.all(color: const Color(0xFFD500F9).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("AI Thinking", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(width: 8),
            SizedBox(
              width: 10, height: 10, 
              child: CircularProgressIndicator(color: const Color(0xFFD500F9), strokeWidth: 1.5)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            border: Border(top: BorderSide(color: _glassBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _glassBorder),
                  ),
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Tanya sesuatu ke AI...",
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isTyping ? null : _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isTyping ? Colors.grey : const Color(0xFF00E5FF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (!_isTyping)
                        BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.4), blurRadius: 10, spreadRadius: 1)
                    ]
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}