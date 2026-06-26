// dashboard_page.dart
import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'nik_check.dart';
import 'admin_page.dart';
import 'owner_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'change_password_page.dart';
import 'tools_gateway.dart';
import 'login_page.dart';
import 'bug_sender.dart';
import 'contact_page.dart';
import 'profile_page.dart';
import 'riwayat_page.dart';
import 'info_page.dart';
import 'ucapan_page.dart';
import 'toko_page.dart';
import 'public_chat_page.dart';
import 'weather_page.dart';
import 'jadwal_sholat_page.dart';

class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const DashboardPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.listBug,
    required this.listDoos,
    required this.sessionKey,
    required this.news,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late WebSocketChannel? _channel;







  late List<dynamic> newsList;

  String androidId = "unknown";
  File? _profileImage;

  int _bottomNavIndex = 0;
  Widget _selectedPage = const SizedBox();

  int onlineUsers = 0;
  int activeConnections = 0;

  Timer? _statsTimer;
  Timer? _onlineTimer;

  // === TEMA MERAH MODERN ===
  static const Color bgDark = Color(0xFF000000);
  static const Color accentRed = Color(0xFF9E9E9E);
  static const Color darkRed = Color(0xFF212121);
  static const Color softRed = Color(0xFF424242);
  static const Color primaryWhite = Color(0xFFFFFFFF);
  static const Color softGrey = Color(0xFF9E9E9E);
  
  Color get glassPrimary => const Color(0x1AFFFFFF);
  Color get glassSecondary => const Color(0x0DFFFFFF);

  LinearGradient get redGradient => const LinearGradient(
        colors: [Color(0xFF1A1A1A), Color(0xFF424242)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get secondaryGradient => const LinearGradient(
        colors: [Color(0xFF1A1A1A), Color(0xFF424242)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    username = widget.username;
    password = widget.password;
    role = widget.role;
    expiredDate = widget.expiredDate;
    listBug = widget.listBug;
    listDoos = widget.listDoos;
    newsList = widget.news;

    _initAnimations();
    _selectedPage = _buildHomePage();

    _initAndroidIdAndConnect();
    _loadProfileImage();
    _startStatsTimer();
    
    _fetchOnlineUsers();     // Ambil data pertama kali
    _startOnlinePolling();   // Mulai polling setiap 10 detik
  }

  void _startStatsTimer() {
  _statsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
    if (_channel != null) {
      _channel?.sink.add(jsonEncode({"type": "stats"}));
    }
  });
}

// ========== TAMBAHKAN 2 FUNGSI INI ==========
Future<void> _fetchOnlineUsers() async {
  try {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/getOnlineUsers?key=$sessionKey'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['valid'] == true) {
        setState(() {
          onlineUsers = data['count'] ?? 0;
        });
        print('✅ Online Users: $onlineUsers'); // Buat debug
      }
    }
  } catch (e) {
    print('❌ Error fetching online users: $e');
  }
}

void _startOnlinePolling() {
  _onlineTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
    _fetchOnlineUsers();
  });
}

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_$username');
    if (imagePath != null && imagePath.isNotEmpty) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  Future<void> _initAndroidIdAndConnect() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    androidId = deviceInfo.id;
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    _channel = WebSocketChannel.connect(Uri.parse('$apiBaseUrl'));
    _channel?.sink.add(jsonEncode({
      "type": "validate",
      "key": sessionKey,
      "androidId": androidId,
    }));
    _channel?.sink.add(jsonEncode({"type": "stats"}));

    _channel?.stream.listen((event) {

      if (data['type'] == 'myInfo') {
        if (data['valid'] == false) {
          if (data['reason'] == 'androidIdMismatch') {
            _handleInvalidSession("Your account has logged on another device.");
          } else if (data['reason'] == 'keyInvalid') {
            _handleInvalidSession("Key is not valid. Please login again.");
          }
        }
      }
      if (data['type'] == 'stats') {
        if (!mounted) return;
        setState(() {
          onlineUsers = data['onlineUsers'] ?? 0;
          activeConnections = data['activeConnections'] ?? 0;
        });
      }
    });
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $uri");
    }
  }

  void _handleInvalidSession(String message) async {
    await Future.delayed(const Duration(milliseconds: 300));

    await prefs.clear();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: glassPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: primaryWhite.withOpacity(0.1), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Session Expired",
              style: TextStyle(
                color: accentRed,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: softGrey, fontSize: 14),
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              gradient: redGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
              child: const Text(
                "OK",
                style: TextStyle(
                  color: primaryWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _bottomNavIndex = index;
      if (index == 0) {
        _selectedPage = _buildHomePage();
      } else if (index == 1) {
        _selectedPage = HomePage(
          username: username,
          password: password,
          listBug: listBug,
          role: role,
          expiredDate: expiredDate,
          sessionKey: sessionKey,
        );
      } else if (index == 2) {
        _selectedPage = InfoPage(sessionKey: sessionKey);
      } else if (index == 3) {
        _selectedPage = ToolsPage(
  sessionKey: sessionKey,
  userRole: role,
  listDoos: listDoos,
);
      }
    });
  }

  void _onSidebarTabSelected(int index) {
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        if (index == 1) {
          _selectedPage = SellerPage(keyToken: sessionKey);
        } else if (index == 2) {
          _selectedPage = AdminPage(sessionKey: sessionKey);
        } else if (index == 3) {
          _selectedPage = OwnerPage(sessionKey: sessionKey, username: username);
        }
      });
    });
  }

  // ===================== HOME PAGE =====================
  Widget _buildHomePage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
