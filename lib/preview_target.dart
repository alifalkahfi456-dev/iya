import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui';

const String baseUrl = "http://tirzzyangsukadia.serverleo.biz.id:9240";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final userController = TextEditingController();
  final passController = TextEditingController();
  bool isLoading = false;
  String? androidId;
  late VideoPlayerController _videoController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Warna utama: Merah (mengganti hijau #4ADE80)
  final Color _primaryColor = const Color(0xFFDC2626); // Warna merah yang kuat
  final Color _secondaryColor = const Color(0xFFEF4444); // Warna merah yang lebih terang
  final Color _accentColor = const Color(0xFFF87171); // Warna merah aksen

  @override
  void initState() {
    super.initState();
    initLogin();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    // Initialize video controller
    _videoController = VideoPlayerController.asset('assets/videos/login.mp4')
      ..initialize().then((_) {
        setState(() {});
        _videoController.setLooping(true);
        _videoController.play();
        _videoController.setVolume(0);
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> initLogin() async {
    androidId = await getAndroidId();

    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString("username");
    final savedPass = prefs.getString("password");
    final savedKey = prefs.getString("key");

    if (savedUser != null && savedPass != null && savedKey != null) {
      final uri = Uri.parse(
        "http://tirzzyangsukadia.serverleo.biz.id:9240/api/auth/myInfo?username=$savedUser&password=$savedPass&androidId=$androidId&key=$savedKey",
      );
      try {
        final res = await http.get(uri);
        final data = jsonDecode(res.body);

        if (data['valid'] == true) {
          Navigator.pushReplacementNamed(
            context,
            '/loader',
            arguments: {
              'username': savedUser,
              'password': savedPass,
              'role': data['role'],
              'key': data['key'],
              'expiredDate': data['expiredDate'],
              'listBug': data['listBug'] ?? [],
              'listPayload': data['listPayload'] ?? [],
              'listDDoS': data['listDDoS'] ?? [],
              'news': data['news'] ?? [],
            },
          );
        }
      } catch (_) {}
    }
  }

  Future<String> getAndroidId() async {
    final deviceInfo = DeviceInfoPlugin();
    final android = await deviceInfo.androidInfo;
    return android.id ?? "unknown_device";
  }

  Future<void> login() async {
    final username = userController.text.trim();
    final password = passController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showAlert("⚠️ Error", "Username and password are required.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final validate = await http.post(
        Uri.parse("http://tirzzyangsukadia.serverleo.biz.id:9240/api/auth/validate"),
        body: {
          "username": username,
          "password": password,
          "androidId": androidId ?? "unknown_device",
        },
      );

      final validData = jsonDecode(validate.body);

      if (validData['expired'] == true) {
        _showAlert("⛔ Access Expired", "Your access has expired.\nPlease renew it.", showContact: true);
      } else if (validData['valid'] != true) {
        _showAlert("🚫 Login Failed", "Invalid username or password.", showContact: true);
      } else {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString("username", username);
        prefs.setString("password", password);
        prefs.setString("key", validData['key']);

        Navigator.pushNamed(
          context,
          '/loader',
          arguments: {
            'username': username,
            'password': password,
            'role': validData['role'],
            'key': validData['key'],
            'expiredDate': validData['expiredDate'],
            'listBug': validData['listBug'] ?? [],
            'listPayload': validData['listPayload'] ?? [],
            'listDDoS': validData['listDDoS'] ?? [],
            'news': validData['news'] ?? [],
          },
        );
      }
    } catch (_) {
      _showAlert("🌐 Connection Error", "Failed to connect to the server.");
    }

    setState(() => isLoading = false);
  }

  void _showAlert(String title, String msg, {bool showContact = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                title.contains("Error") || title.contains("Failed")
                    ? Icons.error_outline
                    : title.contains("Expired")
                    ? Icons.timer_off
                    : Icons.info_outline,
                color: title.contains("Error") || title.contains("Failed")
                    ? Colors.redAccent
                    : title.contains("Expired")
                    ? Colors.amber
                    : _primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
              ),
            ),
          ],
        ),
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontFamily: 'ShareTechMono',
          ),
        ),
        actions: [
          if (showContact)
            TextButton.icon(
              onPressed: () async {
                final uri = Uri.parse("tg://resolve?domain=aboutnastarz");
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(Uri.parse("https://t.me/aboutnastarz"),
                      mode: LaunchMode.externalApplication);
                }
              },
              icon: Icon(Icons.message, size: 18, color: _primaryColor),
              label: Text(
                "Contact Admin Nastarz",
                style: TextStyle(
                  color: _primaryColor,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: _primaryColor.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "CLOSE",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk membuka bot Telegram
  Future<void> _openTelegramBot() async {
    final uri = Uri.parse("tg://resolve?domain=aboutnastarz");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(Uri.parse("https://t.me/aboutnastarz"),
          mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background video with blur effect
          SizedBox(
            height: double.infinity,
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.cover,
              child: _videoController.value.isInitialized
                  ? SizedBox(
                width: _videoController.value.size.width,
                height: _videoController.value.size.height,
                child: VideoPlayer(_videoController),
              )
                  : Container(color: Colors.black),
            ),
          ),
          // Gradient overlay with red accent
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.85),
                  Colors.black.withOpacity(0.95),
                ],
              ),
            ),
          ),
          // Login form
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo with animation
                      Hero(
                        tag: 'logo',
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 140,
                            width: 140,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Welcome text
                      const Text(
                        "Welcome Back",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Login to continue to your account",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontFamily: 'ShareTechMono',
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Login form container
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _neonInput("Username", userController, Icons.person),
                            const SizedBox(height: 20),
                            _neonInput("Password", passController, Icons.lock, isPassword: true),
                            const SizedBox(height: 30),

                            // Login Button with red theme
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                gradient: LinearGradient(
                                  colors: [
                                    _primaryColor.withOpacity(0.8),
                                    _secondaryColor.withOpacity(0.6),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryColor.withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: isLoading ? null : login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text(
                                  "LOGIN",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontFamily: 'Orbitron',
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Start Bot Button (replaces Buy Account)
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: _primaryColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: OutlinedButton.icon(
                          onPressed: _openTelegramBot,
                          label: Text(
                            "Buy Account",
                            style: TextStyle(
                              fontSize: 16,
                              color: _primaryColor,
                              fontFamily: 'Orbitron',
                              letterSpacing: 1.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            side: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _neonInput(String hint, TextEditingController controller, IconData icon,
      {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      cursorColor: _primaryColor,
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          color: Colors.white.withOpacity(0.7),
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontFamily: 'ShareTechMono',
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: _primaryColor.withOpacity(0.5), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    );
  }
}