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

// [stripped relative import]
// [stripped relative import]
// [stripped relative import]
// [stripped relative import]
// [stripped relative import]
// [stripped relative import]
// [stripped relative import]
// [stripped relative import]
// [stripped relative import]
// [stripped relative import]
// [stripped relative import]
// [stripped relative import]
// [stripped relative import]
// [stripped relative import]

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