Container(
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        accentRed.withOpacity(0.1),
        darkRed.withOpacity(0.05),
      ],
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Welcome Back Text (tanpa ShaderMask)
RichText(
  text: TextSpan(
    style: const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
      fontFamily: 'Orbitron', // <-- TAMBAHKAN INI
    ),
    children: [
      const TextSpan(
        text: "Welcome Back, ",
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Orbitron', // <-- TAMBAHKAN INI
        ),
      ),
      TextSpan(
        text: username,
        style: const TextStyle(
          color: Color(0xFF9E9E9E),
          fontFamily: 'Orbitron', // <-- TAMBAHKAN INI
        ),
      ),
    ],
  ),
),
      const SizedBox(height: 12),
      // Role Badge di bawah (sebelah kiri)
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          gradient: secondaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accentRed.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          role.toUpperCase(),
          style: const TextStyle(
            color: primaryWhite,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    ],
  ),
),

          // Stats Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildModernStatsCard(
                    icon: Icons.people_rounded,
                    label: "Online Users",
                    value: "$onlineUsers",
                    color: accentRed,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModernStatsCard(
                    icon: Icons.link_rounded,
                    label: "Active Connections",
                    value: "$activeConnections",
                    color: softRed,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Expiration Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TweenAnimationBuilder(
              duration: const Duration(milliseconds: 800),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentRed.withOpacity(0.15),
                      darkRed.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: accentRed.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentRed.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: redGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        color: primaryWhite,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Expiration Date",
                            style: TextStyle(color: softGrey, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            expiredDate,
                            style: const TextStyle(
                              color: primaryWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: redGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Text(
                        "ACTIVE",
                        style: TextStyle(
                          color: primaryWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // KODE BARU - HORIZONTAL SCROLL (BISA DIGESER)
if (newsList.isNotEmpty) ...[
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            gradient: redGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          "BERITA TERBARU",
          style: TextStyle(
            color: softGrey,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        Text(
          "${newsList.length} Artikel",
          style: TextStyle(
            color: softGrey,
            fontSize: 12,
          ),
        ),
      ],
    ),
  ),
  const SizedBox(height: 16),
  
  // HORIZONTAL SCROLL - BISA DIGESER KE KANAN/KIRI
  SizedBox(
    height: 300, // Tinggi card
    child: ListView.builder(
      scrollDirection: Axis.horizontal, // GESER HORIZONTAL
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: newsList.length,
      itemBuilder: (context, index) {
        final item = newsList[index];
        return Container(
          width: MediaQuery.of(context).size.width * 0.85,
          margin: const EdgeInsets.only(right: 16),
          child: _buildNewsCard(item, index),
        );
      },
    ),
  ),
],

          const SizedBox(height: 32),

          // Quick Actions Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: redGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "QUICK ACTIONS",
                  style: TextStyle(
                    color: softGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Quick Actions Grid
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 4,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 0.85,
    children: [
      _buildModernQuickAction(
        icon: FontAwesomeIcons.telegram,
        label: "Info Channel",
        color: const Color(0xFF0088cc), // BIRU
        onTap: () => _openUrl("https://t.me/vrnxjagagb"),
      ),
      _buildModernQuickAction(
        icon: Icons.wifi_tethering_rounded,
        label: "Bug Sender",
        color: const Color(0xFF616161), // MERAH
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BugSenderPage(
                sessionKey: sessionKey,
                username: username,
                role: role,
              ),
            ),
          );
        },
      ),
      _buildModernQuickAction(
        icon: Icons.card_giftcard_rounded,
        label: "Ucapan",
        color: const Color(0xFF9E9E9E), // KUNING
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UcapanPage(
                sessionKey: sessionKey,
                username: username,
                role: role,
              ),
            ),
          );
        },
      ),
      _buildModernQuickAction(
        icon: Icons.shopping_bag_rounded,
        label: "Toko",
        color: const Color(0xFF00695C), // TEAL
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TokoPage(),
            ),
          );
        },
      ),
      _buildModernQuickAction(
        icon: Icons.public_rounded,
        label: "Public Chat",
        color: const Color(0xFF616161), // PINK
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PublicChatPage(
                sessionKey: sessionKey,
                username: username,
                role: role,
              ),
            ),
          );
        },
      ),
      _buildModernQuickAction(
        icon: Icons.history_rounded,
        label: "Riwayat",
        color: const Color(0xFF616161), // UNGU
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RiwayatPage(
                sessionKey: sessionKey,
                role: role,
              ),
            ),
          );
        },
      ),
      _buildModernQuickAction(
        icon: Icons.wb_sunny_rounded,
        label: "Cek Cuaca",
        color: const Color(0xFF9E9E9E), // ORANYE
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WeatherPage(
                sessionKey: sessionKey,
                username: username,
              ),
            ),
          );
        },
      ),
      _buildModernQuickAction(
        icon: Icons.mosque_rounded,
        label: "Jadwal Sholat",
        color: const Color(0xFF4CAF50), // HIJAU 
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JadwalSholatPage(
                sessionKey: sessionKey,
                username: username,
              ),
            ),
          );
        },
      ),
    ],
  ),
),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ===================== NEWS CARD 16:9 =====================
  Widget _buildNewsCard(dynamic item, int index) {
    if (item == null) return const SizedBox();
    
    return GestureDetector(
      onTap: () {
        // Optional: Navigate to news detail page
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [glassPrimary, glassSecondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: primaryWhite.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gambar 16:9
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    if (item['image'] != null && item['image'].toString().isNotEmpty)
                      Image.network(
                        item['image'],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: darkRed.withOpacity(0.5),
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: primaryWhite,
                              size: 40,
                            ),
                          ),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: darkRed.withOpacity(0.3),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: accentRed,
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        color: darkRed.withOpacity(0.5),
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: primaryWhite,
                            size: 40,
                          ),
                        ),
                      ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    // Badge index
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: redGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "NEWS ${index + 1}",
                          style: const TextStyle(
                            color: primaryWhite,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? 'No Title',
                      style: const TextStyle(
                        color: primaryWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['desc'] ?? '',
                      style: TextStyle(
                        color: primaryWhite.withOpacity(0.7),
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          color: accentRed,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(item['created_at']),
                          style: TextStyle(
                            color: softGrey,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: accentRed.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accentRed.withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            "Baca",
                            style: TextStyle(
                              color: accentRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

  String _formatDate(String? dateString) {
    if (dateString == null) return "Baru saja";
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays > 0) {
        return "${diff.inDays} hari lalu";
      } else if (diff.inHours > 0) {
        return "${diff.inHours} jam lalu";
      } else if (diff.inMinutes > 0) {
        return "${diff.inMinutes} menit lalu";
      } else {
        return "Baru saja";
      }
    } catch (e) {
      return dateString;
    }
  }

  // ===================== MODERN STATS CARD =====================
  Widget _buildModernStatsCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [glassPrimary, glassSecondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryWhite.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: primaryWhite, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: softGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== MODERN QUICK ACTION =====================
  Widget _buildModernQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [glassPrimary, glassSecondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                style: TextStyle(
                  color: primaryWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== DRAWER =====================
  Widget _buildCustomDrawer() {
    return Drawer(
      backgroundColor: bgDark,
      width: MediaQuery.of(context).size.width * 0.85,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 280,
            decoration: BoxDecoration(gradient: redGradient),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryWhite, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _profileImage != null
                            ? Image.file(_profileImage!, fit: BoxFit.cover)
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: secondaryGradient,
                                ),
                                child: Icon(
                                  FontAwesomeIcons.userAstronaut,
                                  size: 45,
                                  color: primaryWhite.withOpacity(0.9),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      username,
                      style: const TextStyle(
                        color: primaryWhite,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: primaryWhite.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryWhite.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          color: primaryWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: bgDark,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  if (role == "reseller")
                    _buildGlassMenuItem(
                      icon: Icons.storefront_rounded,
                      label: "Seller Page",
                      onTap: () => _onSidebarTabSelected(1),
                    ),
                  if (role == "admin")
                    _buildGlassMenuItem(
                      icon: Icons.admin_panel_settings_rounded,
                      label: "Admin Page",
                      onTap: () => _onSidebarTabSelected(2),
                    ),
                  if (role == "owner")
                    _buildGlassMenuItem(
                      icon: Icons.workspace_premium_rounded,
                      label: "Owner Page",
                      onTap: () => _onSidebarTabSelected(3),
                    ),
                  _buildGlassMenuItem(
                    icon: Icons.history_rounded,
                    label: "Riwayat Aktivitas",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RiwayatPage(sessionKey: sessionKey, role: role),
                        ),
                      );
                    },
                  ),
                  _buildGlassMenuItem(
                    icon: Icons.send_rounded,
                    label: "Manage Sender",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BugSenderPage(
                            sessionKey: sessionKey,
                            username: username,
                            role: role,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildGlassMenuItem(
                    icon: Icons.shopping_bag_rounded,
                    label: "Toko",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TokoPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(
                    color: Colors.white10,
                    height: 32,
                    thickness: 0.5,
                  ),
                  _buildGlassMenuItem(
                    icon: Icons.logout_rounded,
                    label: "Log Out",
                    isLogout: true,
                    onTap: () async {
                      Navigator.pop(context);

                      await prefs.clear();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isLogout ? Colors.grey.withOpacity(0.1) : glassSecondary,
        borderRadius: BorderRadius.circular(16),
        border: isLogout
            ? null
            : Border.all(color: primaryWhite.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isLogout
                ? Colors.grey.withOpacity(0.15)
                : accentRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isLogout ? Colors.white70 : accentRed,
            size: 20,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isLogout ? Colors.white70 : primaryWhite,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
        trailing: isLogout
            ? null
            : Icon(Icons.chevron_right_rounded, color: softGrey, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: redGradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            "TRICT CRASHER",
            style: TextStyle(
              color: primaryWhite,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryWhite),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: glassSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: IconButton(
              icon: Icon(
                Icons.headset_mic_rounded,
                color: accentRed,
                size: 20,
              ),
              tooltip: 'Customer Service',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ContactPage()),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: glassSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: IconButton(
              icon: Icon(
                FontAwesomeIcons.circleUser,
                color: accentRed,
                size: 20,
              ),
              tooltip: 'My Profile',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(
                      username: username,
                      password: password,
                      role: role,
                      expiredDate: expiredDate,
                      sessionKey: sessionKey,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      drawer: _buildCustomDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _selectedPage,
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: glassPrimary,
          border: Border(
            top: BorderSide(color: primaryWhite.withOpacity(0.08)),
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          selectedItemColor: accentRed,
          unselectedItemColor: softGrey,
          currentIndex: _bottomNavIndex,
          onTap: _onBottomNavTapped,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.whatsapp),
              label: "WhatsApp",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_active_rounded),
              label: "Info",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.build_rounded),
              label: "Tools",
            ),
          ],
        ),
      ),
    );
  }

  @override
void dispose() {
  _statsTimer?.cancel();
  _onlineTimer?.cancel();  // <-- TAMBAHKAN INI
  _channel?.sink.close(status.goingAway);
  _animationController.dispose();
  super.dispose();
 }
}
 
// ===================== GRID PAINTER =====================
class _GridPainter extends CustomPainter {


  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const gridSize = 30.0;

    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final accentPaint = Paint()
      ..color = accentRed.withOpacity(0.08)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (double x = 0; x <= size.width; x += gridSize * 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), accentPaint);
    }

    for (double y = 0; y <= size.height; y += gridSize * 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
 }

// change_password_page.dart

class ChangePasswordPage extends StatefulWidget {



  const ChangePasswordPage({
    super.key,
    required this.username,
    required this.sessionKey,
  });

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final oldPassCtrl = TextEditingController();
  final newPassCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  bool isLoading = false;
  bool _obscurePassword = true;

  // --- MODERN RED THEME (sama dengan dashboard) ---










  Future<void> _changePassword() async {
    final oldPass = oldPassCtrl.text.trim();
    final newPass = newPassCtrl.text.trim();
    final confirmPass = confirmPassCtrl.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showMessage("Semua field harus diisi.");
      return;
    }

    if (newPass != confirmPass) {
      _showMessage("Password baru tidak cocok dengan konfirmasi.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("$apiBaseUrl/changepass"),
        body: {
          "username": widget.username,
          "oldPass": oldPass,
          "newPass": newPass,
          "sessionKey": widget.sessionKey,
        },
      );


      if (data['success'] == true) {
        _showMessage("Password berhasil diubah!", isSuccess: true);
        oldPassCtrl.clear();
        newPassCtrl.clear();
        confirmPassCtrl.clear();
      } else {
        _showMessage(data['message'] ?? "Gagal mengubah password");
      }
    } catch (e) {
      _showMessage("Koneksi error: $e");
    }

    setState(() => isLoading = false);
  }

  void _showMessage(String msg, {bool isSuccess = false}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bgDark, bgDark.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: accentRed.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: redGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle : Icons.warning_rounded,
                    color: primaryWhite,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isSuccess ? "Sukses" : "Peringatan",
                  style: const TextStyle(
                    color: primaryWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: softGrey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: redGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "OK",
                          style: TextStyle(
                            color: primaryWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon, [bool isPassword = false]) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: glassSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryWhite.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        style: const TextStyle(color: primaryWhite, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: softGrey),
          prefixIcon: Icon(icon, color: accentRed, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: softGrey,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: redGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Text(
            "CHANGE PASSWORD",
            style: TextStyle(
              color: primaryWhite,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: glassSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: accentRed, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Header Icon
                Center(
                  child: TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(scale: value, child: child),
                      );
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: redGradient,
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.lock_reset_rounded, color: primaryWhite, size: 50),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => redGradient.createShader(bounds),
                    child: const Text(
                      "SECURITY UPDATE",
                      style: TextStyle(
                        color: primaryWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    "Masukkan password lama dan baru",
                    style: TextStyle(
                      color: softGrey,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Input Fields
                _buildInput(oldPassCtrl, "Old Password", Icons.lock_outline_rounded, true),
                _buildInput(newPassCtrl, "New Password", Icons.vpn_key_rounded, true),
                _buildInput(confirmPassCtrl, "Confirm Password", Icons.enhanced_encryption_rounded, true),

                const SizedBox(height: 30),

                // Submit Button
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 500),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: GestureDetector(
                      onTap: isLoading ? null : _changePassword,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: redGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: primaryWhite,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_reset_rounded, color: primaryWhite, size: 20),
                                    SizedBox(width: 12),
                                    Text(
                                      "UPDATE PASSWORD",
                                      style: TextStyle(
                                        color: primaryWhite,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Grid Painter for background


// bug_sender.dart

class BugSenderPage extends StatefulWidget {




  const BugSenderPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<BugSenderPage> createState() => _BugSenderPageState();
}

class _BugSenderPageState extends State<BugSenderPage>
    with SingleTickerProviderStateMixin {



  List<dynamic> senderList = [];

  bool isRefreshing = false;
  String? errorMessage;

  // --- MODERN RED THEME (SAMA DENGAN DASHBOARD) ---











  bool get canAddGlobal =>
      ["owner", "developer"].contains(widget.role.toLowerCase());

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchSenders();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchSenders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {


      if (res.statusCode == 200 && data["valid"] == true) {
        final connections = data["connections"] as List<dynamic>? ?? [];
        connections.sort((a, b) {
          final ag = a["isGlobal"] == true ? 0 : 1;
          final bg = b["isGlobal"] == true ? 0 : 1;
          if (ag != bg) return ag.compareTo(bg);
          return (a["sessionName"] ?? "").toString().compareTo(
                (b["sessionName"] ?? "").toString(),
              );
        });
        setState(() => senderList = connections);
      } else {
        setState(
          () => errorMessage = data["message"] ?? "Failed to fetch senders",
        );
      }
    } catch (e) {
      setState(() => errorMessage = "Connection failed: $e");
    } finally {
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
    }
  }

  Future<void> _refreshSenders() async {
    setState(() => isRefreshing = true);
    await _fetchSenders();
  }

  Future<void> _addSender(String number, bool isGlobal) async {
    setState(() => isLoading = true);
    try {


      if (res.statusCode == 200 && data["valid"] == true) {
        _showPairingDialog(number, data["pairingCode"].toString());
        _showSnackBar("Pairing code generated!", false);
      } else {
        _showSnackBar(data["message"] ?? "Failed to generate pairing code", true);
      }
    } catch (e) {
      _showSnackBar("Connection failed: $e", true);
    } finally {
      setState(() => isLoading = false);
      await _fetchSenders();
    }
  }

  Future<void> _deleteSender(String id, bool isGlobal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _buildDeleteDialog(isGlobal),
    );
    if (ok != true) return;

    setState(() => isLoading = true);
    try {


      if (res.statusCode == 200 && data["valid"] == true) {
        _showSnackBar("Sender deleted successfully!", false);
        await _fetchSenders();
      } else {
        _showSnackBar(data["message"] ?? "Failed to delete sender", true);
      }
    } catch (e) {
      _showSnackBar("Connection failed: $e", true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildDeleteDialog(bool isGlobal) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: TweenAnimationBuilder(
        duration: const Duration(milliseconds: 300),
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, double scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bgDark, bgDark.withOpacity(0.95)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.white70, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                "Confirm Delete",
                style: TextStyle(
                  color: primaryWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isGlobal
                    ? "Global sender ini akan dihapus untuk semua user. This action cannot be undone."
                    : "Are you sure you want to delete this sender? This action cannot be undone.",
                style: const TextStyle(color: softGrey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: const Center(
                          child: Text(
                            "CANCEL",
                            style:
                                TextStyle(color: softGrey, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: const Center(
                          child: Text(
                            "DELETE",
                            style: TextStyle(
                                color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog() {
    final phoneController = TextEditingController();
    bool isGlobal = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: TweenAnimationBuilder(
                duration: const Duration(milliseconds: 300),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [bgDark, bgDark.withOpacity(0.95)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: accentRed.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: redGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(0.4),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.phone_android,
                            color: primaryWhite, size: 28),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Add New Sender",
                        style: TextStyle(
                          color: primaryWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Enter phone number to add new WhatsApp sender",
                        style: TextStyle(color: softGrey, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: glassSecondary,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryWhite.withOpacity(0.1)),
                        ),
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: primaryWhite, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: "62xxxxxxxxxx",
                            hintStyle: TextStyle(color: softGrey.withOpacity(0.5)),
                            prefixIcon:
                                const Icon(Icons.phone, color: accentRed, size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                          ),
                        ),
                      ),
                      if (canAddGlobal) ...[
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: glassSecondary,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: primaryWhite.withOpacity(0.1)),
                          ),
                          child: SwitchListTile(
                            value: isGlobal,
                            onChanged: (v) => setLocal(() => isGlobal = v),
                            title: const Text(
                              "Global Sender",
                              style: TextStyle(color: primaryWhite),
                            ),
                            subtitle: const Text(
                              "Tambah global sender untuk semua role",
                              style: TextStyle(color: softGrey, fontSize: 12),
                            ),
                            activeColor: accentRed,
                            inactiveThumbColor: Colors.grey,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.1)),
                                ),
                                child: const Center(
                                  child: Text(
                                    "CANCEL",
                                    style: TextStyle(
                                        color: softGrey, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final number = phoneController.text.trim();
                                if (number.isEmpty) {
                                  _showSnackBar("Please enter phone number", true);
                                  return;
                                }
                                if (isGlobal && !canAddGlobal) {
                                  _showSnackBar(
                                    "Hanya owner & developer yang dapat menambahkan Global Sender.",
                                    true,
                                  );
                                  return;
                                }
                                Navigator.pop(context);
                                await _addSender(number, isGlobal);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: redGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentRed.withOpacity(0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    "ADD SENDER",
                                    style: TextStyle(
                                        color: primaryWhite, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPairingDialog(String number, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bgDark, bgDark.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: accentRed.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: accentRed.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: redGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.qr_code_2, color: primaryWhite, size: 32),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Pairing Required",
                  style: TextStyle(
                    color: primaryWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Number: $number",
                  style: const TextStyle(color: softGrey, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentRed.withOpacity(0.1), darkRed.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentRed.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Pairing Code",
                        style: TextStyle(color: softGrey, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: accentRed, width: 2),
                        ),
                        child: SelectableText(
                          code,
                          style: const TextStyle(
                            color: accentRed,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: code));
                          _showSnackBar("Code copied to clipboard!", false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: accentRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accentRed.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.copy, color: accentRed, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                "COPY CODE",
                                style: TextStyle(
                                    color: accentRed, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Center(
                            child: Text(
                              "CLOSE",
                              style: TextStyle(
                                  color: softGrey, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _refreshSenders();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: redGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: accentRed.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "REFRESH",
                              style: TextStyle(
                                  color: primaryWhite, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String msg, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: primaryWhite,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: primaryWhite, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.grey.withOpacity(0.9) : accentRed.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildSenderCard(Map<String, dynamic> sender, int index) {
    final name = sender["sessionName"] ?? "WhatsApp Sender";
    final id = (sender["id"] ?? name).toString();
    final isGlobal = sender["isGlobal"] == true;
    final canDelete = sender["canDelete"] != false;
    final isEven = index % 2 == 0;

    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isEven
                ? [glassPrimary, glassSecondary]
                : [glassSecondary, glassPrimary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryWhite.withOpacity(0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: redGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentRed.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      isGlobal ? Icons.public : Icons.phone_android,
                      color: primaryWhite,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: primaryWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "ID: $id",
                          style: const TextStyle(color: softGrey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isGlobal ? accentRed : darkRed).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: (isGlobal ? accentRed : darkRed).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: accentRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isGlobal ? "GLOBAL" : "PRIVATE",
                          style: TextStyle(
                            color: isGlobal ? accentRed : darkRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _refreshSenders,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: accentRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: accentRed.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.refresh, color: accentRed, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              "REFRESH",
                              style: TextStyle(
                                  color: accentRed, fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: canDelete ? () => _deleteSender(id, isGlobal) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: canDelete
                              ? Colors.grey.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: canDelete
                                ? Colors.grey.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              canDelete ? Icons.delete_outline : Icons.lock_outline,
                              color: canDelete ? Colors.white70 : softGrey,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              canDelete ? "DELETE" : "LOCKED",
                              style: TextStyle(
                                color: canDelete ? Colors.white70 : softGrey,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [glassPrimary, glassSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryWhite.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: redGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline, color: primaryWhite, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Global sender hanya bisa ditambah owner/developer, tapi semua role bisa memakai global sender.",
              style: TextStyle(color: softGrey, fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: TweenAnimationBuilder(
        duration: const Duration(milliseconds: 600),
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, double value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentRed.withOpacity(0.1), darkRed.withOpacity(0.1)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentRed.withOpacity(0.2)),
                ),
                child: const Icon(Icons.phone_iphone, color: accentRed, size: 70),
              ),
              const SizedBox(height: 28),
              const Text(
                "No Senders Found",
                style: TextStyle(
                    color: primaryWhite, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Add your first WhatsApp sender to get started",
                style: TextStyle(color: softGrey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              GestureDetector(
                onTap: _showAddDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: redGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: primaryWhite, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        "ADD NEW SENDER",
                        style: TextStyle(
                          color: primaryWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.white70, size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              "Failed to Load",
              style: TextStyle(
                  color: primaryWhite, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage ?? "Unknown error occurred",
              style: const TextStyle(color: softGrey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _refreshSenders,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: redGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: accentRed.withOpacity(0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh, color: primaryWhite, size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      "TRY AGAIN",
                      style: TextStyle(
                        color: primaryWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: glassSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: accentRed, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            gradient: redGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Text(
            "BUG SENDER",
            style: TextStyle(
              color: primaryWhite,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: glassSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: IconButton(
              icon: AnimatedRotation(
                turns: isRefreshing ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: const Icon(Icons.refresh, color: accentRed, size: 20),
              ),
              onPressed: isLoading ? null : _refreshSenders,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              gradient: redGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: primaryWhite, size: 20),
              onPressed: _showAddDialog,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: isLoading && senderList.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: accentRed,
                      strokeWidth: 3,
                    ),
                  )
                : errorMessage != null && senderList.isEmpty
                ? _buildErrorState()
                : Column(
                    children: [
                      _buildInfoBanner(),
                      Expanded(
                        child: senderList.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                color: accentRed,
                                backgroundColor: glassSecondary,
                                onRefresh: _refreshSenders,
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: senderList.length,
                                  itemBuilder: (context, index) => _buildSenderCard(
                                    Map<String, dynamic>.from(senderList[index]),
                                    index,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// Custom Grid Painter for background


// admin_page.dart

class AdminPage extends StatefulWidget {


  const AdminPage({super.key, required this.sessionKey});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {

  List<dynamic> fullUserList = [];
  List<dynamic> filteredList = [];

  // Role Options: Hanya Reseller & Member
  final List<String> roleOptions = ['reseller', 'member'];
  String selectedRole = 'member';

  int currentPage = 1;
  int itemsPerPage = 25;

  final deleteController = TextEditingController();
  final createUsernameController = TextEditingController();
  final createPasswordController = TextEditingController();
  final createDayController = TextEditingController();
  String newUserRole = 'member';


  // --- MODERN RED THEME (sama dengan dashboard) ---







  static const Color deleteRed = Color(0xFF757575);


  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {


      if (data['valid'] == true && data['authorized'] == true) {
        fullUserList = data['users'] ?? [];
        _filterAndPaginate();
      } else {
        _alert(
          "⚠️ Error",
          data['message'] ?? 'Tidak diizinkan melihat daftar user.',
        );
      }
    } catch (_) {
      _alert("🌐 Error", "Gagal memuat user list.");
    }
    setState(() => isLoading = false);
  }

  void _filterAndPaginate() {
    setState(() {
      currentPage = 1;
      filteredList = fullUserList
          .where((u) => u['role'] == selectedRole)
          .toList();
    });
  }

  List<dynamic> _getCurrentPageData() {
    final start = (currentPage - 1) * itemsPerPage;
    final end = (start + itemsPerPage);
    return filteredList.sublist(
      start,
      end > filteredList.length ? filteredList.length : end,
    );
  }

  int get totalPages => (filteredList.length / itemsPerPage).ceil();

  Future<void> _deleteUser() async {

    if (username.isEmpty) {
      _alert("⚠️ Error", "Masukkan username yang ingin dihapus.");
      return;
    }

    setState(() => isLoading = true);
    try {


      if (data['deleted'] == true) {
        _alert(
          "✅ Berhasil",
          "User '${data['user']['username']}' telah dihapus.",
        );
        deleteController.clear();
        _fetchUsers();
      } else {
        _alert("❌ Gagal", data['message'] ?? 'Gagal menghapus user.');
      }
    } catch (_) {
      _alert("🌐 Error", "Tidak dapat menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  Future<void> _createAccount() async {


    final day = createDayController.text.trim();

    if (username.isEmpty || password.isEmpty || day.isEmpty) {
      _alert("⚠️ Error", "Semua field wajib diisi.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
        '$apiBaseUrl/userAdd?key=$sessionKey&username=$username&password=$password&day=$day&role=$newUserRole',
      );



      if (data['created'] == true) {
        _alert(
          "✅ Sukses",
          "Akun '${data['user']['username']}' berhasil dibuat.",
        );
        createUsernameController.clear();
        createPasswordController.clear();
        createDayController.clear();
        newUserRole = 'member';
        _fetchUsers();
      } else {
        _alert("❌ Gagal", data['message'] ?? 'Gagal membuat akun.');
      }
    } catch (_) {
      _alert("🌐 Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  void _alert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bgDark, bgDark.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: accentRed.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: redGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Icon(
                    title.contains("Berhasil") || title.contains("Sukses")
                        ? Icons.check_circle
                        : Icons.warning_rounded,
                    color: primaryWhite,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: primaryWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: softGrey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: redGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "OK",
                          style: TextStyle(
                            color: primaryWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: glassSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryWhite.withOpacity(0.1)),
        ),
        child: TextField(
          controller: controller,
          keyboardType: type,
          style: const TextStyle(color: primaryWhite),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: softGrey),
            prefixIcon: Icon(icon, color: accentRed, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: glassPrimary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryWhite.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: accentRed.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: redGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: primaryWhite, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: primaryWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildUserItem(Map user, int index) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: glassSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryWhite.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: redGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentRed.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                user['username'][0].toUpperCase(),
                style: const TextStyle(
                  color: primaryWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['username'],
                    style: const TextStyle(
                      color: primaryWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accentRed.withOpacity(0.3)),
                        ),
                        child: Text(
                          user['role'].toString().toUpperCase(),
                          style: TextStyle(
                            color: accentRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        "Exp: ${user['expiredDate']}",
                        style: const TextStyle(color: softGrey, fontSize: 11),
                      ),
                      Text(
                        "Parent: ${user['parent'] ?? 'SYSTEM'}",
                        style: const TextStyle(color: softGrey, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 300),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, double scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [bgDark, bgDark.withOpacity(0.95)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: deleteRed.withOpacity(0.3), width: 1.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: deleteRed.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: deleteRed.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.warning_amber_rounded, color: deleteRed, size: 32),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Konfirmasi Hapus",
                              style: TextStyle(
                                color: primaryWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Hapus user '${user['username']}'?",
                              style: const TextStyle(color: softGrey, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context, false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "BATAL",
                                          style: TextStyle(color: softGrey, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context, true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: deleteRed.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: deleteRed.withOpacity(0.3)),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "HAPUS",
                                          style: TextStyle(color: deleteRed, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                if (confirm == true) {
                  deleteController.text = user['username'];
                  _deleteUser();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: deleteRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: deleteRed.withOpacity(0.2)),
                ),
                child: Icon(Icons.delete_outline, color: deleteRed, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(totalPages, (index) {
        final page = index + 1;
        return GestureDetector(
          onTap: () => setState(() => currentPage = page),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: currentPage == page ? redGradient : null,
              color: currentPage == page ? null : glassSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: currentPage == page ? accentRed : primaryWhite.withOpacity(0.1),
              ),
            ),
            child: Text(
              "$page",
              style: TextStyle(
                color: currentPage == page ? primaryWhite : softGrey,
                fontSize: 12,
                fontWeight: currentPage == page ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(scale: value, child: child),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: redGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accentRed.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.admin_panel_settings,
                              color: primaryWhite,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShaderMask(
                          shaderCallback: (bounds) => redGradient.createShader(bounds),
                          child: const Text(
                            "ADMIN DASHBOARD",
                            style: TextStyle(
                              color: primaryWhite,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // DELETE USER CARD
                  _buildGlassCard(
                    title: "DELETE USER",
                    icon: FontAwesomeIcons.userSlash,
                    children: [
                      _buildInput(
                        label: "Username Target",
                        controller: deleteController,
                        icon: FontAwesomeIcons.user,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
        colors: [Color(0xFF1A1A1A), Color(0xFF424242)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: deleteRed.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _deleteUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete, size: 18, color: primaryWhite),
                              SizedBox(width: 8),
                              Text(
                                "DELETE ACCOUNT",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // CREATE ACCOUNT CARD
                  _buildGlassCard(
                    title: "CREATE ACCOUNT",
                    icon: FontAwesomeIcons.userPlus,
                    children: [
                      _buildInput(
                        label: "Username",
                        controller: createUsernameController,
                        icon: FontAwesomeIcons.user,
                      ),
                      _buildInput(
                        label: "Password",
                        controller: createPasswordController,
                        icon: FontAwesomeIcons.lock,
                      ),
                      _buildInput(
                        label: "Durasi (Hari)",
                        controller: createDayController,
                        icon: FontAwesomeIcons.calendarDay,
                        type: TextInputType.number,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: glassSecondary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryWhite.withOpacity(0.1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: newUserRole,
                            dropdownColor: bgDark,
                            style: const TextStyle(color: primaryWhite),
                            items: roleOptions.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role.toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => newUserRole = val ?? 'member'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: redGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _createAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryWhite,
                                  ),
                                )
                              : const Text(
                                  "CREATE ACCOUNT",
                                  style: TextStyle(
                                    color: primaryWhite,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),

                  // USER MANAGEMENT CARD
                  _buildGlassCard(
                    title: "USER MANAGEMENT",
                    icon: FontAwesomeIcons.users,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: glassSecondary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryWhite.withOpacity(0.1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRole,
                            dropdownColor: bgDark,
                            style: const TextStyle(color: primaryWhite),
                            items: roleOptions.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role.toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                selectedRole = val;
                                _filterAndPaginate();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: accentRed,
                                strokeWidth: 3,
                              ),
                            )
                          : Column(
                              children: [
                                ..._getCurrentPageData()
                                    .asMap()
                                    .entries
                                    .map((entry) => _buildUserItem(entry.value, entry.key))
                                    .toList(),
                                const SizedBox(height: 16),
                                _buildPagination(),
                              ],
                            ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Grid Painter for background


const String apiBaseUrl = "http://vrnxampas.cloudpanellvip.biz.id:10831";

// contact_page.dart

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  // --- MODERN RED THEME (sama dengan dashboard) ---










  Future<void> _launchUrl(String url) async {

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: redGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Text(
            "CUSTOMER SERVICE",
            style: TextStyle(
              color: primaryWhite,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: glassSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: accentRed, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header Icon dengan animasi
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(scale: value, child: child),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: redGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        size: 48,
                        color: primaryWhite,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Welcome Text
                  ShaderMask(
                    shaderCallback: (bounds) => redGradient.createShader(bounds),
                    child: const Text(
                      "Need Help?",
                      style: TextStyle(
                        color: primaryWhite,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Contact us through our social media platforms below.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: softGrey,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Contact Buttons dengan animasi
                  Column(
                    children: [
                      _buildContactButton(
                        label: "Telegram",
                        icon: FontAwesomeIcons.telegram,
                        color: const Color(0xFF0088cc),
                        url: "https://t.me/healthVelvet",
                        delay: 0,
                      ),
                      const SizedBox(height: 14),
                      _buildContactButton(
                        label: "WhatsApp",
                        icon: FontAwesomeIcons.whatsapp,
                        color: const Color(0xFF25D366),
                        url: "https://wa.me/+6282125892590",
                        delay: 100,
                      ),
                      const SizedBox(height: 14),
                      _buildContactButton(
                        label: "TikTok",
                        icon: FontAwesomeIcons.tiktok,
                        color: primaryWhite,
                        url: "https://tiktok.com/@acap4775",
                        delay: 200,
                      ),
                      const SizedBox(height: 14),
                      _buildContactButton(
                        label: "Instagram",
                        icon: FontAwesomeIcons.instagram,
                        color: const Color(0xFF616161),
                        url: "https://www.instagram.com",
                        delay: 300,
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: redGradient,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "TRICT CRASHER ",
                          style: TextStyle(
                            color: softGrey.withOpacity(0.5),
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 40,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: redGradient,
                          ),
                        ),
                      ],
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

  Widget _buildContactButton({
    required String label,
    required IconData icon,
    required Color color,
    required String url,
    required int delay,
  }) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + delay),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _launchUrl(url),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: glassPrimary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryWhite.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: FaIcon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Text(
                    label,
                    style: const TextStyle(
                      color: primaryWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: accentRed,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Grid Painter for background


// info_page.dart

class InfoPage extends StatefulWidget {


  const InfoPage({super.key, required this.sessionKey});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  Map<String, dynamic>? serverInfo;


  bool isApiOnline = false;
  int apiPingMs = 0;
  Color apiStatusColor = Colors.grey;
  String apiStatusText = "Checking...";
  Timer? _pingTimer;

  // --- MODERN RED THEME (sama dengan dashboard) ---








  static const Color warningColor = Color(0xFFF59E0B);


  @override
  void initState() {
    super.initState();
    _fetchServerInfo();
    _startApiPingLoop();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchServerInfo() async {
    try {

      if (res.statusCode == 200) {
        setState(() {
          serverInfo = jsonDecode(res.body);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _startApiPingLoop() {
    _checkApiPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkApiPing();
    });
  }

  Future<void> _checkApiPing() async {

    try {


      final duration = end.difference(start).inMilliseconds;

      if (res.statusCode == 200) {
        setState(() {
          isApiOnline = true;
          apiPingMs = duration;
          if (duration < 200) {
            apiStatusColor = Colors.greenAccent;
          } else if (duration < 500) {
            apiStatusColor = Colors.amber;
          } else {
            apiStatusColor = Colors.orangeAccent;
          }
          apiStatusText = "Online (${duration}ms)";
        });
      } else {
        throw Exception("Failed");
      }
    } catch (e) {
      setState(() {
        isApiOnline = false;
        apiPingMs = 0;
        apiStatusColor = accentRed;
        apiStatusText = "Offline";
      });
    }
  }

@override
Widget build(BuildContext context) {
  if (isLoading) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: CircularProgressIndicator(color: accentRed, strokeWidth: 3),
      ),
    );
  }
  
    final List<Map<String, String>> rulesList = [
      {"title": "Larangan Barter Akun", "desc": "Akun tidak boleh ditukar dengan barang, jasa, atau akun lain dalam bentuk apa pun."},
      {"title": "Larangan Membagikan Akun", "desc": "Setiap akun bersifat pribadi dan hanya boleh digunakan oleh pemilik akun yang terdaftar."},
      {"title": "Larangan Menjual Akun", "desc": "Member TIDAK diperbolehkan menjual akun. Penjualan akun hanya boleh dilakukan oleh role yang diizinkan secara resmi."},
      {"title": "Larangan Jual Durasi Ilegal", "desc": "Dilarang menjual akses harian, mingguan, trial, atau sejenisnya di luar ketentuan yang telah ditetapkan."},
      {"title": "Larangan Banting Harga", "desc": "Dilarang merusak atau menurunkan harga yang telah ditentukan (banting harga) di bawah ketentuan TRICT CRASHER."},
      {"title": "Larangan Spam & Toxic", "desc": "Dilarang melakukan spam, toxic, atau menyebarkan konten negatif yang dapat mengganggu kenyamanan pengguna lain."},
    ];

    return Scaffold(
    backgroundColor: bgDark,
    appBar: null,
    body: Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.5,
          colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _GridPainter(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: Column(
            children: [
              _buildStatusCard(),
              const SizedBox(height: 24),
              _buildRulesList(rulesList),
              const SizedBox(height: 24),
              _buildSanctionCard(),
              const SizedBox(height: 20),
              _buildDisclaimerFooter(),
            ],
          ),
        ),
      ),
    ),
  );
}

  // ==================== STATUS CARD ====================
  Widget _buildStatusCard() {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: glassPrimary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryWhite.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: accentRed.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: redGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentRed.withOpacity(0.4),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: const Icon(Icons.dns_rounded, color: primaryWhite, size: 28),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: apiStatusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: apiStatusColor.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "SERVER STATUS",
                  style: TextStyle(
                    color: softGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              apiStatusText.toUpperCase(),
              style: TextStyle(
                color: apiStatusColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 16),

            Container(
              height: 1,
              color: primaryWhite.withOpacity(0.08),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, size: 14, color: softGrey),
                const SizedBox(width: 6),
                Text(
                  "Protected by TRICT CRASHERSecurity",
                  style: TextStyle(color: softGrey, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== RULES LIST (1 KOLOM, HORIZONTAL FULL) ====================
  Widget _buildRulesList(List<Map<String, String>> rulesList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: redGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "RULES & REGULATIONS",
              style: TextStyle(
                color: primaryWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accentRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentRed.withOpacity(0.3)),
              ),
              child: Text(
                "${rulesList.length} RULES",
                style: TextStyle(
                  color: accentRed,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ListView builder untuk rules (1 kolom, memanjang horizontal)
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rulesList.length,
          itemBuilder: (context, index) {
            final rule = rulesList[index];
            return TweenAnimationBuilder(
              duration: Duration(milliseconds: 300 + (index * 50)),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: glassPrimary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryWhite.withOpacity(0.08)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: redGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "${index + 1}",
                          style: const TextStyle(
                            color: primaryWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rule['title']!,
                            style: const TextStyle(
                              color: primaryWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            rule['desc']!,
                            style: TextStyle(
                              color: softGrey,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.gavel_rounded,
                      color: accentRed.withOpacity(0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ==================== SANKSI CARD ====================
  Widget _buildSanctionCard() {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              warningColor.withOpacity(0.08),
              warningColor.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: warningColor.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: warningColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: warningColor.withOpacity(0.3)),
              ),
              child: Icon(Icons.gavel_rounded, color: warningColor, size: 32),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SANKSI",
                    style: TextStyle(
                      color: primaryWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Akun akan dihapus secara permanen!",
                    style: TextStyle(
                      color: warningColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tidak ada toleransi / refund",
                    style: TextStyle(
                      color: softGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FOOTER DISCLAIMER ====================
  Widget _buildDisclaimerFooter() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: glassSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryWhite.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.info_outline_rounded, color: accentRed, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "By using this application, you agree to all the terms and regulations above.",
                  style: TextStyle(
                    color: softGrey,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Container(
          width: 60,
          height: 2,
          decoration: BoxDecoration(
            gradient: redGradient,
            borderRadius: BorderRadius.circular(1),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          "TRICT CRASHER ",
          style: TextStyle(
            color: softGrey.withOpacity(0.5),
            fontSize: 9,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// Custom Grid Painter for background


// home_page.dart

class HomePage extends StatefulWidget {







  const HomePage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listBug,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController targetController = TextEditingController();
  late final AnimationController _pulseController;
  String selectedBugId = "";
  String _selectedBugMode = "number";
  bool isSending = false;
  String? responseMessage;

  // Sender Type Selection
  String _selectedSenderType = "private";
  List<String> activeSenders = [];
  bool _isLoadingSenders = false;
  String? _senderError;

  // Video Player
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool isVideoInitialized = false;

  // Warna tema MERAH MODERN (sama dengan dashboard)

  static const Color cardDark = Color(0xFF111111);



  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFF757575);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color liveGreen = Color(0xFF22C55E);



  LinearGradient get primaryGradient => const LinearGradient(
        colors: [Color(0xFF1A1A1A), Color(0xFF424242)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );


  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (widget.listBug.isNotEmpty) {
      selectedBugId = widget.listBug[0]['bug_id'];
    }

    _initializeVideoPlayer();
    _fetchActiveSenders();
  }

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.asset('assets/videos/banner.mp4');

    _videoController.initialize().then((_) {
      if (mounted) {
        setState(() {
          _videoController.setVolume(0.5); // SUARA DIHIDUPKAN (volume 0.5)
          _chewieController = ChewieController(
            videoPlayerController: _videoController,
            autoPlay: true,
            looping: true,
            showControls: false,
            autoInitialize: true,
          );
          isVideoInitialized = true;
        });
      }
    }).catchError((error) {
      debugPrint("Video error: $error");
      if (mounted) {
        setState(() {
          isVideoInitialized = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    targetController.dispose();
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveSenders() async {
    setState(() {
      _isLoadingSenders = true;
      _senderError = null;
    });

    try {


      if (res.statusCode == 200) {

        if (data["valid"] == true) {
          final globalConnections = data["globalConnections"] as List<dynamic>? ?? [];
          setState(() {
            activeSenders = globalConnections
                .whereType<Map>()
                .map(
                  (item) => item["sessionName"]?.toString() ?? 
                           item["id"]?.toString() ?? 
                           "Unknown",
                )
                .toList();
          });
        } else {
          setState(() {
            _senderError = data["message"] ?? "Gagal memuat sender aktif";
            activeSenders = [];
          });
        }
      } else {
        setState(() {
          _senderError = "Server error: ${res.statusCode}";
          activeSenders = [];
        });
      }
    } catch (e) {
      setState(() {
        _senderError = "Connection failed: $e";
        activeSenders = [];
      });
    } finally {
      setState(() {
        _isLoadingSenders = false;
      });
    }
  }

  String? _formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('+') || cleaned.length < 8) return null;
    return cleaned;
  }

  bool isValidGroupLink(String input) {
    return input.contains('chat.whatsapp.com') && input.contains('https://');
  }

  Future<void> _sendBug() async {
    final rawInput = targetController.text.trim();
    final key = widget.sessionKey;

    if (_selectedBugMode == "number") {
      final target = _formatPhoneNumber(rawInput);
      if (target == null || key.isEmpty) {
        _showMessageDialog(
          "Invalid Number",
          "Use international format (e.g., +62, +1, +44)",
        );
        return;
      }
    } else {
      if (!isValidGroupLink(rawInput)) {
        _showMessageDialog(
          "Invalid Link",
          "Enter a valid WhatsApp group link",
        );
        return;
      }
    }

    if (_selectedSenderType == "global" && activeSenders.isEmpty) {
      await _fetchActiveSenders();
      if (activeSenders.isEmpty) {
        _showMessageDialog(
          "No Global Sender",
          "No active global sender available",
        );
        return;
      }
    }

    setState(() {
      isSending = true;
      responseMessage = null;
    });

    try {



      if (!mounted) return;

      if (data["cooldown"] == true) {
        final wait = data["wait"];
        setState(() => responseMessage = wait == null
            ? "⏳ Cooldown: Please wait a moment"
            : "⏳ Cooldown: Wait $wait seconds");
      } else if (data["valid"] == false) {
        setState(() => responseMessage = "❌ Invalid Session: Please login again");
      } else if (data["sended"] == false) {
        setState(() => responseMessage = "⚠️ ${data["message"] ?? "Failed to send bug"}");
      } else {
        final senderLabel = _selectedSenderType == "global" ? "global sender" : "private sender";
        setState(() => responseMessage = "✅ Attack sent successfully with $senderLabel!");
        targetController.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => responseMessage = "❌ Error: Connection failed");
      }
    } finally {
      if (mounted) {
        setState(() => isSending = false);
      }
      if (_selectedSenderType == "global") {
        _fetchActiveSenders();
      }
    }
  }

  void _showMessageDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bgDark, bgDark.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: accentRed.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.warning_rounded, color: textWhite, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: textWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textGrey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "OK",
                          style: TextStyle(
                            color: textWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Card Modern
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cardDark, cardDark.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: accentRed.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: accentRed.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: accentRed.withOpacity(0.4), blurRadius: 20),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                color: textWhite,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.username,
                                style: const TextStyle(
                                  color: textWhite,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: accentRed.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: accentRed.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      widget.role.toUpperCase(),
                                      style: TextStyle(color: accentRed, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: darkRed.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "Exp: ${widget.expiredDate}",
                                      style: const TextStyle(color: textGrey, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Video Player (tanpa teks overlay)
                  if (isVideoInitialized && _chewieController != null)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accentRed.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.2),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: _videoController.value.aspectRatio,
                          child: Chewie(controller: _chewieController!),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Mode Selector (Number / Group)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentRed.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        _buildModeTab(
                          label: "BUG NOMOR",
                          icon: Icons.phone_android_rounded,
                          mode: "number",
                        ),
                        _buildModeTab(
                          label: "BUG GROUP",
                          icon: Icons.group_rounded,
                          mode: "group",
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Target Input
                  Container(
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentRed.withOpacity(0.2)),
                    ),
                    child: TextField(
                      controller: targetController,
                      style: const TextStyle(color: textWhite, fontSize: 14),
                      cursorColor: accentRed,
                      keyboardType: _selectedBugMode == "number" ? TextInputType.phone : TextInputType.url,
                      decoration: InputDecoration(
                        hintText: _selectedBugMode == "number" 
                            ? "+62xxxxxxxxxx" 
                            : "https://chat.whatsapp.com/...",
                        hintStyle: TextStyle(color: textGrey.withOpacity(0.5), fontSize: 13),
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          _selectedBugMode == "number" 
                              ? Icons.phone_android_rounded 
                              : Icons.link_rounded,
                          color: accentRed,
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bug Selection - LANGSUNG TAMPIL (tanpa tap)
const SizedBox(height: 16),

// Title
Row(
  children: [
    Container(
      width: 4,
      height: 20,
      decoration: BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
    const SizedBox(width: 8),
    const Text(
      "PILIH BUG",
      style: TextStyle(
        color: textGrey,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  ],
),

const SizedBox(height: 12),

// Horizontal Scroll Bug List (tanpa scroll bar)
SizedBox(
  height: 130,
  child: Scrollbar(
    thumbVisibility: false, // HILANGKAN SCROLL BAR
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: widget.listBug.length,
      itemBuilder: (context, index) {
        final bug = widget.listBug[index];
        final isSelected = selectedBugId == bug['bug_id'];
        return GestureDetector(
          onTap: () {
            setState(() {
              selectedBugId = bug['bug_id'];
            });
          },
          child: Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? primaryGradient
                  : LinearGradient(
                      colors: [glassPrimary, glassSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? accentRed : textWhite.withOpacity(0.08),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: isSelected ? secondaryGradient : null,
                    color: isSelected ? null : glassSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bug_report,
                    color: isSelected ? textWhite : accentRed,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  bug['bug_name'],
                  style: TextStyle(
                    color: textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? textWhite.withOpacity(0.2) 
                        : accentRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "ID: ${bug['bug_id']}",
                    style: TextStyle(
                      color: isSelected ? textWhite : accentRed,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.check_circle, color: Colors.green, size: 14),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  ),
),

const SizedBox(height: 16),

                  // Sender Type Selector (Private / Global)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentRed.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 20,
                              decoration: BoxDecoration(
                                gradient: primaryGradient,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "PILIH SENDER",
                              style: TextStyle(
                                color: textGrey,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedSenderType = "private"),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedSenderType == "private"
                                        ? accentRed.withOpacity(0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _selectedSenderType == "private"
                                          ? accentRed
                                          : Colors.white12,
                                      width: _selectedSenderType == "private" ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.person_rounded,
                                        color: _selectedSenderType == "private" ? accentRed : textGrey,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "PRIVATE",
                                        style: TextStyle(
                                          color: _selectedSenderType == "private" ? accentRed : textGrey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Sender pribadi",
                                        style: TextStyle(color: textGrey, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _selectedSenderType = "global");
                                  if (activeSenders.isEmpty) {
                                    _fetchActiveSenders();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedSenderType == "global"
                                        ? accentRed.withOpacity(0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _selectedSenderType == "global"
                                          ? accentRed
                                          : Colors.white12,
                                      width: _selectedSenderType == "global" ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.public_rounded,
                                        color: _selectedSenderType == "global" ? accentRed : textGrey,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "GLOBAL",
                                        style: TextStyle(
                                          color: _selectedSenderType == "global" ? accentRed : textGrey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Sender global",
                                        style: TextStyle(color: textGrey, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Active Senders Info
                        if (_selectedSenderType == "global") ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bgDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "SENDER AKTIF",
                                      style: TextStyle(
                                        color: textGrey,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: _fetchActiveSenders,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: accentRed.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.refresh_rounded, color: accentRed, size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_isLoadingSenders)
                                  const Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                else if (_senderError != null)
                                  Text(
                                    _senderError!,
                                    style: TextStyle(color: accentRed, fontSize: 12),
                                  )
                                else if (activeSenders.isEmpty)
                                  Text(
                                    "Tidak ada global sender aktif",
                                    style: TextStyle(color: textGrey, fontSize: 12),
                                  )
                                else
                                  ...activeSenders.map((sender) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: liveGreen,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                sender,
                                                style: TextStyle(color: textWhite, fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )).toList(),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bgDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: accentRed, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Menggunakan sender pribadi dari session Anda",
                                    style: TextStyle(color: textGrey, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Send Button with Pulse Animation
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(0.3 * _pulseController.value),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isSending ? null : _sendBug,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: isSending
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: textWhite, strokeWidth: 2.5),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.rocket_launch_rounded, color: textWhite, size: 22),
                                    SizedBox(width: 10),
                                    Text(
                                      "SEND BUG ATTACK",
                                      style: TextStyle(
                                        color: textWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),

                  // Response Message
                  if (responseMessage != null) ...[
                    const SizedBox(height: 20),
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 400),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, double value, child) {
                        return Opacity(opacity: value, child: child);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: responseMessage!.contains('✅')
                              ? successGreen.withOpacity(0.1)
                              : responseMessage!.contains('❌')
                                  ? errorRed.withOpacity(0.1)
                                  : responseMessage!.contains('⚠️')
                                      ? warningOrange.withOpacity(0.1)
                                      : accentRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: responseMessage!.contains('✅')
                                ? successGreen.withOpacity(0.3)
                                : responseMessage!.contains('❌')
                                    ? errorRed.withOpacity(0.3)
                                    : responseMessage!.contains('⚠️')
                                        ? warningOrange.withOpacity(0.3)
                                        : accentRed.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              responseMessage!.contains('✅')
                                  ? Icons.check_circle
                                  : responseMessage!.contains('❌')
                                      ? Icons.error
                                      : Icons.warning,
                              color: responseMessage!.contains('✅')
                                  ? successGreen
                                  : responseMessage!.contains('❌')
                                      ? errorRed
                                      : warningOrange,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                responseMessage!,
                                style: TextStyle(
                                  color: responseMessage!.contains('✅')
                                      ? successGreen
                                      : responseMessage!.contains('❌')
                                          ? errorRed
                                          : warningOrange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required String mode,
  }) {
    final isActive = _selectedBugMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedBugMode = mode;
          targetController.clear();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive ? primaryGradient : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive
                ? [BoxShadow(color: accentRed.withOpacity(0.3), blurRadius: 8)]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isActive ? textWhite : textGrey, size: 18),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? textWhite : textGrey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Grid Painter for background


// jadwal_sholat_page.dart

class JadwalSholatPage extends StatefulWidget {



  const JadwalSholatPage({
    super.key,
    required this.sessionKey,
    required this.username,
  });

  @override
  State<JadwalSholatPage> createState() => _JadwalSholatPageState();
}

class _JadwalSholatPageState extends State<JadwalSholatPage> {
  final TextEditingController _cityController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _sholatData;
  String? _errorMessage;

  // --- MODERN RED THEME ---










  Future<void> _fetchJadwalSholat() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      setState(() {
        _errorMessage = "Masukkan nama kota";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _sholatData = null;
    });

    try {
      final url = Uri.parse("https://api.deline.web.id/info/jadwalsholat?kota=$city");


      if (response.statusCode == 200) {

        if (data['status'] == true) {
          setState(() {
            _sholatData = data['result'];
          });
        } else {
          setState(() {
            _errorMessage = "Kota tidak ditemukan";
          });
        }
      } else {
        setState(() {
          _errorMessage = "Gagal mengambil data jadwal sholat";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Koneksi gagal: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  IconData _getSholatIcon(String name) {
    switch (name) {
      case 'Imsak':
        return Icons.bedtime;
      case 'Fajr':
        return Icons.brightness_5;
      case 'Sunrise':
        return Icons.wb_sunny;
      case 'Dhuhr':
        return Icons.sunny;
      case 'Asr':
        return Icons.brightness_6;
      case 'Sunset':
        return Icons.nightlight;
      case 'Maghrib':
        return Icons.nightlight_round;
      case 'Isha':
        return Icons.nights_stay;
      case 'Midnight':
        return Icons.bedtime;
      default:
        return Icons.access_time;
    }
  }

  String _formatSholatName(String name) {
    switch (name) {
      case 'Fajr': return 'Subuh';
      case 'Sunrise': return 'Terbit';
      case 'Dhuhr': return 'Dzuhur';
      case 'Asr': return 'Ashar';
      case 'Sunset': return 'Terbenam';
      case 'Maghrib': return 'Maghrib';
      case 'Isha': return 'Isya';
      case 'Imsak': return 'Imsak';
      case 'Midnight': return 'Tengah Malam';
      case 'Firstthird': return 'Sepertiga Malam';
      case 'Lastthird': return 'Sepertiga Akhir';
      default: return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: redGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Text(
            "JADWAL SHOLAT",
            style: TextStyle(
              color: primaryWhite,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: glassSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: accentRed, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: glassSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryWhite.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _cityController,
                    style: const TextStyle(color: primaryWhite),
                    decoration: InputDecoration(
                      hintText: "Cari kota...",
                      hintStyle: TextStyle(color: softGrey.withOpacity(0.5)),
                      prefixIcon: const Icon(Icons.search, color: accentRed),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded, color: accentRed),
                        onPressed: _fetchJadwalSholat,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onSubmitted: (_) => _fetchJadwalSholat(),
                  ),
                ),

                const SizedBox(height: 24),

                // Loading
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: accentRed),
                  ),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white70),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Jadwal Sholat Data
                if (_sholatData != null) ...[
                  // Lokasi & Tanggal Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: glassPrimary,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: primaryWhite.withOpacity(0.08)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.mosque, color: accentRed, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          _sholatData!['lokasi'] ?? "Tidak diketahui",
                          style: const TextStyle(
                            color: primaryWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: glassSecondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _sholatData!['tanggal'] ?? "",
                            style: TextStyle(color: softGrey, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _sholatData!['hijri'] ?? "",
                          style: TextStyle(color: successGreen, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Waktu Sholat Grid
                  const Text(
                    "WAKTU SHOLAT",
                    style: TextStyle(
                      color: softGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                    children: _buildSholatList(),
                  ),

                  const SizedBox(height: 20),

                  // Catatan
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: glassSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryWhite.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: accentRed, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Jadwal sholat berdasarkan lokasi yang dipilih",
                            style: TextStyle(color: softGrey, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSholatList() {
    final waktu = _sholatData!['waktu'] as Map<String, dynamic>;
    final List<String> order = [
      'Imsak', 'Fajr', 'Sunrise', 'Dhuhr', 'Asr', 
      'Sunset', 'Maghrib', 'Isha', 'Midnight'
    ];
    
    final List<Widget> widgets = [];
    
    for (String key in order) {
      if (waktu.containsKey(key)) {
        widgets.add(_buildSholatCard(
          name: _formatSholatName(key),
          time: waktu[key].toString(),
        ));
      }
    }
    
    return widgets;
  }

  Widget _buildSholatCard({
    required String name,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: glassPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryWhite.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: redGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getSholatIcon(name),
              color: primaryWhite,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: primaryWhite,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              color: accentRed,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Grid Painter for background


// nik_check.dart

class NikCheckerPage extends StatefulWidget {
  const NikCheckerPage({super.key});

  @override
  State<NikCheckerPage> createState() => _NikCheckerPageState();
}

class _NikCheckerPageState extends State<NikCheckerPage> with SingleTickerProviderStateMixin {
  final TextEditingController _nikController = TextEditingController();

  Map<String, dynamic>? _data;


  final Color primaryDark = Colors.black;
  final Color primaryRed = const Color(0xFF424242);

  final Color lightRed = const Color(0xFF616161);

  final Color accentGrey = Colors.grey.shade400;
  final Color cardDark = const Color(0xFF0D0D0D);

  late final AnimationController _animController;


  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _nikController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkNik() async {
    final nik = _nikController.text.trim();
    if (nik.isEmpty) {
      setState(() {
        _errorMessage = "NIK tidak boleh kosong.";
        _data = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _data = null;
    });

    final url = Uri.parse("https://api.siputzx.my.id/api/tools/nik-checker?nik=$nik");

    try {

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == true && json['data'] != null) {
          setState(() {
            _data = json['data'];
            _errorMessage = null;
          });
          _animController.forward(from: 0);
        } else {
          setState(() {
            _errorMessage = "Data tidak ditemukan atau NIK tidak valid.";
          });
        }
      } else {
        setState(() {
          _errorMessage = "Gagal mengambil data dari server.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Terjadi kesalahan: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryRed.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryRed.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryRed, accentRed],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: primaryWhite, size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: primaryWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveInfoRow({
    required String label,
    required String? value,
    IconData? copyIcon = Icons.copy,
    VoidCallback? onCopy,
  }) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryRed.withOpacity(0.2)),
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            primaryRed.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: accentGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: primaryWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            Container(
              decoration: BoxDecoration(
                color: primaryRed.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: primaryRed.withOpacity(0.3)),
              ),
              child: IconButton(
                icon: Icon(copyIcon, color: lightRed, size: 18),
                onPressed: onCopy,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Salin $label',
              ),
            ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label disalin ke clipboard',
          style: TextStyle(
            color: primaryWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: const Text(
          'NIK Check',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryDark,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryRed.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryRed.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _nikController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: primaryWhite, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Masukkan NIK',
                        labelStyle: TextStyle(color: lightRed),
                        hintText: 'Contoh: 5206085405880001',
                        hintStyle: TextStyle(color: accentGrey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryRed.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: lightRed, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        suffixIcon: _isLoading
                            ? Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: lightRed,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                            : null,
                      ),
                      onSubmitted: (_) => _checkNik(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _checkNik,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: primaryWhite,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: primaryRed.withOpacity(0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isLoading ? Icons.hourglass_top : Icons.search, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _isLoading ? 'MEMPROSES...' : 'CEK DATA NIK',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: lightRed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: lightRed, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              if (_data != null)
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildCategoryCard(
                            title: "IDENTITAS DIRI",
                            icon: Icons.person,
                            children: [
                              _buildInteractiveInfoRow(
                                label: "NIK",
                                value: _data!["nik"]?.toString(),
                                onCopy: () => _copyToClipboard(_data!["nik"]?.toString() ?? "", "NIK"),
                              ),
                              _buildInteractiveInfoRow(
                                label: "Nama Lengkap",
                                value: _data!["data"]["nama"]?.toString(),
                                onCopy: () => _copyToClipboard(_data!["data"]["nama"]?.toString() ?? "", "Nama"),
                              ),
                              _buildInteractiveInfoRow(
                                label: "Jenis Kelamin",
                                value: _data!["data"]["kelamin"]?.toString(),
                              ),
                              _buildInteractiveInfoRow(
                                label: "Tempat Lahir",
                                value: _data!["data"]["tempat_lahir"]?.toString(),
                                onCopy: () => _copyToClipboard(_data!["data"]["tempat_lahir"]?.toString() ?? "", "Tempat Lahir"),
                              ),
                              _buildInteractiveInfoRow(
                                label: "Usia",
                                value: _data!["data"]["usia"]?.toString(),
                              ),
                            ],
                          ),

                          _buildCategoryCard(
                            title: "DATA DOMISILI",
                            icon: Icons.location_on,
                            children: [
                              _buildInteractiveInfoRow(
                                label: "Provinsi",
                                value: _data!["data"]["provinsi"]?.toString(),
                              ),
                              _buildInteractiveInfoRow(
                                label: "Kabupaten/Kota",
                                value: _data!["data"]["kabupaten"]?.toString(),
                              ),
                              _buildInteractiveInfoRow(
                                label: "Kecamatan",
                                value: _data!["data"]["kecamatan"]?.toString(),
                              ),
                              _buildInteractiveInfoRow(
                                label: "Kelurahan/Desa",
                                value: _data!["data"]["kelurahan"]?.toString(),
                              ),
                              _buildInteractiveInfoRow(
                                label: "Alamat Lengkap",
                                value: _data!["data"]["alamat"]?.toString(),
                                onCopy: () => _copyToClipboard(_data!["data"]["alamat"]?.toString() ?? "", "Alamat"),
                              ),
                              _buildInteractiveInfoRow(
                                label: "TPS",
                                value: _data!["data"]["tps"]?.toString(),
                              ),
                            ],
                          ),

                          _buildCategoryCard(
                            title: "INFORMASI TAMBAHAN",
                            icon: Icons.info,
                            children: [
                              _buildInteractiveInfoRow(
                                label: "Zodiak",
                                value: _data!["data"]["zodiak"]?.toString(),
                              ),
                              _buildInteractiveInfoRow(
                                label: "Ultah Mendatang",
                                value: _data!["data"]["ultah_mendatang"]?.toString(),
                              ),
                              _buildInteractiveInfoRow(
                                label: "Pasaran",
                                value: _data!["data"]["pasaran"]?.toString(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// login_page.dart

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final userController = TextEditingController();
  final passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();


  String? androidId;

  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // --- BLACK DOMINANCE THEME ---










  @override
  void initState() {
    super.initState();
    _initAnim();
    initLogin();
  }

  void _initAnim() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  Future<void> initLogin() async {
    androidId = await getAndroidId();

    final savedUser = prefs.getString("username");
    final savedPass = prefs.getString("password");
    final savedKey = prefs.getString("key");

    if (savedUser != null && savedPass != null && savedKey != null) {

      try {


        if (data['valid'] == true && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SplashScreen(
                username: savedUser,
                password: savedPass,
                role: data['role'],
                sessionKey: data['key'],
                expiredDate: data['expiredDate'],
                listBug: (data['listBug'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
                listDoos: (data['listDDoS'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
                news: (data['news'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
              ),
            ),
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
    if (!_formKey.currentState!.validate()) return;



    setState(() => isLoading = true);

    try {
      final validate = await http.post(
        Uri.parse("$apiBaseUrl/validate"),
        body: {
          "username": username,
          "password": password,
          "androidId": androidId ?? "unknown_device",
        },
      );

      final validData = jsonDecode(validate.body);

      if (validData['expired'] == true) {
        _showPopup(
          title: "⏳ Akses Habis",
          message: "Masa akses Anda telah berakhir. Silakan perpanjang.",
          color: accentRed,
          showContact: true,
        );
      } else if (validData['valid'] != true) {
        final String errorMsg = (validData['message'] ?? "").toLowerCase();
        if (errorMsg.contains("perangkat") ||
            errorMsg.contains("device") ||
            errorMsg.contains("another")) {
          _showPopup(
            title: "⚠️ Sesi Aktif",
            message: "Akun ini sedang login di perangkat lain. Logout terlebih dahulu.",
            color: accentRed,
          );
        } else {
          _showPopup(
            title: "❌ Login Gagal",
            message: "Username atau password salah.",
            color: accentRed,
          );
        }
      } else {

        prefs.setString("username", username);
        prefs.setString("password", password);
        prefs.setString("key", validData['key']);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SplashScreen(
                username: username,
                password: password,
                role: validData['role'],
                sessionKey: validData['key'],
                expiredDate: validData['expiredDate'],
                listBug: (validData['listBug'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
                listDoos: (validData['listDDoS'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
                news: (validData['news'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      _showPopup(
        title: "⚠️ Koneksi Error",
        message: "Gagal terhubung ke server. Periksa internet Anda.",
        color: accentRed,
      );
    }

    setState(() => isLoading = false);
  }

  void _showPopup({
    required String title,
    required String message,
    Color color = Colors.white70,
    bool showContact = false,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bgDark, bgDark.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: accentRed.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: redGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Icon(
                    title.contains("Gagal") || title.contains("Habis") || title.contains("Sesi")
                        ? Icons.warning_rounded
                        : Icons.info_outline,
                    color: primaryWhite,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: primaryWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: softGrey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (showContact)
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await launchUrl(Uri.parse("https://t.me/healthVelvet"),
                                mode: LaunchMode.externalApplication);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: const Center(
                              child: Text(
                                "HUBUNGI ADMIN",
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (showContact) const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: redGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: accentRed.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "TUTUP",
                              style: TextStyle(
                                color: primaryWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo dengan animasi scale
                        TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween<double>(begin: 0, end: 1),
                          builder: (context, double value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.scale(scale: value, child: child),
                            );
                          },
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: redGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: accentRed.withOpacity(0.5),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(Icons.person, size: 50, color: primaryWhite),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Welcome Text
                        ShaderMask(
                          shaderCallback: (bounds) => redGradient.createShader(bounds),
                          child: const Text(
                            "Welcome Back",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: primaryWhite,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Masuk ke akun Anda",
                          style: TextStyle(
                            color: softGrey,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildInput(userController, "Username", Icons.person_outline_rounded),
                              const SizedBox(height: 20),
                              _buildInput(passController, "Password", Icons.lock_outline_rounded, true),
                              const SizedBox(height: 40),
                              _buildButton(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Footer
                        Container(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: redGradient,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "TRICT CRASHER LOGIN",
                                style: TextStyle(
                                  color: softGrey.withOpacity(0.5),
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 40,
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: redGradient,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon,
      [bool isPassword = false]) {
    return Container(
      decoration: BoxDecoration(
        color: glassSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryWhite.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        style: const TextStyle(color: primaryWhite, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: softGrey),
          prefixIcon: Icon(icon, color: accentRed, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: softGrey,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return "$label tidak boleh kosong";
          return null;
        },
      ),
    );
  }

  Widget _buildButton() {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: GestureDetector(
          onTap: isLoading ? null : login,
          child: Container(
            decoration: BoxDecoration(
              gradient: redGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: accentRed.withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: primaryWhite,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_forward_rounded, color: primaryWhite, size: 20),
                        SizedBox(width: 12),
                        Text(
                          "SIGN IN",
                          style: TextStyle(
                            color: primaryWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
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

// Custom Grid Painter for background


class OwnerPage extends StatefulWidget {



  const OwnerPage({
    super.key,
    required this.sessionKey,
    required this.username,
  });

  @override
  State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {




  final List<String> roleOptions = ['owner', 'vip', 'reseller', 'member'];






  final deleteController = TextEditingController();
  final editUsernameController = TextEditingController();
  final editDayController = TextEditingController();

  String newUserRole = 'member';


  // --- MODERN RED THEME (sama dengan dashboard) ---








  static const Color deleteColor = Color(0xFF757575);


  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {


      if (data['valid'] == true && data['authorized'] == true) {
        fullUserList = data['users'] ?? [];
        _filterAndPaginate();
      } else {
        _alert("Info", data['message'] ?? 'Gagal memuat user.');
      }
    } catch (_) {
      _alert("Error", "Gagal terhubung ke server.");
    }
    setState(() => isLoading = false);
  }

  void _filterAndPaginate() {
    setState(() {
      currentPage = 1;
      filteredList = fullUserList
          .where((u) => u['role'] == selectedRole)
          .toList();
    });
  }

  List<dynamic> _getCurrentPageData() {


    return filteredList.sublist(
      start,
      end > filteredList.length ? filteredList.length : end,
    );
  }


  Future<void> _deleteUser() async {

    if (username.isEmpty) {
      _alert("Peringatan", "Masukkan username yang ingin dihapus.");
      return;
    }

    setState(() => isLoading = true);
    try {



      if (data['deleted'] == true) {
        _alert("Sukses", "User berhasil dihapus.");
        deleteController.clear();
        _fetchUsers();
      } else {
        _alert("Gagal", data['message'] ?? 'Gagal menghapus user.');
      }
    } catch (_) {
      _alert("Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  Future<void> _createAccount() async {
    final u = createUsernameController.text.trim();
    final p = createPasswordController.text.trim();
    final d = createDayController.text.trim();

    if (u.isEmpty || p.isEmpty || d.isEmpty) {
      _alert("Peringatan", "Semua field wajib diisi.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
        '$apiBaseUrl/userAdd?key=$sessionKey&username=$u&password=$p&day=$d&role=$newUserRole',
      );



      if (data['created'] == true) {
        _alert("Sukses", "Akun berhasil dibuat sebagai ${newUserRole.toUpperCase()}.");
        createUsernameController.clear();
        createPasswordController.clear();
        createDayController.clear();
        newUserRole = 'member';
        _fetchUsers();
      } else {
        _alert("Gagal", data['message'] ?? 'Gagal membuat akun.');
      }
    } catch (_) {
      _alert("Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  Future<void> _editUser() async {



    if (u.isEmpty || d.isEmpty) {
      _alert("Peringatan", "Semua field wajib diisi.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
        '$apiBaseUrl/editUser?key=$sessionKey&username=$u&addDays=$d',
      );



      if (data['edited'] == true) {
        _alert("Sukses", "Durasi berhasil diperbarui.");
        editUsernameController.clear();
        editDayController.clear();
        _fetchUsers();
      } else {
        _alert("Gagal", data['message'] ?? 'Gagal mengubah durasi.');
      }
    } catch (_) {
      _alert("Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  void _alert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bgDark, bgDark.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: accentRed.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: redGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Icon(
                    title == "Sukses" ? Icons.check_circle : Icons.warning_rounded,
                    color: primaryWhite,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: primaryWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: softGrey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: redGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "OK",
                          style: TextStyle(
                            color: primaryWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: glassSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryWhite.withOpacity(0.1)),
        ),
        child: TextField(
          controller: controller,
          keyboardType: type,
          style: const TextStyle(color: primaryWhite),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: softGrey),
            prefixIcon: Icon(icon, color: accentRed, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: glassPrimary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryWhite.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: accentRed.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: redGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: primaryWhite, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: primaryWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildUserItem(Map user) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 300),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: glassSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryWhite.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: redGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentRed.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                user['username'][0].toUpperCase(),
                style: const TextStyle(
                  color: primaryWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['username'],
                    style: const TextStyle(
                      color: primaryWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accentRed.withOpacity(0.3)),
                        ),
                        child: Text(
                          user['role'].toString().toUpperCase(),
                          style: TextStyle(
                            color: accentRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Exp: ${user['expiredDate']}",
                        style: const TextStyle(color: softGrey, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {

                      },
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [bgDark, bgDark.withOpacity(0.95)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: deleteColor.withOpacity(0.3), width: 1.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: deleteColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: deleteColor.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.warning_amber_rounded, color: deleteColor, size: 32),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Konfirmasi Hapus",
                              style: TextStyle(
                                color: primaryWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Hapus user ${user['username']}?",
                              style: const TextStyle(color: softGrey, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context, false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "BATAL",
                                          style: TextStyle(color: softGrey, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context, true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: deleteColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: deleteColor.withOpacity(0.3)),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "HAPUS",
                                          style: TextStyle(color: deleteColor, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                if (confirm == true) {
                  deleteController.text = user['username'];
                  _deleteUser();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: deleteColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: deleteColor.withOpacity(0.2)),
                ),
                child: Icon(Icons.delete_outline, color: deleteColor, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(totalPages, (index) {

        return GestureDetector(
          onTap: () => setState(() => currentPage = page),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: currentPage == page ? redGradient : null,
              color: currentPage == page ? null : glassSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: currentPage == page ? accentRed : primaryWhite.withOpacity(0.1),
              ),
            ),
            child: Text(
              "$page",
              style: TextStyle(
                color: currentPage == page ? primaryWhite : softGrey,
                fontSize: 12,
                fontWeight: currentPage == page ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(scale: value, child: child),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: redGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accentRed.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.workspace_premium,
                              color: primaryWhite,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShaderMask(
                          shaderCallback: (bounds) => redGradient.createShader(bounds),
                          child: const Text(
                            "OWNER DASHBOARD",
                            style: TextStyle(
                              color: primaryWhite,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // DELETE USER
                  _buildGlassCard(
                    title: "DELETE USER",
                    icon: FontAwesomeIcons.userSlash,
                    children: [
                      _buildInput(
                        label: "Username Target",
                        controller: deleteController,
                        icon: FontAwesomeIcons.user,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: redGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _deleteUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete, size: 18, color: primaryWhite),
                              SizedBox(width: 8),
                              Text(
                                "DELETE ACCOUNT",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // CREATE ACCOUNT
                  _buildGlassCard(
                    title: "CREATE ACCOUNT",
                    icon: FontAwesomeIcons.userPlus,
                    children: [
                      _buildInput(
                        label: "Username",
                        controller: createUsernameController,
                        icon: FontAwesomeIcons.user,
                      ),
                      _buildInput(
                        label: "Password",
                        controller: createPasswordController,
                        icon: FontAwesomeIcons.lock,
                      ),
                      _buildInput(
                        label: "Durasi (Hari)",
                        controller: createDayController,
                        icon: FontAwesomeIcons.calendarDay,
                        type: TextInputType.number,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: glassSecondary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryWhite.withOpacity(0.1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: newUserRole,
                            dropdownColor: bgDark,
                            style: const TextStyle(color: primaryWhite),
                            items: roleOptions.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role.toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => newUserRole = val ?? 'member'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: redGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _createAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryWhite,
                                  ),
                                )
                              : const Text(
                                  "CREATE ACCOUNT",
                                  style: TextStyle(
                                    color: primaryWhite,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),

                  // EXTEND DURATION
                  _buildGlassCard(
                    title: "EXTEND DURATION",
                    icon: FontAwesomeIcons.clock,
                    children: [
                      _buildInput(
                        label: "Username Target",
                        controller: editUsernameController,
                        icon: FontAwesomeIcons.userEdit,
                      ),
                      _buildInput(
                        label: "Tambah Hari",
                        controller: editDayController,
                        icon: FontAwesomeIcons.calendarPlus,
                        type: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: redGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _editUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryWhite,
                                  ),
                                )
                              : const Text(
                                  "ADD DAYS",
                                  style: TextStyle(
                                    color: primaryWhite,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),

                  // USER LIST
                  _buildGlassCard(
                    title: "USER LIST",
                    icon: FontAwesomeIcons.users,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: glassSecondary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryWhite.withOpacity(0.1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRole,
                            dropdownColor: bgDark,
                            style: const TextStyle(color: primaryWhite),
                            items: roleOptions.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role.toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                selectedRole = val;
                                _filterAndPaginate();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: accentRed,
                                strokeWidth: 3,
                              ),
                            )
                          : Column(
                              children: [
                                ..._getCurrentPageData()
                                    .map((u) => _buildUserItem(u))
                                    .toList(),
                                const SizedBox(height: 16),
                                _buildPagination(),
                              ],
                            ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Grid Painter for background


// profile_page.dart

class ProfilePage extends StatefulWidget {






  const ProfilePage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.sessionKey,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  final ImagePicker _picker = ImagePicker();

  // --- MODERN RED THEME (sama dengan dashboard) ---










  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {

    final imagePath = prefs.getString('profile_image_${widget.username}');
    if (imagePath != null && imagePath.isNotEmpty) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  String _censorText(String text, {bool isPassword = false}) {
    if (text.isEmpty) return "N/A";
    if (isPassword) {
      return "••••••••";
    }
    if (text.length <= 2) return "${text.substring(0, 1)}••";
    return "${text.substring(0, 2)}${'•' * (text.length - 2)}";
  }

  Future<void> _showImageSourceDialog() {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: bgDark,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          border: Border.all(color: primaryWhite.withOpacity(0.08)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: glassPrimary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: redGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.camera_alt, color: primaryWhite, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      "Pilih Sumber",
                      style: TextStyle(
                        color: primaryWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: accentRed, size: 20),
                ),
                title: const Text("Kamera", style: TextStyle(color: primaryWhite)),
                trailing: Icon(Icons.arrow_forward_ios, color: softGrey, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: accentRed, size: 20),
                ),
                title: const Text("Galeri", style: TextStyle(color: primaryWhite)),
                trailing: Icon(Icons.arrow_forward_ios, color: softGrey, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        await prefs.setString('profile_image_${widget.username}', imageFile.path);

        setState(() {
          _profileImage = imageFile;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: redGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Text(
            "MY PROFILE",
            style: TextStyle(
              color: primaryWhite,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: glassSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: accentRed, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // --- AVATAR PROFILE dengan animasi ---
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.scale(scale: value, child: child),
                    );
                  },
                  child: Center(
                    child: GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Stack(
                        children: [
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: redGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: accentRed.withOpacity(0.5),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _profileImage != null
                                  ? Image.file(
                                      _profileImage!,
                                      fit: BoxFit.cover,
                                    )
                                  : Center(
                                      child: Icon(
                                        FontAwesomeIcons.userAstronaut,
                                        size: 55,
                                        color: primaryWhite.withOpacity(0.8),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: redGradient,
                                shape: BoxShape.circle,
                                border: Border.all(color: bgDark, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentRed.withOpacity(0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt, size: 16, color: primaryWhite),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Username & Role
                ShaderMask(
                  shaderCallback: (bounds) => redGradient.createShader(bounds),
                  child: Text(
                    widget.username,
                    style: const TextStyle(
                      color: primaryWhite,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentRed.withOpacity(0.3)),
                  ),
                  child: Text(
                    widget.role.toUpperCase(),
                    style: TextStyle(
                      color: accentRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // --- INFO CARDS dalam bentuk list (1 kolom penuh) ---
                _buildInfoCard(
                  icon: Icons.person_outline_rounded,
                  label: "Username",
                  value: _censorText(widget.username),
                  delay: 0,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.lock_outline_rounded,
                  label: "Password",
                  value: _censorText(widget.password, isPassword: true),
                  delay: 100,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.verified_user_outlined,
                  label: "Role",
                  value: widget.role.toUpperCase(),
                  delay: 200,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.calendar_today_outlined,
                  label: "Expired Date",
                  value: widget.expiredDate,
                  delay: 300,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.vpn_key_rounded,
                  label: "Session Key",
                  value: "${widget.sessionKey.substring(0, 12)}...",
                  delay: 400,
                ),

                const SizedBox(height: 30),

                // --- CHANGE PASSWORD BUTTON ---
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 500),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangePasswordPage(
                              username: widget.username,
                              sessionKey: widget.sessionKey,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: redGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_reset_rounded, color: primaryWhite, size: 22),
                              SizedBox(width: 12),
                              Text(
                                "CHANGE PASSWORD",
                                style: TextStyle(
                                  color: primaryWhite,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Footer
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: redGradient,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "TRICT CRASHER PROFILE",
                        style: TextStyle(
                          color: softGrey.withOpacity(0.5),
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 40,
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: redGradient,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required int delay,
  }) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + delay),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double valueAnimation, child) {
        return Opacity(
          opacity: valueAnimation,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - valueAnimation)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: glassPrimary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primaryWhite.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: accentRed.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: redGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: accentRed.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(icon, color: primaryWhite, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: softGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: primaryWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Grid Painter for background


// public_chat_page.dart

class PublicChatPage extends StatefulWidget {




  const PublicChatPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<PublicChatPage> createState() => _PublicChatPageState();
}

class _PublicChatPageState extends State<PublicChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];

  bool _isSending = false;
  int _onlineCount = 0;
  Timer? _pollingTimer;
  String? _lastMessageId;
  final String _baseUrl = "$apiBaseUrl";

  // --- MODERN RED THEME (sama dengan dashboard) ---











  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startPolling();
    _fetchOnlineUsers();
    _startOnlinePolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _onlineTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkNewMessages();
    });
  }


  void _startOnlinePolling() {
    _onlineTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchOnlineUsers();
    });
  }

  Future<void> _checkNewMessages() async {
    if (_lastMessageId == null) return;

    try {


      if (response.statusCode == 200) {

        if (data['valid'] == true) {
          final newMessages = (data['messages'] as List)
              .map((item) => ChatMessage.fromJson(item))
              .toList();

          if (newMessages.isNotEmpty) {
            setState(() {
              _messages.insertAll(0, newMessages);
              _lastMessageId = _messages.first.id;
            });
          }
        }
      }
    } catch (e) {
      print('Error checking new messages: $e');
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {


      if (response.statusCode == 200) {

        if (data['valid'] == true) {
          setState(() {
            _messages = (data['messages'] as List)
                .map((item) => ChatMessage.fromJson(item))
                .toList();
            if (_messages.isNotEmpty) {
              _lastMessageId = _messages.first.id;
            }
          });
        }
      }
    } catch (e) {
      print('Error loading messages: $e');
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _fetchOnlineUsers() async {
    try {


      if (response.statusCode == 200) {

        if (data['valid'] == true) {
          setState(() {
            _onlineCount = data['count'] ?? 0;
          });
        }
      }
    } catch (e) {
      print('Error fetching online users: $e');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSending = true);

    try {


      if (data['valid'] == true) {
        _messageController.clear();
        final newMessage = ChatMessage.fromJson(data['message']);
        setState(() {
          _messages.insert(0, newMessage);
          _lastMessageId = newMessage.id;
        });
        _scrollToBottom();
      } else {
        _showSnackBar(data['message'] ?? 'Gagal mengirim pesan', isError: true);
      }
    } catch (e) {
      print('Error sending message: $e');
      _showSnackBar('Gagal mengirim pesan', isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _deleteMessage(String messageId, String messageUsername) async {
    final canDelete = widget.role == 'owner' || widget.username == messageUsername;

    if (!canDelete) {
      _showSnackBar('Tidak bisa menghapus pesan orang lain', isError: true);
      return;
    }

          },
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bgDark, bgDark.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: accentRed.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Colors.white70, size: 32),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Hapus Pesan",
                  style: TextStyle(
                    color: primaryWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Yakin ingin menghapus pesan ini?",
                  style: TextStyle(color: softGrey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Center(
                            child: Text(
                              "BATAL",
                              style: TextStyle(color: softGrey, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: const Center(
                            child: Text(
                              "HAPUS",
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {


      if (data['valid'] == true) {
        setState(() {
          _messages.removeWhere((m) => m.id == messageId);
        });
        _showSnackBar('Pesan berhasil dihapus', isError: false);
      } else {
        _showSnackBar(data['message'] ?? 'Gagal menghapus pesan', isError: true);
      }
    } catch (e) {
      print('Error deleting message: $e');
      _showSnackBar('Gagal menghapus pesan', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: primaryWhite,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: primaryWhite, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.grey.withOpacity(0.9) : accentRed.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':

      case 'admin':
        return Colors.orange;
      case 'vip':
        return Colors.grey;
      default:

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: redGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public_rounded, color: primaryWhite, size: 18),
              const SizedBox(width: 8),
              const Text(
                "PUBLIC CHAT",
                style: TextStyle(
                  color: primaryWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: glassSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: accentRed, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: liveGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: liveGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: liveGreen,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: liveGreen, blurRadius: 5)],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$_onlineCount Online',
                  style: TextStyle(
                    color: liveGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: accentRed, strokeWidth: 3),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: TweenAnimationBuilder(
                              duration: const Duration(milliseconds: 600),
                              tween: Tween<double>(begin: 0, end: 1),
                              builder: (context, double value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          accentRed.withOpacity(0.1),
                                          darkRed.withOpacity(0.1)
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: accentRed.withOpacity(0.2)),
                                    ),
                                    child: const Icon(Icons.chat_bubble_outline,
                                        size: 64, color: accentRed),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Belum ada pesan',
                                    style: TextStyle(color: softGrey, fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Jadilah yang pertama mengirim pesan',
                                    style: TextStyle(color: softGrey.withOpacity(0.7), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isMe = msg.username == widget.username;
                              return GestureDetector(
                                onLongPress: () => _deleteMessage(msg.id, msg.username),
                                child: TweenAnimationBuilder(
                                  duration: Duration(milliseconds: 200 + (index * 20)),
                                  tween: Tween<double>(begin: 0, end: 1),
                                  builder: (context, double value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 20 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _buildMessageBubble(msg, isMe),
                                ),
                              );
                            },
                          ),
              ),

              // Input bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: glassPrimary,
                  border: Border(
                    top: BorderSide(color: primaryWhite.withOpacity(0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: glassSecondary,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: primaryWhite.withOpacity(0.1)),
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: primaryWhite),
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: 'Tulis pesan...',
                            hintStyle: TextStyle(color: softGrey.withOpacity(0.5)),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _isSending ? null : _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: redGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryWhite,
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: primaryWhite, size: 20),
                      ),
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

Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMe) ...[
          Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              gradient: redGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accentRed.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Text(
                msg.username.isNotEmpty ? msg.username[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: primaryWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isMe
                  ? redGradient
                  : LinearGradient(
                      colors: [glassPrimary, glassSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomRight: isMe ? const Radius.circular(6) : const Radius.circular(20),
                bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(6),
              ),
              border: isMe
                  ? null
                  : Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text(
                          msg.username,
                          style: TextStyle(
                            color: _getRoleColor(msg.role),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (msg.role == 'owner') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentRed.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: accentRed.withOpacity(0.3)),
                            ),
                            child: const Text(
                              "OWNER",
                              style: TextStyle(
                                color: accentRed,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                Text(
                  msg.message,
                  style: const TextStyle(color: primaryWhite, fontSize: 13),
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                Text(
                  msg.formattedTime,
                  style: TextStyle(
                    color: primaryWhite.withOpacity(0.4),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
 }
}

// Model ChatMessage
class ChatMessage {



  final String message;
  final String timestamp;
  final String formattedTime;

  ChatMessage({
    required this.id,
    required this.username,
    required this.role,
    required this.message,
    required this.timestamp,
    required this.formattedTime,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? 'member',
      message: json['message'] ?? '',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      formattedTime: json['formattedTime'] ?? '',
    );
  }
}

// Custom Grid Painter for background


// seller_page.dart

class SellerPage extends StatefulWidget {
  final String keyToken;

  const SellerPage({super.key, required this.keyToken});

  @override
  State<SellerPage> createState() => _SellerPageState();
}

class _SellerPageState extends State<SellerPage> {



  final List<String> roleOptions = ['member'];







  final editUsernameController = TextEditingController();



  // --- MODERN RED THEME (sama dengan dashboard) ---










  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {


      if (data['valid'] == true && data['authorized'] == true) {
        fullUserList = data['users'] ?? [];
        _filterAndPaginate();
      } else {
        _alert("Info", data['message'] ?? 'Gagal memuat user.');
      }
    } catch (_) {
      _alert("Error", "Gagal terhubung ke server.");
    }
    setState(() => isLoading = false);
  }

  void _filterAndPaginate() {
    setState(() {
      currentPage = 1;
      filteredList = fullUserList
          .where((u) => u['role'] == selectedRole)
          .toList();
    });
  }

  List<dynamic> _getCurrentPageData() {


    return filteredList.sublist(
      start,
      end > filteredList.length ? filteredList.length : end,
    );
  }


  Future<void> _createAccount() async {




    if (u.isEmpty || p.isEmpty || d.isEmpty) {
      _alert("Peringatan", "Semua field wajib diisi.");
      return;
    }

    setState(() => isLoading = true);
    try {



      if (data['created'] == true) {
        _alert("Sukses", "✅ Akun berhasil dibuat!");
        createUsernameController.clear();
        createPasswordController.clear();
        createDayController.clear();
        _fetchUsers();
      } else {
        String msg = data['message'] ?? 'Gagal membuat akun.';
        if (data['invalidDay'] == true) {
          msg += " (Max 30 hari untuk Reseller)";
        }
        _alert("Gagal", "❌ $msg");
      }
    } catch (e) {
      _alert("Error", "❌ Koneksi error: $e");
    }
    setState(() => isLoading = false);
  }

  Future<void> _editUser() async {



    if (u.isEmpty || d.isEmpty) {
      _alert("Peringatan", "Semua field wajib diisi.");
      return;
    }

    setState(() => isLoading = true);
    try {



      if (data['edited'] == true) {
        _alert("Sukses", "✅ Durasi berhasil diperbarui.");
        editUsernameController.clear();
        editDayController.clear();
        _fetchUsers();
      } else {
        _alert("Gagal", "❌ ${data['message'] ?? 'Gagal mengubah durasi.'}");
      }
    } catch (e) {
      _alert("Error", "❌ Koneksi error: $e");
    }
    setState(() => isLoading = false);
  }

  void _alert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bgDark, bgDark.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: accentRed.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: redGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Icon(
                    title == "Sukses" ? Icons.check_circle : Icons.warning_rounded,
                    color: primaryWhite,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: primaryWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: softGrey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: redGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "OK",
                          style: TextStyle(
                            color: primaryWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType type = TextInputType.text,
    String hint = "",
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: glassSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryWhite.withOpacity(0.1)),
        ),
        child: TextField(
          controller: controller,
          keyboardType: type,
          style: const TextStyle(color: primaryWhite),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: TextStyle(color: softGrey.withOpacity(0.5)),
            labelStyle: const TextStyle(color: softGrey),
            prefixIcon: Icon(icon, color: accentRed, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: glassPrimary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryWhite.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: accentRed.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: redGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: primaryWhite, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: primaryWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildUserItem(Map user) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 300),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: glassSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryWhite.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: redGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentRed.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                user['username'][0].toUpperCase(),
                style: const TextStyle(
                  color: primaryWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['username'],
                    style: const TextStyle(
                      color: primaryWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accentRed.withOpacity(0.3)),
                        ),
                        child: Text(
                          user['role'].toString().toUpperCase(),
                          style: TextStyle(
                            color: accentRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Exp: ${user['expiredDate']}",
                        style: const TextStyle(color: softGrey, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(totalPages, (index) {

        return GestureDetector(
          onTap: () => setState(() => currentPage = page),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: currentPage == page ? redGradient : null,
              color: currentPage == page ? null : glassSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: currentPage == page ? accentRed : primaryWhite.withOpacity(0.1),
              ),
            ),
            child: Text(
              "$page",
              style: TextStyle(
                color: currentPage == page ? primaryWhite : softGrey,
                fontSize: 12,
                fontWeight: currentPage == page ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(scale: value, child: child),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: redGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accentRed.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.storefront,
                              color: primaryWhite,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShaderMask(
                          shaderCallback: (bounds) => redGradient.createShader(bounds),
                          child: const Text(
                            "SELLER DASHBOARD",
                            style: TextStyle(
                              color: primaryWhite,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // CREATE MEMBER CARD
                  _buildGlassCard(
                    title: "CREATE MEMBER",
                    icon: FontAwesomeIcons.userPlus,
                    children: [
                      _buildInput(
                        label: "Username Baru",
                        controller: createUsernameController,
                        icon: FontAwesomeIcons.user,
                      ),
                      _buildInput(
                        label: "Password",
                        controller: createPasswordController,
                        icon: FontAwesomeIcons.lock,
                      ),
                      _buildInput(
                        label: "Durasi (Hari)",
                        controller: createDayController,
                        icon: FontAwesomeIcons.calendarDay,
                        type: TextInputType.number,
                        hint: "Maksimal 30 hari",
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: redGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _createAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryWhite,
                                  ),
                                )
                              : const Text(
                                  "CREATE ACCOUNT",
                                  style: TextStyle(
                                    color: primaryWhite,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),

                  // EXTEND DURATION CARD
                  _buildGlassCard(
                    title: "EXTEND DURATION",
                    icon: FontAwesomeIcons.clock,
                    children: [
                      _buildInput(
                        label: "Username Target",
                        controller: editUsernameController,
                        icon: FontAwesomeIcons.userEdit,
                        hint: "Username member yang ingin diperpanjang",
                      ),
                      _buildInput(
                        label: "Tambah Hari",
                        controller: editDayController,
                        icon: FontAwesomeIcons.calendarPlus,
                        type: TextInputType.number,
                        hint: "Maksimal 30 hari",
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: redGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _editUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryWhite,
                                  ),
                                )
                              : const Text(
                                  "ADD DAYS",
                                  style: TextStyle(
                                    color: primaryWhite,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),

                  // MEMBER LIST CARD
                  _buildGlassCard(
                    title: "MEMBER LIST",
                    icon: FontAwesomeIcons.users,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: glassSecondary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryWhite.withOpacity(0.1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRole,
                            dropdownColor: bgDark,
                            style: const TextStyle(color: primaryWhite),
                            items: roleOptions.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role.toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                selectedRole = val;
                                _filterAndPaginate();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: accentRed,
                                strokeWidth: 3,
                              ),
                            )
                          : Column(
                              children: [
                                ..._getCurrentPageData()
                                    .map((u) => _buildUserItem(u))
                                    .toList(),
                                const SizedBox(height: 16),
                                _buildPagination(),
                              ],
                            ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Grid Painter for background


// ucapan_page.dart

class UcapanPage extends StatefulWidget {




  const UcapanPage({super.key, this.sessionKey, this.username, this.role});

  @override
  State<UcapanPage> createState() => _UcapanPageState();
}

class _UcapanPageState extends State<UcapanPage> {
  List<UcapanModel> _ucapanList = [];
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _pesanController = TextEditingController();

  String? _sessionKey;
  String? _username;
  String? _role;

  // --- MODERN RED THEME (sama dengan dashboard) ---













  // Kata-kata kasar (filter client side juga)
  final List<String> _forbiddenWords = [
    'anjing', 'bangsat', 'kontol', 'memek', 'ngentot', 'jembut', 'peler',
    'toket', 'goblok', 'tolol', 'babi', 'asu', 'sialan', 'brengsek',
    'kampret', 'bajingan', 'tai', 'ampas'
  ];

  String _filterText(String text) {
    String filtered = text;
    for (String word in _forbiddenWords) {
      if (filtered.toLowerCase().contains(word.toLowerCase())) {
        filtered = filtered.replaceAll(RegExp(word, caseSensitive: false), '****');
      }
    }
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {

    _sessionKey = widget.sessionKey ?? prefs.getString('sessionKey') ?? '';
    _username = widget.username ?? prefs.getString('username') ?? '';
    _role = widget.role ?? prefs.getString('role') ?? 'member';

    _namaController.text = _username ?? '';
    await _loadUcapan();
  }

  Future<void> _loadUcapan() async {
    setState(() => _isLoading = true);

    try {


      if (response.statusCode == 200) {

        if (data['valid'] == true) {
          setState(() {
            _ucapanList = (data['ucapan'] as List)
                .map((item) => UcapanModel.fromJson(item))
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error loading ucapan: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _tambahUcapan() async {
    final nama = _namaController.text.trim();
    final pesan = _pesanController.text.trim();

    if (nama.isEmpty || pesan.isEmpty) {
      _showSnackBar('Nama dan pesan tidak boleh kosong', isError: true);
      return;
    }

    if (pesan.length > 500) {
      _showSnackBar('Pesan maksimal 500 karakter', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {


      if (data['valid'] == true) {
        _pesanController.clear();
        await _loadUcapan();

        if (mounted) {
          _showSnackBar('✅ Ucapan berhasil dikirim!', isError: false);
        }
      } else {
        _showSnackBar(data['message'] ?? 'Gagal mengirim ucapan', isError: true);
      }
    } catch (e) {
      print('Error: $e');
      _showSnackBar('Gagal mengirim ucapan', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _likeUcapan(String id, String type) async {
    setState(() => _isLoading = true);

    try {


      if (response.statusCode == 200) {

        if (data['valid'] == true) {
          setState(() {
            final index = _ucapanList.indexWhere((u) => u.id == id);
            if (index != -1) {
              _ucapanList[index] = UcapanModel(
                id: _ucapanList[index].id,
                nama: _ucapanList[index].nama,
                pesan: _ucapanList[index].pesan,
                waktu: _ucapanList[index].waktu,
                likes: data['likes'],
                dislikes: data['dislikes'],
              );
            }
          });

          String message = '';
          if (data['action'] == 'liked') message = 'Berhasil like';
          else if (data['action'] == 'unliked') message = 'Batal like';
          else if (data['action'] == 'disliked') message = 'Berhasil dislike';
          else if (data['action'] == 'undisliked') message = 'Batal dislike';

          _showSnackBar(message, isError: false);
        }
      }
    } catch (e) {
      print('Error like: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUcapan(String id) async {
    if (_role != 'owner') return;

          },
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bgDark, bgDark.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: accentRed.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.white70, size: 32),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Hapus Ucapan",
                  style: TextStyle(
                    color: primaryWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Yakin ingin menghapus ucapan ini?",
                  style: TextStyle(color: softGrey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Center(
                            child: Text(
                              "BATAL",
                              style: TextStyle(color: softGrey, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: const Center(
                            child: Text(
                              "HAPUS",
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {


      if (data['valid'] == true) {
        await _loadUcapan();
        _showSnackBar('Ucapan berhasil dihapus', isError: false);
      }
    } catch (e) {
      print('Error delete: $e');
    }
  }

  String _formatWaktu(String isoString) {
    try {
      final waktu = DateTime.parse(isoString).toLocal();

      final diff = now.difference(waktu);

      if (diff.inMinutes < 1) return 'baru saja';
      if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
      if (diff.inDays < 1) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return '${diff.inDays ~/ 7} minggu lalu';
    } catch (e) {
      return 'baru saja';
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: primaryWhite,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: primaryWhite, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.grey.withOpacity(0.9) : accentRed.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showTambahUcapanDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bgDark, bgDark.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: accentRed.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: accentRed.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: redGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, color: primaryWhite, size: 28),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Kirim Ucapan",
                  style: TextStyle(
                    color: primaryWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Kirim ucapan spesial untuk aplikasi",
                  style: TextStyle(color: softGrey, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: glassSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryWhite.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _namaController,
                    style: const TextStyle(color: primaryWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Nama Anda",
                      hintStyle: TextStyle(color: softGrey.withOpacity(0.5)),
                      prefixIcon: const Icon(Icons.person, color: accentRed, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: glassSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryWhite.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _pesanController,
                    style: const TextStyle(color: primaryWhite, fontSize: 14),
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Pesan ucapan...",
                      hintStyle: TextStyle(color: softGrey.withOpacity(0.5)),
                      prefixIcon: const Icon(Icons.edit_note, color: accentRed, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: warningOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: warningOrange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: warningOrange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dilarang menggunakan kata-kata kasar',
                          style: TextStyle(color: warningOrange, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Center(
                            child: Text(
                              "BATAL",
                              style: TextStyle(color: softGrey, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _tambahUcapan();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: redGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: accentRed.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "KIRIM",
                              style: TextStyle(color: primaryWhite, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: redGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.card_giftcard_rounded, color: primaryWhite, size: 18),
              const SizedBox(width: 8),
              const Text(
                "KIRIM UCAPAN",
                style: TextStyle(
                  color: primaryWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: glassSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: accentRed, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              gradient: redGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: primaryWhite, size: 20),
              onPressed: _showTambahUcapanDialog,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: accentRed, strokeWidth: 3),
                )
              : _ucapanList.isEmpty
                  ? Center(
                      child: TweenAnimationBuilder(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween<double>(begin: 0, end: 1),
                        builder: (context, double value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [accentRed.withOpacity(0.1), darkRed.withOpacity(0.1)],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: accentRed.withOpacity(0.2)),
                              ),
                              child: const Icon(Icons.card_giftcard_rounded, size: 70, color: accentRed),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Belum ada ucapan',
                              style: TextStyle(color: softGrey, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _showTambahUcapanDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: redGradient,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentRed.withOpacity(0.4),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add, color: primaryWhite, size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "BUAT UCAPAN PERTAMA",
                                      style: TextStyle(
                                        color: primaryWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _ucapanList.length,
                      itemBuilder: (context, index) {
                        final ucapan = _ucapanList[index];
                        return TweenAnimationBuilder(
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          tween: Tween<double>(begin: 0, end: 1),
                          builder: (context, double value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: glassPrimary,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: primaryWhite.withOpacity(0.08)),
                              boxShadow: [
                                BoxShadow(
                                  color: accentRed.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          gradient: redGradient,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: accentRed.withOpacity(0.3),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            ucapan.nama.isNotEmpty ? ucapan.nama[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                              color: primaryWhite,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ucapan.nama,
                                              style: const TextStyle(
                                                color: primaryWhite,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              ucapan.pesan,
                                              style: TextStyle(color: softGrey, fontSize: 13, height: 1.4),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(Icons.access_time, size: 12, color: softGrey),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatWaktu(ucapan.waktu),
                                                  style: TextStyle(color: softGrey, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_role == 'owner')
                                        GestureDetector(
                                          onTap: () => _deleteUcapan(ucapan.id),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.delete_outline, color: Colors.white70, size: 18),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Like & Dislike buttons
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _likeUcapan(ucapan.id, 'like'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: accentRed.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: accentRed.withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.thumb_up_alt_outlined, color: accentRed, size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${ucapan.likes}',
                                                style: const TextStyle(color: accentRed, fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: () => _likeUcapan(ucapan.id, 'dislike'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.thumb_down_alt_outlined, color: softGrey, size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${ucapan.dislikes}',
                                                style: TextStyle(color: softGrey, fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

// Model untuk ucapan
class UcapanModel {

  final String nama;
  final String pesan;
  final String waktu;
  final int likes;
  final int dislikes;

  UcapanModel({
    required this.id,
    required this.nama,
    required this.pesan,
    required this.waktu,
    required this.likes,
    required this.dislikes,
  });

  factory UcapanModel.fromJson(Map<String, dynamic> json) {
    return UcapanModel(
      id: json['id'] ?? '',
      nama: json['nama'] ?? '',
      pesan: json['pesan'] ?? '',
      waktu: json['waktu'] ?? DateTime.now().toIso8601String(),
      likes: json['likes'] ?? 0,
      dislikes: json['dislikes'] ?? 0,
    );
  }
}

// Custom Grid Painter for background


// riwayat_page.dart

class RiwayatPage extends StatefulWidget {



  const RiwayatPage({
    super.key,
    required this.sessionKey,
    required this.role,
  });

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  // --- MODERN RED THEME (sama dengan dashboard) ---










  List<ActivityModel> activities = [];


  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    const baseUrl = "$apiBaseUrl";

    try {


      if (response.statusCode == 200) {

        if (data['valid']) {
          List<dynamic> rawList = data['activities'];

          setState(() {
            activities = rawList.map((item) {
              return ActivityModel(
                type: item['type'] ?? 'system',
                title: item['title'] ?? 'Aktivitas',
                description: item['description'] ?? '-',
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                    item['timestamp'] ?? DateTime.now().millisecondsSinceEpoch
                ),
              );
            }).toList();
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } else {
        print("Server Error: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching history: $e");
      setState(() => isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: redGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Text(
            "RIWAYAT AKTIVITAS",
            style: TextStyle(
              color: primaryWhite,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: glassSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: accentRed, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: accentRed,
                    strokeWidth: 3,
                  ),
                )
              : activities.isEmpty
                  ? Center(
                      child: TweenAnimationBuilder(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween<double>(begin: 0, end: 1),
                        builder: (context, double value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [accentRed.withOpacity(0.1), darkRed.withOpacity(0.1)],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: accentRed.withOpacity(0.2)),
                              ),
                              child: const Icon(Icons.history_toggle_off, size: 60, color: accentRed),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Belum ada aktivitas",
                              style: TextStyle(
                                color: softGrey,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Pastikan server aktif",
                              style: TextStyle(
                                color: softGrey.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadActivities,
                      color: accentRed,
                      backgroundColor: glassSecondary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: activities.length,
                        itemBuilder: (context, index) {
                          final activity = activities[index];
                          return TweenAnimationBuilder(
                            duration: Duration(milliseconds: 300 + (index * 50)),
                            tween: Tween<double>(begin: 0, end: 1),
                            builder: (context, double value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: _buildActivityCard(activity, index),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityModel activity, int index) {
    Color iconColor;
    IconData iconData;
    LinearGradient iconGradient;
    String typeLabel;

    switch (activity.type) {
      case 'login':
        iconColor = Colors.greenAccent;
        iconData = Icons.login_rounded;
        iconGradient = const LinearGradient(
        colors: [Color(0xFF1A1A1A), Color(0xFF424242)],
        );
        typeLabel = "LOGIN";
        break;
      case 'bug':
        iconColor = Colors.orangeAccent;
        iconData = Icons.bug_report_outlined;
        iconGradient = const LinearGradient(
        colors: [Color(0xFF1A1A1A), Color(0xFF424242)],
        );
        typeLabel = "ATTACK";
        break;
      case 'create':
        iconColor = Colors.cyanAccent;
        iconData = Icons.person_add_alt_1_rounded;
        iconGradient = const LinearGradient(
        colors: [Color(0xFF1A1A1A), Color(0xFF424242)],
        );
        typeLabel = "ACCOUNT";
        break;
      default:
        iconColor = softGrey;
        iconData = Icons.info_outline;
        iconGradient = const LinearGradient(
        colors: [Color(0xFF1A1A1A), Color(0xFF424242)],
        );
        typeLabel = "SYSTEM";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: glassPrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryWhite.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: accentRed.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: iconGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(iconData, color: primaryWhite, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        activity.title,
                        style: const TextStyle(
                          color: primaryWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentRed.withOpacity(0.3)),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          color: accentRed,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  activity.description,
                  style: TextStyle(
                    color: softGrey,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 12, color: softGrey.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(activity.timestamp),
                      style: TextStyle(
                        color: softGrey.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityModel {
  final String type;
  final String title;
  final String description;
  final DateTime timestamp;

  ActivityModel({
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
  });
}

// Custom Grid Painter for background


// tools_page.dart

class ToolsPage extends StatelessWidget {

  final String userRole;


  const ToolsPage({
    super.key,
    required this.sessionKey,
    required this.userRole,
    required this.listDoos,
  });

  // --- MODERN RED THEME ---











  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              accentRed.withOpacity(0.15),
              bgDark,
              bgDark,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: SafeArea(
            child: Column(
              children: [
                // === GLASS HEADER ===
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    children: [
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.8, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutBack,
                        builder: (context, double scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: redGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accentRed.withOpacity(0.5),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.build_circle_outlined,
                                  color: primaryWhite,
                                  size: 42,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      ShaderMask(
                        shaderCallback: (bounds) => redGradient.createShader(bounds),
                        child: const Text(
                          "Tools Dashboard",
                          style: TextStyle(
                            color: primaryWhite,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: glassSecondary,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryWhite.withOpacity(0.08)),
                        ),
                        child: Text(
                          "Advanced Security & OSINT Tools",
                          style: TextStyle(color: softGrey, fontSize: 12, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // === GLASS CATEGORY CARDS ===
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.1,
                      children: [
                        _buildGlassToolCard(
                          icon: Icons.flash_on_rounded,
                          title: "DDoS Tools",
                          subtitle: "Attack Panel",
                          gradient: redGradient,
                          onTap: () => _showDDoSTools(context),
                        ),
                        _buildGlassToolCard(
                          icon: Icons.wifi_rounded,
                          title: "Network",
                          subtitle: "WiFi & Spam",
                          gradient: secondaryGradient,
                          onTap: () => _showNetworkTools(context),
                        ),
                        _buildGlassToolCard(
                          icon: Icons.search_rounded,
                          title: "OSINT",
                          subtitle: "Investigation",
                          gradient: redGradient,
                          onTap: () => _showOSINTTools(context),
                        ),
                        _buildGlassToolCard(
                          icon: Icons.download_rounded,
                          title: "Downloader",
                          subtitle: "Social Media",
                          gradient: secondaryGradient,
                          onTap: () => _showDownloaderTools(context),
                        ),
                        _buildGlassToolCard(
                          icon: Icons.build_rounded,
                          title: "Utilities",
                          subtitle: "Extra Tools",
                          gradient: redGradient,
                          onTap: () => _showUtilityTools(context),
                        ),
                        _buildGlassToolCard(
                          icon: Icons.rocket_launch_rounded,
                          title: "Quick Access",
                          subtitle: "Favorites",
                          gradient: secondaryGradient,
                          onTap: () => _showComingSoon(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, double scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: glassPrimary,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primaryWhite.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end, // KE BAWAH (BOTTOM)
              crossAxisAlignment: CrossAxisAlignment.start, // KE KIRI (LEFT)
              children: [
                const Spacer(), // Mendorong ke bawah
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: primaryWhite, size: 26),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: primaryWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: softGrey, fontSize: 11, letterSpacing: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGlassBottomSheet(BuildContext context, String title, IconData icon, List<Widget> children) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: bgDark,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          border: Border.all(color: primaryWhite.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: glassPrimary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: redGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentRed.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: primaryWhite, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      color: primaryWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: children,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDDoSTools(BuildContext context) {
    _showGlassBottomSheet(
      context,
      "DDoS Tools",
      Icons.flash_on_rounded,
      [
        _buildGlassToolOption(
          icon: Icons.flash_on_rounded,
          label: "Attack Panel",
          description: "Launch DDoS attacks with power",
          color: accentRed,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttackPanel(
                  sessionKey: sessionKey,
                  listDoos: listDoos,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildGlassToolOption(
          icon: Icons.dns_rounded,
          label: "Manage Server",
          description: "Configure server settings",
          color: softRed,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ManageServerPage(keyToken: sessionKey),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showNetworkTools(BuildContext context) {
    List<Widget> options = [
      _buildGlassToolOption(
        icon: Icons.message_rounded,
        label: "Spam NGL",
        description: "Anonymous message spam",
        color: accentRed,
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NglPage()),
          );
        },
      ),
      const SizedBox(height: 12),
      _buildGlassToolOption(
        icon: Icons.wifi_off_rounded,
        label: "WiFi Killer (Internal)",
        description: "Internal network attacks",
        color: softRed,
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WifiKillerPage()),
          );
        },
      ),
    ];

    if (userRole == "vip" || userRole == "owner" || userRole == "reseller") {
      options.addAll([
        const SizedBox(height: 12),
        _buildGlassToolOption(
          icon: Icons.router_rounded,
          label: "WiFi Killer (External)",
          description: "External network attacks",
          color: darkRed,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WifiInternalPage(sessionKey: sessionKey),
              ),
            );
          },
        ),
      ]);
    }

    _showGlassBottomSheet(context, "Network Tools", Icons.wifi_rounded, options);
  }

  void _showOSINTTools(BuildContext context) {
    _showGlassBottomSheet(
      context,
      "OSINT Tools",
      Icons.search_rounded,
      [
        _buildGlassToolOption(
          icon: Icons.badge_rounded,
          label: "NIK Detail",
          description: "Indonesian ID card lookup",
          color: accentRed,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NikCheckerPage()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildGlassToolOption(
          icon: Icons.domain_rounded,
          label: "Domain OSINT",
          description: "Domain information gathering",
          color: softRed,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DomainOsintPage()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildGlassToolOption(
  icon: Icons.phone_android_rounded,
  label: "Phone Lookup",
  description: "Cek informasi nomor telepon",
  color: accentRed,
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhoneLookupPage(
          sessionKey: sessionKey,
        ),
      ),
    );
  },
),
      ],
    );
  }

  void _showDownloaderTools(BuildContext context) {
    _showGlassBottomSheet(
      context,
      "Media Downloader",
      Icons.download_rounded,
      [
        _buildGlassToolOption(
          icon: Icons.video_library_rounded,
          label: "TikTok Downloader",
          description: "Download TikTok videos without watermark",
          color: accentRed,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TiktokDownloaderPage()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildGlassToolOption(
          icon: Icons.camera_alt_rounded,
          label: "Instagram Downloader",
          description: "Download Instagram content",
          color: softRed,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const InstagramDownloaderPage()),
            );
          },
        ),
      ],
    );
  }

  void _showUtilityTools(BuildContext context) {
    _showGlassBottomSheet(
      context,
      "Utility Tools",
      Icons.build_rounded,
      [
        _buildGlassToolOption(
          icon: Icons.qr_code_rounded,
          label: "QR Generator",
          description: "Generate QR codes instantly",
          color: accentRed,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QrGeneratorPage()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildGlassToolOption(
  icon: Icons.link_rounded,
  label: "Shortlink URL",
  description: "Pendekkan URL panjangmu",
  color: accentRed,
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShortlinkPage(
          sessionKey: sessionKey,
        ),
      ),
    );
  },
),
const SizedBox(height: 12),
  _buildGlassToolOption(
  icon: Icons.dns_rounded,
  label: "IP Scanner",
  description: "Cek informasi alamat IP",
  color: accentRed,
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IpScannerPage(
          sessionKey: sessionKey,
        ),
      ),
    );
  },
),
      ],
    );
  }

  Widget _buildGlassToolOption({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: glassSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryWhite, size: 20),
          ),
          title: Text(
            label,
            style: const TextStyle(
              color: primaryWhite,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            description,
            style: TextStyle(
              color: softGrey,
              fontSize: 12,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: redGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: primaryWhite, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Coming Soon!',
              style: TextStyle(
                color: primaryWhite,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: glassPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primaryWhite.withOpacity(0.08)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Custom Grid Painter for background


// toko_page.dart

class TokoPage extends StatelessWidget {
  const TokoPage({super.key});

  // --- MODERN RED THEME (sama dengan dashboard) ---










  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: redGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_rounded, color: primaryWhite, size: 18),
              const SizedBox(width: 8),
              const Text(
                "TRICT CRASHER",
                style: TextStyle(
                  color: primaryWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: glassSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: accentRed, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Empty state message
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: value,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      decoration: BoxDecoration(
                        color: glassPrimary,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: primaryWhite.withOpacity(0.08),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentRed.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accentRed.withOpacity(0.1), darkRed.withOpacity(0.1)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: accentRed.withOpacity(0.2)),
                            ),
                            child: const Icon(
                              FontAwesomeIcons.boxOpen,
                              size: 48,
                              color: accentRed,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ShaderMask(
                            shaderCallback: (bounds) => redGradient.createShader(bounds),
                            child: const Text(
                              'BELUM ADA PRODUK',
                              style: TextStyle(
                                color: primaryWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada produk yang tersedia saat ini.\nSilakan cek kembali nanti.',
                            style: TextStyle(
                              color: softGrey,
                              fontSize: 13,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          // Decorative dot pattern
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              3,
                              (index) => AnimatedContainer(
                                duration: Duration(milliseconds: 400 + (index * 100)),
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  gradient: redGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentRed.withOpacity(0.5),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Grid Painter for background


// weather_page.dart

class WeatherPage extends StatefulWidget {



  const WeatherPage({
    super.key,
    required this.sessionKey,
    required this.username,
  });

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {


  Map<String, dynamic>? _weatherData;


  // --- MODERN RED THEME ---









  Future<void> _fetchWeather() async {

    if (city.isEmpty) {
      setState(() {
        _errorMessage = "Masukkan nama kota";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _weatherData = null;
    });

    try {
      final url = Uri.parse("https://api.siputzx.my.id/api/info/cuaca?q=$city");


      if (response.statusCode == 200) {

        if (data['status'] == true) {
          setState(() {
            _weatherData = data['data'];
          });
        } else {
          setState(() {
            _errorMessage = "Kota tidak ditemukan";
          });
        }
      } else {
        setState(() {
          _errorMessage = "Gagal mengambil data cuaca";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Koneksi gagal: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  IconData _getWeatherIconData(String weatherDesc) {
    if (weatherDesc.contains("Cerah")) return Icons.wb_sunny;
    if (weatherDesc.contains("Berawan")) return Icons.cloud;
    if (weatherDesc.contains("Hujan")) return Icons.beach_access;
    if (weatherDesc.contains("Petir")) return Icons.flash_on;
    if (weatherDesc.contains("Kabut")) return Icons.cloud_queue;
    if (weatherDesc.contains("Angin")) return Icons.air;
    return Icons.help_outline;
  }

  IconData _getWindDirectionIcon(String wd) {
    if (wd == "U") return Icons.navigation;
    if (wd == "S") return Icons.south;
    if (wd == "T") return Icons.east;
    if (wd == "B") return Icons.west;
    if (wd == "TL") return Icons.north_east;
    if (wd == "TG") return Icons.south_east;
    if (wd == "BL") return Icons.north_west;
    if (wd == "BG") return Icons.south_west;
    return Icons.compass_calibration;
  }

  @override
  Widget build(BuildContext context) {
    // Ambil data cuaca pertama (current weather)
    Map<dynamic, dynamic>? currentWeather;
    String? locationName;
    String? provinsi;
    String? kotkab;

    if (_weatherData != null) {
      final weatherList = _weatherData!['weather'] as List?;
      if (weatherList != null && weatherList.isNotEmpty) {
        final firstWeather = weatherList[0];
        final lokasi = firstWeather['lokasi'] as Map?;
        if (lokasi != null) {
          provinsi = lokasi['provinsi'];
          kotkab = lokasi['kotkab'];
          locationName = lokasi['desa'] ?? lokasi['kecamatan'];
        }
        
        final cuacaList = firstWeather['cuaca'] as List?;
        if (cuacaList != null && cuacaList.isNotEmpty) {
          final firstCuaca = cuacaList[0] as List?;
          if (firstCuaca != null && firstCuaca.isNotEmpty) {
            currentWeather = firstCuaca[0] as Map?;
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: redGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Text(
            "CEK CUACA",
            style: TextStyle(
              color: primaryWhite,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: glassSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryWhite.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: accentRed, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [accentRed.withOpacity(0.15), bgDark, bgDark],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: glassSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryWhite.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _cityController,
                    style: const TextStyle(color: primaryWhite),
                    decoration: InputDecoration(
                      hintText: "Cari kota...",
                      hintStyle: TextStyle(color: softGrey.withOpacity(0.5)),
                      prefixIcon: const Icon(Icons.search, color: accentRed),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded, color: accentRed),
                        onPressed: _fetchWeather,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onSubmitted: (_) => _fetchWeather(),
                  ),
                ),

                const SizedBox(height: 24),

                // Loading
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: accentRed),
                  ),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white70),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Weather Data
                if (_weatherData != null && currentWeather != null) ...[
                  // Lokasi Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: glassPrimary,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: primaryWhite.withOpacity(0.08)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.location_on_rounded, color: accentRed, size: 32),
                        const SizedBox(height: 12),
                        Text(
                          locationName ?? "Tidak diketahui",
                          style: const TextStyle(
                            color: primaryWhite,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (provinsi != null)
                          Text(
                            "$provinsi, $kotkab",
                            style: TextStyle(color: softGrey, fontSize: 13),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Cuaca Sekarang Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: redGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: accentRed.withOpacity(0.3),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Icon cuaca
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryWhite.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getWeatherIconData(currentWeather['weather_desc'] ?? ""),
                            color: primaryWhite,
                            size: 48,
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Suhu
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${currentWeather['t']?.toString() ?? "?"}°C",
                              style: const TextStyle(
                                color: primaryWhite,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              currentWeather['weather_desc'] ?? "Tidak diketahui",
                              style: const TextStyle(
                                color: primaryWhite,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Detail Cuaca (Info tambahan)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: glassPrimary,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: primaryWhite.withOpacity(0.08)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailItem(
                                icon: Icons.water_drop,
                                label: "Kelembaban",
                                value: "${currentWeather['hu'] ?? "?"}%",
                              ),
                            ),
                            Expanded(
                              child: _buildDetailItem(
                                icon: Icons.air,
                                label: "Kecepatan Angin",
                                value: "${currentWeather['ws'] ?? "?"} km/h",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailItem(
                                icon: _getWindDirectionIcon(currentWeather['wd'] ?? ""),
                                label: "Arah Angin",
                                value: currentWeather['wd'] ?? "?",
                              ),
                            ),
                            Expanded(
                              child: _buildDetailItem(
                                icon: Icons.visibility,
                                label: "Visibilitas",
                                value: currentWeather['vs_text'] ?? "?",
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Prakiraan 5 Jam ke Depan
                  const Text(
                    "PRAKIRAAN 5 JAM KE DEPAN",
                    style: TextStyle(
                      color: softGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _getNext5Weather().length,
                      itemBuilder: (context, index) {
                        final weather = _getNext5Weather()[index];
                        return Container(
                          width: 90,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: glassPrimary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryWhite.withOpacity(0.08)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                weather['time'] ?? "",
                                style: const TextStyle(
                                  color: accentRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Icon(
                                _getWeatherIconData(weather['weather_desc'] ?? ""),
                                color: primaryWhite,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${weather['t']?.toString() ?? "?"}°C",
                                style: const TextStyle(
                                  color: primaryWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: accentRed, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: primaryWhite,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: softGrey, fontSize: 11),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getNext5Weather() {
    if (_weatherData == null) return [];
    
    final weatherList = _weatherData!['weather'] as List?;
    if (weatherList == null || weatherList.isEmpty) return [];
    
    final firstWeather = weatherList[0];
    final cuacaList = firstWeather['cuaca'] as List?;
    if (cuacaList == null || cuacaList.isEmpty) return [];
    
    final firstCuaca = cuacaList[0] as List?;
    if (firstCuaca == null) return [];
    
    final List<Map<String, dynamic>> result = [];
    for (int i = 0; i < firstCuaca.length && i < 5; i++) {
      final item = firstCuaca[i] as Map;
      result.add({
        'time': _formatTime(item['local_datetime']),
        't': item['t'],
        'weather_desc': item['weather_desc'],
      });
    }
    return result;
  }

  String _formatTime(String? datetime) {
    if (datetime == null) return "";
    try {
      final parts = datetime.split(' ');
      if (parts.length > 1) {
        return parts[1].substring(0, 5);
      }
      return datetime;
    } catch (e) {

    }
  }
}

// Custom Grid Painter for background
