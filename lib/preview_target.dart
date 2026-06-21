// dashboard_page.dart
// Full convert dari dashboard.html (GENIUS) ke Flutter — full animation.
// Terhubung ke backend Node.js asli (lihat login_page.dart / splash.dart).

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'login_page.dart' show baseUrl;
import 'seller_page.dart';
import 'device_dashboard.dart';
import 'chat.dart';

// ════════════════ HELPER: format tanggal & sisa hari dari data backend ════════════════
DateTime _parseExpired(String raw) {
  try {
    return DateTime.parse(raw);
  } catch (_) {
    return DateTime.now();
  }
}

String _formatExpired(String raw) => DateFormat('dd-MM-yyyy').format(_parseExpired(raw));
int _daysLeftOf(String raw) => _parseExpired(raw).difference(DateTime.now()).inDays;
bool _isActiveOf(String raw) => _daysLeftOf(raw) > 0;

/// Normalisasi item news dari backend.
/// Backend bisa kirim key `desc` atau `description` — ditangani fleksibel di sini.
String _newsDesc(Map<String, dynamic> n) =>
    (n['desc'] ?? n['description'] ?? n['content'] ?? '').toString();
String _newsTitle(Map<String, dynamic> n) => (n['title'] ?? n['judul'] ?? '').toString();

// ─────────────────────────── THEME / COLORS ───────────────────────────
class AppColors {
  static const bg = Color(0xFFF4F7FB);
  static const bgDeep = Color(0xFFE8EFFA);
  static const surface = Color(0xFFFFFFFF);
  static const cardGlass = Color(0xCCFFFFFF);

  static const blue = Color(0xFF2F80FF);
  static const blueDeep = Color(0xFF1A5FE0);
  static const blueSoft = Color(0xFF7FB1FF);
  static const blueFaint = Color(0xFFE5EEFF);

  static const textPrimary = Color(0xFF161D2E);
  static const textSec = Color(0xFF656E85);
  static const textMuted = Color(0xFFA0A7BD);

  static const shadow = Color(0x142A4B8E);
  static const shadowSoft = Color(0x0A2A4B8E);
}

class ShadowUtils {
  static List<BoxShadow> get card => const [
        BoxShadow(color: AppColors.shadow, blurRadius: 24, offset: Offset(0, 8)),
        BoxShadow(color: AppColors.shadowSoft, blurRadius: 4, offset: Offset(0, 1)),
      ];
  static List<BoxShadow> get soft => const [
        BoxShadow(color: AppColors.shadowSoft, blurRadius: 10, offset: Offset(0, 3)),
      ];
  static List<BoxShadow> get heavy => const [
        BoxShadow(color: AppColors.shadow, blurRadius: 30, offset: Offset(0, 12)),
      ];
}

// ─────────────────────────── GLASS CARD ───────────────────────────
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.onTap,
    this.gradient,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.gradient == null ? AppColors.cardGlass : null,
        gradient: widget.gradient,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: AppColors.blue.withOpacity(0.10)),
        boxShadow: ShadowUtils.card,
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return container;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap!();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _pressed ? 0.97 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: _pressed ? 0.88 : 1.0,
          child: container,
        ),
      ),
    );
  }
}

// ─────────────────────────── FADE IN UP ───────────────────────────
class FadeInUp extends StatefulWidget {

  final Duration delay;
  const FadeInUp({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _offset = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved);
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

// ─────────────────────────── PULSE DOT ───────────────────────────
class PulseDot extends StatefulWidget {
  final Color color;
  const PulseDot({super.key, this.color = AppColors.blue});
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {

  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _a = Tween<double>(begin: 0.35, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color.withOpacity(0.5), blurRadius: 6)],
        ),
      ),
    );
  }
}

// ─────────────────────────── TYPEWRITER TITLE ───────────────────────────
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const TypewriterText({super.key, required this.text, required this.style});

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _shown = '';
  Timer? _timer;
  Timer? _loop;
  bool _cursorOn = true;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _run();
    _loop = Timer.periodic(const Duration(milliseconds: 9000), (_) => _run());
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _cursorOn = !_cursorOn);
    });
  }

  void _run() {
    _timer?.cancel();
    int i = 0;
    setState(() => _shown = '');
    _timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (i >= widget.text.length) {
        t.cancel();
        return;
      }
      setState(() => _shown += widget.text[i]);
      i++;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loop?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(style: widget.style, children: [
        TextSpan(text: _shown),
        TextSpan(
          text: '|',
          style: widget.style.copyWith(color: _cursorOn ? AppColors.blue : Colors.transparent),
        ),
      ]),
    );
  }
}

// ─────────────────────────── COUNT UP NUMBER ───────────────────────────
class CountUpNumber extends StatefulWidget {
  final int target;

  const CountUpNumber({super.key, required this.target, required this.style});

  @override
  State<CountUpNumber> createState() => _CountUpNumberState();
}

class _CountUpNumberState extends State<CountUpNumber> with SingleTickerProviderStateMixin {



  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _a = Tween<double>(begin: 0, end: widget.target.toDouble())
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Text(_a.value.round().toString(), style: widget.style),
    );
  }
}

// ─────────────────────────── DASHBOARD PAGE ───────────────────────────
class DashboardPage extends StatefulWidget {
  final String username, password, role, expiredDate, sessionKey;
  final List<Map<String, dynamic>> listBug, listDoos;
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

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  int _navIndex = 0;
  final PageController _newsController = PageController(viewportFraction: 0.92);
  int _newsCurrent = 0;
  Timer? _newsAutoTimer;

  late AnimationController _blobController;
  
  // Tambahan untuk Pairing ID
  String _pairingId = '';
  bool _isLoadingPairId = false;

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
    _newsAutoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_newsController.hasClients) return;
      _newsCurrent = (_newsCurrent + 1) % math.max(widget.news.length, 1);
      _newsController.animateToPage(_newsCurrent,
          duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    });
    
    // Fetch Pairing ID
    _fetchPairingId();
  }

  @override
  void dispose() {
    _newsAutoTimer?.cancel();
    _newsController.dispose();
    _blobController.dispose();
    super.dispose();
  }

  // Method untuk fetch Pairing ID dari backend
  Future<void> _fetchPairingId() async {
    if (_isLoadingPairId) return;
    setState(() => _isLoadingPairId = true);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rat/pairid?key=${widget.sessionKey}'),
        timeout: const Duration(seconds: 8),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid'] == true && data['pairId'] != null) {
          setState(() {
            _pairingId = data['pairId'].toString();
            _isLoadingPairId = false;
          });
        } else {
          setState(() => _isLoadingPairId = false);
        }
      } else {
        setState(() => _isLoadingPairId = false);
      }
    } catch (e) {
      print('Error fetching pair ID: $e');
      setState(() => _isLoadingPairId = false);
    }
  }

  // Method untuk copy Pairing ID
  void _copyPairingId() {
    if (_pairingId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _pairingId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pairing ID berhasil disalin!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openDrawerMenu() => _scaffoldKey.currentState?.openDrawer();

  void _openAccountSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AccountSheet(
        username: widget.username,
        role: widget.role,
        expiredDate: widget.expiredDate,
        pairingId: _pairingId,
        onCopy: _copyPairingId,
        onLogout: () {
          Navigator.pop(context);
          _openLogoutDialog();
        },
      ),
    );
  }

  void _openLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => LogoutDialog(
        onConfirm: () async {
          Navigator.pop(context);
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('username');
          await prefs.remove('password');
          await prefs.remove('key');
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        },
      ),
    );
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final daysLeft = math.max(_daysLeftOf(widget.expiredDate), 0);
    final progressPct = (math.min(1, math.max(0, _daysLeftOf(widget.expiredDate) / 30))).toDouble();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      drawer: AppDrawer(
        username: widget.username,
        role: widget.role,
        onSeller: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Seller Page (contoh navigasi)')));
        },
        onLogout: () {
          Navigator.pop(context);
          _openLogoutDialog();
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _AppBarRow(
              onMenuTap: _openDrawerMenu, 
              onAvatarTap: _openAccountSheet,
              pairingId: _pairingId,
              onCopyPairId: _copyPairingId,
            ),
            Expanded(
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _blobController,
                    builder: (context, _) => CustomPaint(
                      painter: _BlobPainter(t: _blobController.value),
                      size: Size.infinite,
                    ),
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    children: [
                      FadeInUp(
                        delay: Duration.zero,
                        child: _ProfileHero(
                          username: widget.username,
                          role: widget.role,
                          expiredDate: widget.expiredDate,
                          daysLeft: daysLeft,
                          pairingId: _pairingId,
                          onCopy: _copyPairingId,
                          isLoading: _isLoadingPairId,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        delay: const Duration(milliseconds: 80),
                        child: _StatusGrid(
                          expiredDate: widget.expiredDate,
                          daysLeft: daysLeft,
                          progressPct: progressPct,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeInUp(
                        delay: const Duration(milliseconds: 140),
                        child: const _SectionLabel(icon: Icons.article_outlined, label: 'NEWS & UPDATE'),
                      ),
                      FadeInUp(
                        delay: const Duration(milliseconds: 160),
                        child: _NewsCarousel(
                          news: widget.news,
                          controller: _newsController,
                          current: _newsCurrent,
                          onDot: (i) {
                            _newsCurrent = i;
                            _newsController.animateToPage(i,
                                duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
                          },
                          onPageChanged: (i) => setState(() => _newsCurrent = i),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeInUp(
                        delay: const Duration(milliseconds: 180),
                        child: const _SectionLabel(icon: Icons.sports_esports_outlined, label: 'RETRO ARCADE'),
                      ),
                      FadeInUp(
                        delay: const Duration(milliseconds: 190),
                        child: const DinoRunGame(),
                      ),
                      const SizedBox(height: 20),
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        child: const _SectionLabel(icon: Icons.bar_chart_rounded, label: 'STATISTIK PENGGUNA'),
                      ),
                      FadeInUp(
                        delay: const Duration(milliseconds: 210),
                        child: const UserGraphCard(),
                      ),
                      const SizedBox(height: 20),
                      FadeInUp(
                        delay: const Duration(milliseconds: 220),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          radius: 18,
                          onTap: () {
                            // launchUrl(Uri.parse('https://example.com/thanks_to.html'));
                          },
                          child: Row(
                            children: [
                              _miniIconBox(Icons.favorite_rounded),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('Thanks To — orang yang berkontribusi',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.blue, size: 18),
                            ],
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
      bottomNavigationBar: BottomNavBar(
        index: _navIndex,
        onChanged: (i) {
          HapticFeedback.selectionClick();
          setState(() => _navIndex = i);
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  username: widget.username,
                  sessionKey: widget.sessionKey,
                ),
              ),
            ).then((_) => setState(() => _navIndex = 0));
          } else if (i == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeviceDashboardPage(
                  username: widget.username,
                  role: widget.role,
                  sessionKey: widget.sessionKey,
                ),
              ),
            ).then((_) => setState(() => _navIndex = 0));
          }
        },
      ),
    );
  }

  static Widget _miniIconBox(IconData icon) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(colors: [AppColors.blueSoft, AppColors.blue]),
        ),
        child: Icon(icon, color: Colors.white, size: 15),
      );
}

// ─────────────────────────── APP BAR ───────────────────────────
// ─────────────────────────── APP BAR ───────────────────────────
class _AppBarRow extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onAvatarTap;
  final String pairingId;
  final VoidCallback onCopyPairId;

  const _AppBarRow({
    required this.onMenuTap,
    required this.onAvatarTap,
    this.pairingId = '',
    required this.onCopyPairId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.blueFaint)),
      ),
      child: Row(
        children: [
          _IconBtn(icon: Icons.menu, onTap: onMenuTap),
          const SizedBox(width: 14),
          Expanded(
            child: TypewriterText(
              text: 'GENIUS',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: 1.5, color: AppColors.textPrimary),
            ),
          ),
          // Pairing ID Button (jika ada)
          if (pairingId.isNotEmpty)
            GestureDetector(
              onTap: onCopyPairId,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // ← PERBAIKAN DI SINI
                decoration: BoxDecoration(
                  color: AppColors.blueFaint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link_rounded, color: AppColors.blueDeep, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'ID: ${pairingId.length > 8 ? '...${pairingId.substring(pairingId.length - 6)} : pairingId}',
                      style: TextStyle(
                        color: AppColors.blueDeep,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.copy_rounded, color: AppColors.blueDeep, size: 12),
                  ],
                ),
              ),
            ),
          GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(2), // ← PERBAIKAN DI SINI
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AppColors.blueSoft, AppColors.blue]),
                boxShadow: ShadowUtils.soft,
              ),
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: AppColors.blue, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: AppColors.blueFaint, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 18, color: AppColors.blueDeep),
      ),
    );
  }
}

// ─────────────────────────── BACKGROUND BLOBS ───────────────────────────
class _BlobPainter extends CustomPainter {
  final double t;
  const _BlobPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final a1 = math.sin(t * 2 * math.pi) * 16;
    final p1 = Paint()
      ..shader = RadialGradient(colors: [
        AppColors.blueSoft.withOpacity(0.28),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset(-20 + a1, -40 + a1), radius: 160));
    canvas.drawCircle(Offset(-20 + a1, -40 + a1), 160, p1);

    final a2 = math.sin(t * 2 * math.pi + 2) * 14;
    final p2 = Paint()
      ..shader = RadialGradient(colors: [
        AppColors.blue.withOpacity(0.16),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset(size.width + 20 + a2, size.height * 0.4 + a2), radius: 150));
    canvas.drawCircle(Offset(size.width + 20 + a2, size.height * 0.4 + a2), 150, p2);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) => oldDelegate.t != t;
}

// ─────────────────────────── SECTION LABEL ───────────────────────────
class _SectionLabel extends StatelessWidget {

  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(colors: [AppColors.blueSoft, AppColors.blue]),
              boxShadow: ShadowUtils.soft,
            ),
            child: Icon(icon, size: 13, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        ],
      ),
    );
  }
}

// ─────────────────────────── PROFILE HERO ───────────────────────────
class _ProfileHero extends StatelessWidget {
  final String username, role, expiredDate;


  final VoidCallback onCopy;
  final bool isLoading;

  const _ProfileHero({
    required this.username,
    required this.role,
    required this.expiredDate,
    required this.daysLeft,
    this.pairingId = '',
    required this.onCopy,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withOpacity(0.9), AppColors.blueFaint.withOpacity(0.7)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [AppColors.blue, AppColors.blueDeep]),
                  boxShadow: ShadowUtils.card,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            username,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const PulseDot(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(role.toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.blueDeep, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.event, size: 11, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('Berlaku hingga ${_formatExpired(expiredDate)}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Pairing ID Section
          if (pairingId.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blue.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.link_rounded, color: AppColors.blueDeep, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PAIRING ID',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pairingId,
                          style: TextStyle(
                            color: AppColors.blueDeep,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onCopy,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.blueSoft, AppColors.blue]),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: ShadowUtils.soft,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'COPY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isLoading) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blue.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.link_rounded, color: AppColors.blueDeep, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PAIRING ID',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: 16,
                          width: 120,
                          decoration: BoxDecoration(
                            color: AppColors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.blue,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── STATUS GRID ───────────────────────────
class _StatusGrid extends StatelessWidget {


  final double progressPct;
  const _StatusGrid({required this.expiredDate, required this.daysLeft, required this.progressPct});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(colors: [AppColors.blue, AppColors.blueDeep]),
                        boxShadow: ShadowUtils.soft,
                      ),
                      child: const Icon(Icons.shield_outlined, size: 15, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Text('MASA AKTIF',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    CountUpNumber(
                      target: daysLeft,
                      style: const TextStyle(color: AppColors.blueDeep, fontSize: 30, fontWeight: FontWeight.w800, height: 1),
                    ),
                    const SizedBox(width: 6),
                    const Text('hari', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 6,
                    color: AppColors.blueFaint,
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      tween: Tween(begin: 0, end: progressPct),
                      builder: (context, value, _) => FractionallySizedBox(
                        widthFactor: value,
                        child: Container(color: AppColors.blue),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: GlassCard(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: AppColors.blue.withOpacity(0.10), shape: BoxShape.circle),
                  child: Icon(
                    _isActiveOf(expiredDate) ? Icons.verified_rounded : Icons.error_outline_rounded,
                    color: AppColors.blue,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_isActiveOf(expiredDate) ? 'AKTIF' : 'EXPIRED',
                    style: const TextStyle(
                        color: AppColors.blueDeep, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                const SizedBox(height: 2),
                Text(_formatExpired(expiredDate), style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── NEWS CAROUSEL ───────────────────────────
class _NewsCarousel extends StatelessWidget {

  final PageController controller;
  final int current;
  final ValueChanged<int> onDot;
  final ValueChanged<int> onPageChanged;

  const _NewsCarousel({
    required this.news,
    required this.controller,
    required this.current,
    required this.onDot,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (news.isEmpty) {
      return Container(
        height: 190,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.blueFaint.withOpacity(0.5),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text('Belum ada update', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: controller,
            itemCount: news.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, i) {
              final n = Map<String, dynamic>.from(news[i] as Map);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.blueSoft, AppColors.blue]),
                        ),
                        child: const Center(
                          child: Icon(Icons.article_outlined, size: 38, color: Colors.white70),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, AppColors.blueDeep.withOpacity(0.75)],
                            stops: const [0.4, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_newsTitle(n),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(_newsDesc(n),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11)),
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(news.length, (i) {
            final active = i == current;
            return GestureDetector(
              onTap: () => onDot(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 22 : 6,
                height: 5,
                decoration: BoxDecoration(
                  color: active ? AppColors.blue : AppColors.blueFaint,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────── DINO RUN GAME ───────────────────────────
class DinoRunGame extends StatefulWidget {
  const DinoRunGame({super.key});

  @override
  State<DinoRunGame> createState() => _DinoRunGameState();
}

enum _GameState { idle, running, over }

class _Obstacle {
  double x;
  final double w;
  final double h;
  final int variant;
  _Obstacle({required this.x, required this.w, required this.h, required this.variant});
}

class _DinoRunGameState extends State<DinoRunGame> with SingleTickerProviderStateMixin {
  static const double groundY = 26;
  static const double playerW = 30, playerH = 34;
  static const double hitInset = 4;
  static const double gravity = 2300;
  static const double jumpVelocity = 480;
  static const double baseSpeed = 230;

  _GameState _state = _GameState.idle;
  double _velocityY = 0;
  double _playerBottom = groundY;
  double _speed = baseSpeed;
  double _score = 0;
  int _best = 0;
  final List<_Obstacle> _obstacles = [];
  double _spawnTimer = 0;
  double _nextSpawnAt = 900;
  Duration _lastTick = Duration.zero;
  Ticker? _ticker;
  final math.Random _rng = math.Random();
  double _boxWidth = 300;

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _resetGame() {
    _obstacles.clear();
    _velocityY = 0;
    _playerBottom = groundY;
    _speed = baseSpeed;
    _score = 0;
    _spawnTimer = 0;
    _nextSpawnAt = 900;
  }

  void _startGame() {
    _resetGame();
    _state = _GameState.running;
    _lastTick = Duration.zero;
    _ticker ??= createTicker(_onTick);
    _ticker!.start();
    setState(() {});
  }

  void _gameOver() {
    _state = _GameState.over;
    _best = math.max(_best, _score.floor());
    _ticker?.stop();
    setState(() {});
  }

  void _spawnObstacle() {
    final variant = _rng.nextInt(3);
    const sizes = [
      [16.0, 30.0],
      [12.0, 22.0],
      [22.0, 26.0],
    ];
    final s = sizes[variant];
    _obstacles.add(_Obstacle(x: _boxWidth + 10, w: s[0], h: s[1], variant: variant));
  }

  void _onTick(Duration elapsed) {
    if (_state != _GameState.running) return;
    if (_lastTick == Duration.zero) _lastTick = elapsed;
    final dt = math.min(0.032, (elapsed - _lastTick).inMicroseconds / 1e6);
    _lastTick = elapsed;

    _speed = baseSpeed + math.min(220, _score * 2.2);

    _velocityY -= gravity * dt;
    _playerBottom += _velocityY * dt;
    if (_playerBottom <= groundY) {
      _playerBottom = groundY;
      _velocityY = 0;
    }

    _spawnTimer += dt * 1000;
    if (_spawnTimer >= _nextSpawnAt) {
      _spawnTimer = 0;
      _nextSpawnAt = (750 + _rng.nextDouble() * 750 - math.min(300, _score * 3)).clamp(420, double.infinity);
      _spawnObstacle();
    }

    final pLeft = 30 + hitInset, pRight = 30 + playerW - hitInset;
    final pBottom = _playerBottom, pTop = _playerBottom + playerH;

    for (int i = _obstacles.length - 1; i >= 0; i--) {
      final o = _obstacles[i];
      o.x -= _speed * dt;
      if (o.x < -30) {
        _obstacles.removeAt(i);
        continue;
      }
      final obLeft = o.x + hitInset, obRight = o.x + o.w - hitInset;
      const obBottom = groundY;
      final obTop = groundY + o.h;
      final xOverlap = obRight > pLeft && obLeft < pRight;
      final yOverlap = pBottom < obTop && pTop > obBottom;
      if (xOverlap && yOverlap) {
        _gameOver();
        return;
      }
    }

    _score += dt * 12;
    setState(() {});
  }

  void _jumpOrStart() {
    if (_state == _GameState.idle || _state == _GameState.over) {
      _startGame();
      return;
    }
    if (_state == _GameState.running && _playerBottom == groundY) {
      _velocityY = jumpVelocity;
      HapticFeedback.lightImpact();
    }
  }

  Color _cactusColor(int variant) {
    switch (variant) {
      case 0:
        return const Color(0xFF3DBB6B);
      case 1:
        return const Color(0xFF2E9B57);
      default:
        return const Color(0xFF56CE82);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _boxWidth = constraints.maxWidth;
      return GestureDetector(
        onTap: _jumpOrStart,
        child: Container(
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.blue.withOpacity(0.25), width: 1.5),
            boxShadow: ShadowUtils.card,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFBFE6FF), Color(0xFFE8F6FF), Color(0xFFFFF3D6)],
              stops: [0, 0.55, 1],
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // sun
              Positioned(
                top: 14,
                right: 20,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Color(0xFFFFE45C), Color(0xFFFFC93C)]),
                    boxShadow: [BoxShadow(color: Color(0xB3FFC93C), blurRadius: 18)],
                  ),
                ),
              ),
              // ground dashed line
              Positioned(
                left: 0,
                right: 0,
                bottom: groundY,
                child: CustomPaint(painter: _DashedLinePainter(), size: const Size(double.infinity, 3)),
              ),
              // floor
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: groundY,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFD9C29A), Color(0xFFC7AC7B)],
                    ),
                  ),
                ),
              ),
              // obstacles
              for (final o in _obstacles)
                Positioned(
                  left: o.x,
                  bottom: groundY,
                  width: o.w,
                  height: o.h,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cactusColor(o.variant),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              // player
              Positioned(
                left: 30,
                bottom: _playerBottom,
                width: playerW,
                height: playerH,
                child: const Icon(Icons.pets, color: Color(0xFF3DBB6B), size: 28),
              ),
              // badges
              Positioned(
                top: 12,
                left: 12,
                child: _gameBadge('DINO RUN', AppColors.blueDeep),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _gameBadge('SCORE ${_score.floor().toString().padLeft(4, '0')}', const Color(0xFFE0822A)),
              ),
              if (_state == _GameState.idle)
                const Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Text(
                    'TAP TO START',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.blueDeep,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 3),
                  ),
                ),
              if (_state == _GameState.over)
                Positioned.fill(
                  child: Container(
                    color: AppColors.bg.withOpacity(0.55),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('GAME OVER',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFFE0473D),
                                letterSpacing: 1.5,
                                fontFamily: 'monospace')),
                        const SizedBox(height: 6),
                        Text('Tap untuk main lagi · Best $_best',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSec, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _gameBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.blue.withOpacity(0.2)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w900, fontSize: 11, fontFamily: 'monospace', letterSpacing: 1)),
      );
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.blueSoft
      ..strokeWidth = size.height;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 14, size.height / 2), paint);
      x += 22;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────── USER GRAPH ───────────────────────────
class UserGraphCard extends StatefulWidget {
  const UserGraphCard({super.key});

  @override
  State<UserGraphCard> createState() => _UserGraphCardState();
}

class _UserGraphCardState extends State<UserGraphCard> {
  late List<double> _values;
  late int _total;
  static const labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _values = List.generate(7, (_) => 40 + rng.nextDouble() * 160);
    _total = _values.fold(0.0, (a, b) => a + b).round();
  }

  @override
  Widget build(BuildContext context) {
    final maxV = _values.reduce(math.max);
    return GlassCard(
      child: SizedBox(
        height: 134,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(colors: [AppColors.blueSoft, AppColors.blue]),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, size: 13, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text('Pengguna Mingguan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.blueFaint, borderRadius: BorderRadius.circular(10)),
                  child: Text('$_total total',
                      style: const TextStyle(color: AppColors.blueDeep, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(_values.length, (i) {
                  final isLast = i == _values.length - 1;
                  final h = _values[i] / maxV;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeOutCubic,
                                tween: Tween(begin: 0, end: h),
                                builder: (context, value, _) => FractionallySizedBox(
                                  heightFactor: value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: isLast
                                            ? [AppColors.blueDeep, AppColors.blue]
                                            : [AppColors.blueSoft.withOpacity(0.7), AppColors.blue.withOpacity(0.85)],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(labels[i],
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── BOTTOM NAV ───────────────────────────
class BottomNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const BottomNavBar({super.key, required this.index, required this.onChanged});

  static const _items = [
    (Icons.grid_view_rounded, 'Home'),
    (Icons.chat_bubble_outline_rounded, 'Chat'),
    (Icons.devices_other_rounded, 'Device'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.blue.withOpacity(0.10)),
          boxShadow: ShadowUtils.heavy,
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final active = i == index;
            final (icon, label) = _items[i];
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: active ? const LinearGradient(colors: [AppColors.blueSoft, AppColors.blue]) : null,
                    boxShadow: active ? [const BoxShadow(color: Color(0x4D2F80FF), blurRadius: 14, offset: Offset(0, 4))] : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 19, color: active ? Colors.white : AppColors.textMuted),
                      if (active) ...[
                        const SizedBox(width: 7),
                        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────── DRAWER ───────────────────────────
class AppDrawer extends StatelessWidget {
  final String username, role;
  final VoidCallback onSeller;
  final VoidCallback onLogout;
  const AppDrawer({super.key, required this.username, required this.role, required this.onSeller, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.blueSoft, AppColors.blueDeep]),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 10),
                Text(username, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(12)),
                  child: Text(role.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DrawerItem(icon: Icons.storefront_outlined, title: 'Seller Page', onTap: onSeller),
                  const Divider(height: 24, color: AppColors.blueFaint),
                  _DrawerItem(icon: Icons.logout_rounded, title: 'Logout', color: AppColors.blueDeep, onTap: onLogout),
                  const Spacer(),
                  const Center(
                    child: Text('GENIUS', style: TextStyle(color: AppColors.textMuted, fontSize: 9, letterSpacing: 2)),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatefulWidget {

  final String title;


  const _DrawerItem({required this.icon, required this.title, this.color, required this.onTap});

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _pressed ? 0.98 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: AppColors.blueFaint, borderRadius: BorderRadius.circular(10)),
                child: Icon(widget.icon, size: 18, color: widget.color ?? AppColors.blue),
              ),
              const SizedBox(width: 14),
              Text(widget.title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: widget.color ?? AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── ACCOUNT SHEET ───────────────────────────
class AccountSheet extends StatelessWidget {





  const AccountSheet({
    super.key,
    required this.username,
    required this.role,
    required this.expiredDate,
    this.pairingId = '',
    required this.onCopy,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.blueFaint, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            tween: Tween(begin: 0.8, end: 1.0),
            builder: (context, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AppColors.blueSoft, AppColors.blueDeep]),
                boxShadow: ShadowUtils.card,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 34),
            ),
          ),
          const SizedBox(height: 10),
          Text(username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: AppColors.blueFaint, borderRadius: BorderRadius.circular(12)),
            child: Text(role.toUpperCase(), style: const TextStyle(color: AppColors.blueDeep, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Text('Berlaku: ${_formatExpired(expiredDate)}', style: const TextStyle(color: AppColors.textSec, fontSize: 12)),
          
          // Pairing ID di Account Sheet
          if (pairingId.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.blueFaint.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blue.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.link_rounded, color: AppColors.blueDeep, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PAIRING ID',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pairingId,
                          style: TextStyle(
                            color: AppColors.blueDeep,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onCopy,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.blueSoft, AppColors.blue]),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: ShadowUtils.soft,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'COPY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blueDeep,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── LOGOUT DIALOG ───────────────────────────
class LogoutDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const LogoutDialog({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withOpacity(0.96), AppColors.blueFaint.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.blue.withOpacity(0.14)),
          boxShadow: ShadowUtils.heavy,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [AppColors.blueSoft, AppColors.blueDeep]),
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            const Text('Konfirmasi Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Yakin ingin logout?', style: TextStyle(color: AppColors.textSec, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blueDeep,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SellerPage extends StatefulWidget {
  final String keyToken;

  const SellerPage({super.key, required this.keyToken});

  @override
  State<SellerPage> createState() => _SellerPageState();
}

class _SellerPageState extends State<SellerPage> with SingleTickerProviderStateMixin {
  final _newUser = TextEditingController();
  final _newPass = TextEditingController();
  final _days = TextEditingController();
  final _editUser = TextEditingController();
  final _editDays = TextEditingController();
  
  // Untuk akun permanen (tanpa expired)
  final _permUser = TextEditingController();
  final _permPass = TextEditingController();
  
  bool loading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _baseUrl;

  final Color deepPurple = const Color(0xFF120000);
  final Color mainPurple = const Color(0xFF2A0000);
  final Color accentPurple = const Color(0xFFCCCCCC);
  final Color deepBlack = const Color(0xFF120000);
  final Color cardDark = const Color(0xFF2A0000);
  final Color greenAccent = const Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _baseUrl = await ApiConfig.baseUrl;
      print('✅ Seller Page Base URL: $_baseUrl');
      
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..forward();
      _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    } catch (e) {
      print('❌ Failed to initialize seller page: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _newUser.dispose();
    _newPass.dispose();
    _days.dispose();
    _editUser.dispose();
    _editDays.dispose();
    _permUser.dispose();
    _permPass.dispose();
    super.dispose();
  }

  // Membuat akun dengan durasi (berlaku sampai tanggal tertentu)
  Future<void> _create() async {
    if (_baseUrl == null) return;
    final u = _newUser.text.trim(), p = _newPass.text.trim(), d = _days.text.trim();
    if (u.isEmpty || p.isEmpty || d.isEmpty) return _alert("Semua field wajib diisi");
    setState(() => loading = true);
    final res = await http.get(Uri.parse(
        "$_baseUrl/createAccount?key=${widget.keyToken}&newUser=$u&pass=$p&day=$d"));

    if (data['created'] == true) {
      _alert("Akun berhasil dibuat!", isSuccess: true);
      _newUser.clear(); _newPass.clear(); _days.clear();
    } else {
      _alert("${data['message'] ?? 'Gagal membuat akun.'}");
    }
    setState(() => loading = false);
  }

  // MEMBUAT AKUN PERMANEN (tanpa expired date / berlaku selamanya)
  Future<void> _createPermanent() async {
    if (_baseUrl == null) return;
    final u = _permUser.text.trim(), p = _permPass.text.trim();
    if (u.isEmpty || p.isEmpty) return _alert("Username dan Password wajib diisi");
    setState(() => loading = true);
    
    // Kirim day = 0 atau nilai khusus untuk menandakan akun permanen
    // Sesuaikan dengan API backend Anda
    final res = await http.get(Uri.parse(
        "$_baseUrl/createAccount?key=${widget.keyToken}&newUser=$u&pass=$p&day=0&permanent=true"));

    if (data['created'] == true) {
      _alert("Akun PERMANEN berhasil dibuat!", isSuccess: true);
      _permUser.clear(); _permPass.clear();
    } else {
      _alert("${data['message'] ?? 'Gagal membuat akun permanen.'}");
    }
    setState(() => loading = false);
  }

  // Mengubah durasi akun (menambah hari)
  Future<void> _edit() async {
    if (_baseUrl == null) return;
    final u = _editUser.text.trim(), d = _editDays.text.trim();
    if (u.isEmpty || d.isEmpty) return _alert("Username dan durasi wajib diisi");
    setState(() => loading = true);
    final res = await http.get(Uri.parse(
        "$_baseUrl/editUser?key=${widget.keyToken}&username=$u&addDays=$d"));

    if (data['edited'] == true) {
      _alert("Durasi berhasil diperbarui.", isSuccess: true);
      _editUser.clear(); _editDays.clear();
    } else {
      _alert("${data['message'] ?? 'Gagal mengubah durasi.'}");
    }
    setState(() => loading = false);
  }

  void _alert(String msg, {bool isSuccess = false}) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: isSuccess ? greenAccent : accentPurple.withOpacity(0.3), width: 1.5),
          ),
          content: Text(
            msg,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK", style: TextStyle(color: isSuccess ? greenAccent : accentPurple)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardDark,
            cardDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentPurple.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: mainPurple.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildGlassInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            cardDark,
            cardDark.withOpacity(0.8),
          ],
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        cursorColor: accentPurple,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: accentPurple),
          filled: false,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accentPurple.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accentPurple, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accentPurple.withOpacity(0.3)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: color ?? accentPurple, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepBlack,
      body: Stack(
        children: [
          // Background decorations
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    deepPurple.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    mainPurple.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      _buildGlassCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.store, color: accentPurple, size: 32),
                            const SizedBox(width: 12),
                            const Text(
                              "RESELLER PANEL",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // --- SECTION: BUAT AKUN PERMANEN (BARU) ---
                      _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("Buat Akun Permanen", Icons.star, color: greenAccent),
                            const Text(
                              "Akun member tanpa masa berlaku (selamanya)",
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            const SizedBox(height: 12),

                            _buildGlassInputField(
                              controller: _permUser,
                              label: "Username",
                              icon: Icons.person_outline,
                            ),

                            _buildGlassInputField(
                              controller: _permPass,
                              label: "Password",
                              icon: Icons.lock_outline,
                              obscureText: true,
                            ),

                            const SizedBox(height: 8),

                            _buildActionButton(
                              text: "BUAT AKUN PERMANEN",
                              icon: Icons.star,
                              onPressed: _createPermanent,
                              color: greenAccent,
                              isLoading: loading,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // --- SECTION: BUAT AKUN BIAYA (dengan durasi) ---
                      _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("Buat Akun Berbayar", Icons.person_add),

                            _buildGlassInputField(
                              controller: _newUser,
                              label: "Username",
                              icon: Icons.person_outline,
                            ),

                            _buildGlassInputField(
                              controller: _newPass,
                              label: "Password",
                              icon: Icons.lock_outline,
                              obscureText: true,
                            ),

                            _buildGlassInputField(
                              controller: _days,
                              label: "Durasi (hari)",
                              icon: Icons.calendar_today,
                              keyboardType: TextInputType.number,
                            ),

                            const SizedBox(height: 8),

                            _buildActionButton(
                              text: "BUAT AKUN",
                              icon: Icons.person_add,
                              onPressed: _create,
                              color: mainPurple,
                              isLoading: loading,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // --- SECTION: UBAH DURASI ---
                      _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("Tambah Durasi", Icons.edit_calendar),

                            _buildGlassInputField(
                              controller: _editUser,
                              label: "Username",
                              icon: Icons.person_outline,
                            ),

                            _buildGlassInputField(
                              controller: _editDays,
                              label: "Tambah Hari",
                              icon: Icons.calendar_today,
                              keyboardType: TextInputType.number,
                            ),

                            const SizedBox(height: 8),

                            _buildActionButton(
                              text: "TAMBAH DURASI",
                              icon: Icons.edit,
                              onPressed: _edit,
                              color: deepPurple,
                              isLoading: loading,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Info card
                      _buildGlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: greenAccent, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Akun Permanen vs Berbayar",
                                    style: TextStyle(
                                      color: greenAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "• Akun PERMANEN: Tidak ada masa berlaku (selamanya)\n• Akun BERBAYAR: Memiliki masa berlaku sesuai durasi yang dipilih",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
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
        ],
      ),
    );
  }
}

// device_dashboard.dart (Fixed version - replace Icons.devices_off_rounded)

// ============================================================================
// THEME DASHBOARD COLORS (Dark Elegant)
// ============================================================================
class DashboardTheme {


  static const surface2 = Color(0xFF1C1C2A);
  static const surface3 = Color(0xFF242433);
  static const cardDark = Color(0xFF0D0D14);
  
  static const accent1 = Color(0xFF00E5FF);
  static const accent2 = Color(0xFF7C4DFF);
  static const accent3 = Color(0xFFFF4081);
  static const success = Color(0xFF00E676);
  static const warning = Color(0xFFFFAB40);
  static const error = Color(0xFFFF5252);
  
  static const textPrimary = Color(0xFFF5F5FF);
  static const textSecondary = Color(0xFF9E9EB8);

  
  static const shadow = Color(0x40000000);
  static const shadowHeavy = Color(0x80000000);
}

// ============================================================================
// SHADOW UTILITIES
// ============================================================================


// ============================================================================
// PAGE 1: PAIRING INFO & TUTORIAL
// ============================================================================
class _PairingInfoPage extends StatelessWidget {
  final String pairId;

  final bool isOwner;
  
  const _PairingInfoPage({
    required this.pairId,
    required this.onCopy,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [DashboardTheme.accent1, DashboardTheme.accent2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: ShadowUtils.heavy,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.link_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PAIRING ID',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pairId.isEmpty ? 'MEMUAT...' : pairId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pairId.isNotEmpty)
                  GestureDetector(
                    onTap: onCopy,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Step by Step Tutorial
          Text(
            'CARA MENAUTKAN DEVICE',
            style: TextStyle(
              color: DashboardTheme.textSecondary,
              fontSize: 12,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 16),
          
          _StepCard(
            number: 1,
            title: 'INSTALL APK',
            description: 'Install aplikasi target di perangkat yang ingin dipantau',
            icon: Icons.download_rounded,
            gradient: [DashboardTheme.accent1, DashboardTheme.accent2],
          ),
          
          const SizedBox(height: 12),
          
          _StepCard(
            number: 2,
            title: 'MASUKKAN PAIRING ID',
            description: 'Buka aplikasi lalu masukkan ID di atas',
            icon: Icons.qr_code_scanner_rounded,
            gradient: [DashboardTheme.accent2, DashboardTheme.accent3],
          ),
          
          const SizedBox(height: 12),
          
          _StepCard(
            number: 3,
            title: 'BERI IZIN AKSES',
            description: 'Izinkan semua permission yang diminta',
            icon: Icons.security_rounded,
            gradient: [DashboardTheme.accent3, DashboardTheme.accent1],
          ),
          
          const SizedBox(height: 12),
          
          _StepCard(
            number: 4,
            title: 'SELESAI',
            description: 'Device akan muncul di halaman Devices',
            icon: Icons.check_circle_rounded,
            gradient: [DashboardTheme.success, DashboardTheme.accent2],
          ),
          
          const SizedBox(height: 24),
          
          // Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: DashboardTheme.surface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DashboardTheme.accent1.withOpacity(0.2)),
              boxShadow: ShadowUtils.medium,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DashboardTheme.accent1.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.info_rounded, color: DashboardTheme.accent1, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CATATAN PENTING',
                        style: TextStyle(
                          color: DashboardTheme.accent1,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID Pairing hanya dimiliki Owner. Jangan bagikan ke orang yang tidak dikenal.',
                        style: TextStyle(color: DashboardTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (!isOwner) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DashboardTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DashboardTheme.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_rounded, color: DashboardTheme.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Anda bukan Owner, ID Pairing tidak tersedia. Hubungi Owner untuk mendapat akses.',
                      style: TextStyle(color: DashboardTheme.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int number;

  final String description;

  final List<Color> gradient;
  
  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DashboardTheme.surface2,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ShadowUtils.soft,
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: ShadowUtils.soft,
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DashboardTheme.surface3,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: gradient[0], size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: DashboardTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          color: DashboardTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: DashboardTheme.textMuted, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PAGE 2: DEVICE LIST
// ============================================================================
class _DeviceListPage extends StatelessWidget {
  final List<dynamic> devices;


  final PermissionResult? perm;
  final bool denied;
  
  const _DeviceListPage({
    required this.devices,
    required this.role,
    required this.isOwner,
    required this.perm,
    required this.denied,
  });

  @override
  Widget build(BuildContext context) {
    final activeCount = devices.where((d) => d['online'] == true).length;
    
    return Column(
      children: [
        // Stats bar
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: DashboardTheme.surface2,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ShadowUtils.soft,
          ),
          child: Row(
            children: [
              _StatChip(
                label: 'ONLINE',
                value: '$activeCount',
                color: DashboardTheme.success,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: 'OFFLINE',
                value: '${devices.length - activeCount}',
                color: DashboardTheme.error,
              ),
              const Spacer(),
              _StatChip(
                label: 'TOTAL',
                value: '${devices.length}',
                color: DashboardTheme.accent1,
              ),
            ],
          ),
        ),
        
        // Device List
        Expanded(
          child: devices.isEmpty
              ? _EmptyDeviceWidget(denied: denied, isOwner: isOwner)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  physics: const BouncingScrollPhysics(),
                  itemCount: devices.length,
                  itemBuilder: (ctx, i) {
                    final d = devices[i];
                    final isOnline = d['online'] == true;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DeviceCard(
                        device: d,
                        isOnline: isOnline,
                        role: role,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {

  final String value;

  
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: DashboardTheme.textMuted, fontSize: 10),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final dynamic device;
  final bool isOnline;

  
  const _DeviceCard({
    required this.device,
    required this.isOnline,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isOnline ? DashboardTheme.success : DashboardTheme.error;
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ControlCenterPage(targetDevice: device, role: role),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: DashboardTheme.surface2,
          borderRadius: BorderRadius.circular(20),
          boxShadow: ShadowUtils.card,
          border: Border.all(
            color: isOnline ? statusColor.withOpacity(0.3) : Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            if (isOnline)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [statusColor.withOpacity(0.1), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Icon device
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DashboardTheme.surface3,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: ShadowUtils.soft,
                    ),
                    child: Icon(
                      device['model']?.toString().toLowerCase().contains('samsung') == true
                          ? Icons.phone_android_rounded
                          : Icons.devices_rounded,
                      color: DashboardTheme.textSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Info device
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device['model'] ?? 'Unknown Device',
                          style: TextStyle(
                            color: DashboardTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          device['id'] ?? 'ID: ---',
                          style: TextStyle(
                            color: DashboardTheme.textMuted,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.battery_charging_full_rounded,
                              color: DashboardTheme.textMuted,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${device['battery'] ?? '?'}%',
                              style: TextStyle(
                                color: DashboardTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            if (!isOnline && device['lastSeen'] != null) ...[
                              const SizedBox(width: 10),
                              Text(
                                _formatLastSeen(device['lastSeen']),
                                style: TextStyle(color: DashboardTheme.textMuted, fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Status badge + arrow
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: statusColor, blurRadius: 4),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOnline ? 'ON' : 'OFF',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: DashboardTheme.textMuted,
                        size: 14,
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
  
  String _formatLastSeen(String? lastSeenStr) {
    if (lastSeenStr == null) return 'Never';
    try {
      final lastSeen = DateTime.parse(lastSeenStr);
      final diff = DateTime.now().difference(lastSeen);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Never';
    }
  }
}

class _EmptyDeviceWidget extends StatelessWidget {


  
  const _EmptyDeviceWidget({
    required this.denied,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DashboardTheme.surface2,
              shape: BoxShape.circle,
              boxShadow: ShadowUtils.heavy,
            ),
            child: Icon(
              denied ? Icons.lock_rounded : Icons.devices_rounded,
              size: 48,
              color: denied ? DashboardTheme.error : DashboardTheme.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            denied ? 'AKSES DITOLAK' : 'BELUM ADA DEVICE',
            style: TextStyle(
              color: denied ? DashboardTheme.error : DashboardTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            denied 
                ? 'Hubungi Owner untuk mendapatkan izin akses'
                : 'Tautkan device menggunakan ID Pairing di halaman sebelumnya',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: DashboardTheme.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 32),
          if (!denied && isOwner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: DashboardTheme.accent1.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: DashboardTheme.accent1.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swipe_left_rounded, color: DashboardTheme.accent1, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'GESER KE KIRI UNTUK LIHAT PAIRING ID',
                    style: TextStyle(color: DashboardTheme.accent1, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// PERMISSION BOTTOM SHEET
// ============================================================================
class _PermissionBottomSheet extends StatefulWidget {

  final List<dynamic> allDevices;
  
  const _PermissionBottomSheet({
    required this.sessionKey,
    required this.allDevices,
  });

  @override
  State<_PermissionBottomSheet> createState() => _PermissionBottomSheetState();
}

class _PermissionBottomSheetState extends State<_PermissionBottomSheet> {
  Map<String, dynamic> _perms = {};
  String _selectedUser = '';
  final _inputCtrl = TextEditingController();
  String _inputVal = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    if (mounted) {
      setState(() {
        _perms = data;
        _loading = false;
      });
    }
  }

  List<String> get _users => _perms.keys.toList();
  bool _approved(String u) => _perms[u]?['approved'] == true;
  bool _hasAll(String u) => _perms[u]?['allDevices'] == true;
  List<String> _devices(String u) => List<String>.from(_perms[u]?['devices'] ?? []);

  Future<void> _addUser(String username) async {
    if (username.trim().isEmpty) return;
    final key = username.trim().toLowerCase();
    setState(() => _saving = true);
    final ok = await DevicePermissionStore.setPerm(
      widget.sessionKey, key,
      approved: true, allDevices: true, devices: [],
    );
    if (ok) {
      await _load();
      if (mounted) {
        setState(() {
          _selectedUser = key;
          _inputVal = '';
          _inputCtrl.clear();
          _saving = false;
        });
      }
    } else {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menambahkan user')),
        );
      }
    }
  }

  Future<void> _update(String u, {bool? approved, bool? allDevices, List<String>? devices}) async {
    setState(() => _saving = true);
    final ok = await DevicePermissionStore.setPerm(
      widget.sessionKey, u,
      approved: approved ?? _approved(u),
      allDevices: allDevices ?? _hasAll(u),
      devices: devices ?? _devices(u),
    );
    if (ok) await _load();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _removeUser(String u) async {
    setState(() => _saving = true);
    final ok = await DevicePermissionStore.removePerm(widget.sessionKey, u);
    if (ok) {
      await _load();
      if (mounted) setState(() {
        if (_selectedUser == u) _selectedUser = '';
        _saving = false;
      });
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: DashboardTheme.surface,
            boxShadow: ShadowUtils.heavy,
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DashboardTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [DashboardTheme.accent2, DashboardTheme.accent3],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: ShadowUtils.soft,
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KELOLA AKSES DEVICE',
                            style: TextStyle(
                              color: DashboardTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'Atur user yang dapat mengakses device',
                            style: TextStyle(color: DashboardTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (_saving)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: DashboardTheme.accent1,
                          strokeWidth: 2,
                        ),
                      ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: DashboardTheme.surface3,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.close_rounded, color: DashboardTheme.textMuted, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              // Add user section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: DashboardTheme.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DashboardTheme.surface3),
                  boxShadow: ShadowUtils.soft,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        onChanged: (v) => setState(() => _inputVal = v),
                        style: TextStyle(color: DashboardTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Username baru...',
                          hintStyle: TextStyle(color: DashboardTheme.textMuted),
                          prefixIcon: Icon(Icons.person_add_rounded, color: DashboardTheme.accent2, size: 18),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _addUser(_inputVal),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [DashboardTheme.accent2, DashboardTheme.accent3],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: ShadowUtils.soft,
                        ),
                        child: const Text(
                          'TAMBAH',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // User list and permissions
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: DashboardTheme.accent1),
                      )
                    : _users.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.group_off_rounded, color: DashboardTheme.textMuted, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'Belum ada user',
                                  style: TextStyle(color: DashboardTheme.textSecondary, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tambahkan user untuk memberi akses device',
                                  style: TextStyle(color: DashboardTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User chips
                                const Text(
                                  'DAFTAR USER',
                                  style: TextStyle(
                                    color: DashboardTheme.textSecondary,
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _users.map((u) {
                                    final active = u == _selectedUser;
                                    final appr = _approved(u);
                                    return GestureDetector(
                                      onTap: () => setState(() => _selectedUser = u),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: active ? DashboardTheme.accent2 : DashboardTheme.surface2,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: active
                                                ? DashboardTheme.accent2
                                                : (appr ? DashboardTheme.success.withOpacity(0.3) : DashboardTheme.error.withOpacity(0.3)),
                                          ),
                                          boxShadow: active ? ShadowUtils.soft : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: appr ? DashboardTheme.success : DashboardTheme.error,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: (appr ? DashboardTheme.success : DashboardTheme.error).withOpacity(0.5),
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              u,
                                              style: TextStyle(
                                                color: active ? Colors.white : DashboardTheme.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                
                                if (_selectedUser.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  // User permission card
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: DashboardTheme.surface2,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: DashboardTheme.surface3),
                                      boxShadow: ShadowUtils.medium,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: DashboardTheme.surface3,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Icon(
                                                    Icons.person_rounded,
                                                    color: _approved(_selectedUser) ? DashboardTheme.success : DashboardTheme.error,
                                                    size: 16,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  _selectedUser,
                                                  style: TextStyle(
                                                    color: DashboardTheme.textPrimary,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            GestureDetector(
                                              onTap: () => _removeUser(_selectedUser),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: DashboardTheme.error.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: DashboardTheme.error.withOpacity(0.3)),
                                                ),
                                                child: Row(
                                                  children: const [
                                                    Icon(Icons.delete_outline_rounded, color: DashboardTheme.error, size: 14),
                                                    SizedBox(width: 4),
                                                    Text('Hapus', style: TextStyle(color: DashboardTheme.error, fontSize: 11)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        const Divider(color: DashboardTheme.surface3),
                                        const SizedBox(height: 12),
                                        // Approval toggle
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'IZINKAN AKSES',
                                                  style: TextStyle(
                                                    color: DashboardTheme.textSecondary,
                                                    fontSize: 10,
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _approved(_selectedUser) ? 'User dapat mengakses device' : 'Akses ditolak',
                                                  style: TextStyle(
                                                    color: _approved(_selectedUser) ? DashboardTheme.success : DashboardTheme.error,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Switch(
                                              value: _approved(_selectedUser),
                                              activeColor: DashboardTheme.success,
                                              activeTrackColor: DashboardTheme.success.withOpacity(0.3),
                                              inactiveThumbColor: DashboardTheme.error,
                                              inactiveTrackColor: DashboardTheme.error.withOpacity(0.3),
                                              onChanged: (v) => _update(_selectedUser, approved: v),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Device selection (if approved)
                                  if (_approved(_selectedUser) && widget.allDevices.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: DashboardTheme.surface2,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: DashboardTheme.surface3),
                                        boxShadow: ShadowUtils.medium,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.devices_rounded, color: DashboardTheme.accent1, size: 16),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'DEVICE YANG DAPAT DIAKSES',
                                                style: TextStyle(
                                                  color: DashboardTheme.textSecondary,
                                                  fontSize: 10,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                '${_devices(_selectedUser).length} / ${widget.allDevices.length}',
                                                style: TextStyle(
                                                  color: DashboardTheme.accent1,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          ListView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: widget.allDevices.length,
                                            itemBuilder: (ctx, i) {
                                              final d = widget.allDevices[i];
                                              final id = d['id']?.toString() ?? '';
                                              final model = d['model']?.toString() ?? 'Unknown';
                                              final allowed = _devices(_selectedUser).contains(id);
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: allowed ? DashboardTheme.accent1.withOpacity(0.05) : DashboardTheme.surface3,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: allowed ? DashboardTheme.accent1.withOpacity(0.3) : DashboardTheme.surface3,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.phone_android_rounded,
                                                      color: allowed ? DashboardTheme.accent1 : DashboardTheme.textMuted,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            model,
                                                            style: TextStyle(
                                                              color: allowed ? DashboardTheme.textPrimary : DashboardTheme.textSecondary,
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          Text(
                                                            'ID: ${id.length > 12 ? '...${id.substring(id.length - 10)}' : id}',
                                                            style: TextStyle(color: DashboardTheme.textMuted, fontSize: 9),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Checkbox(
                                                      value: allowed,
                                                      activeColor: DashboardTheme.accent1,
                                                      checkColor: Colors.white,
                                                      side: BorderSide(color: DashboardTheme.textMuted),
                                                      onChanged: (v) async {
                                                        final cur = List<String>.from(_devices(_selectedUser));
                                                        if (v == true) {
                                                          if (!cur.contains(id)) cur.add(id);
                                                        } else {
                                                          cur.remove(id);
                                                        }
                                                        await _update(_selectedUser, devices: cur);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MAIN DASHBOARD WITH HORIZONTAL SCROLL
// ============================================================================
class DeviceDashboardPage extends StatefulWidget {
  final String username;


  
  const DeviceDashboardPage({
    super.key,
    this.username = '',
    this.role = '',
    this.sessionKey = '',
  });

  @override
  State<DeviceDashboardPage> createState() => _DDState();
}

class _DDState extends State<DeviceDashboardPage> {
  List<dynamic> _visible = [];

  String? _errorMsg;
  String _pairId = '';
  PermissionResult? _perm;

  late PageController _pageController;
  int _currentPage = 0;


  bool get _isOwner => widget.role.toLowerCase() == 'owner';
  bool get _denied => _perm != null && !_perm!.approved && !_isOwner;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initialize();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      _baseUrl = await ApiConfig.baseUrl;
      print('✅ Device Dashboard Base URL: $_baseUrl');
      await _loadAll();
      _timer = Timer.periodic(const Duration(seconds: 20), (_) => _loadAll());
    } catch (e) {
      print('❌ Failed to initialize: $e');
      setState(() {
        _loading = false;
        _errorMsg = e.toString();
      });
    }
  }

  Future<void> _loadAll() async {
    if (_baseUrl == null) return;
    if (!mounted) return;
    try {
      final pRes = await http
          .get(Uri.parse('$_baseUrl/rat/pairid?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 8));
      if (pRes.statusCode == 200) {
        final pd = jsonDecode(pRes.body);
        if (pd['valid'] == true && pd['pairId'] != null) {
          if (mounted) setState(() => _pairId = pd['pairId'].toString());
        }
      }

      final dRes = await http
          .get(Uri.parse('$_baseUrl/rat/my-devices?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (dRes.statusCode != 200) {
        setState(() {
          _loading = false;
          _errorMsg = 'Server error ${dRes.statusCode}';
        });
        return;
      }

      final body = jsonDecode(dRes.body);
      if (body['valid'] != true) {
        setState(() {
          _loading = false;
          _errorMsg = body['message'] ?? 'Error';
        });
        return;
      }

      List<dynamic> devices = List<dynamic>.from(body['devices'] ?? []);
      final now = DateTime.now();
      for (var d in devices) {
        try {
          final seen = DateTime.parse(d['lastSeen']?.toString() ?? '');
          d['online'] = now.difference(seen).inSeconds < 30;
        } catch (_) {
          d['online'] = false;
        }
      }

      PermissionResult perm;
      if (_isOwner) {
        perm = PermissionResult(approved: true, allDevices: true, devices: []);
      } else {
        perm = await DevicePermissionStore.getFor(widget.username, widget.sessionKey);
      }

      if (mounted) setState(() {
        _visible = devices;
        _perm = perm;
        _loading = false;
        _errorMsg = null;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _errorMsg = e.toString();
      });
    }
  }

  void _copyPairId() {
    if (_pairId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _pairId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: DashboardTheme.accent1,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: const [
            Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('ID Pairing berhasil disalin!'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openPermissionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PermissionBottomSheet(
        sessionKey: widget.sessionKey,
        allDevices: _visible,
      ),
    ).then((_) => _loadAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardTheme.bg,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: DashboardTheme.accent1,
              ),
            )
          : _errorMsg != null
              ? _buildErrorView()
              : Stack(
                  children: [
                    Column(
                      children: [
                        // Page Indicator
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _PageDot(
                                isActive: _currentPage == 0,
                                color: DashboardTheme.accent1,
                              ),
                              const SizedBox(width: 8),
                              _PageDot(
                                isActive: _currentPage == 1,
                                color: DashboardTheme.accent2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Page View
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            onPageChanged: (page) {
                              setState(() => _currentPage = page);
                            },
                            children: [
                              _PairingInfoPage(
                                pairId: _pairId,
                                onCopy: _copyPairId,
                                isOwner: _isOwner,
                              ),
                              _DeviceListPage(
                                devices: _visible,
                                role: widget.role,
                                isOwner: _isOwner,
                                perm: _perm,
                                denied: _denied,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Bottom Left Permission Button (Only for Owner)
                    if (_isOwner && !_loading && _errorMsg == null)
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: GestureDetector(
                          onTap: _openPermissionBottomSheet,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [DashboardTheme.accent2, DashboardTheme.accent3],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: ShadowUtils.heavy,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.monitor_heart_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'KELOLA AKSES',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
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
      backgroundColor: DashboardTheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: DashboardTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEVICE DASHBOARD',
            style: TextStyle(
              color: DashboardTheme.textMuted,
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '@${widget.username}',
            style: TextStyle(
              color: DashboardTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded, color: DashboardTheme.accent1),
            onPressed: () {
              setState(() => _loading = true);
              _loadAll();
            },
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: DashboardTheme.surface2,
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: DashboardTheme.surface2,
          borderRadius: BorderRadius.circular(20),
          boxShadow: ShadowUtils.heavy,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DashboardTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_rounded, color: DashboardTheme.error, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'TERJADI KESALAHAN',
              style: TextStyle(
                color: DashboardTheme.error,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMsg ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: DashboardTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                setState(() {
                  _loading = true;
                  _errorMsg = null;
                });
                _loadAll();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [DashboardTheme.accent1, DashboardTheme.accent2],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: ShadowUtils.soft,
                ),
                child: const Text(
                  'COBA LAGI',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDot extends StatelessWidget {
  final bool isActive;

  
  const _PageDot({
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 24 : 6,
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: isActive ? color : DashboardTheme.textMuted.withOpacity(0.3),
        boxShadow: isActive
            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)]
            : [],
      ),
    );
  }
}

// ─── COLORS (same as dashboard) ─────────────────────────────────────────────
class _C {



  static const accent1     = Color(0xFF00E5FF); // Cyan
 // Purple
 // Pink


  static const textPrimary = Color(0xFFF5F8FF);
  static const textSec     = Color(0xFF9E9EB8);

  static const shadow      = Color(0x40000000);

}

// ─── HEX BACKGROUND PAINTER ─────────────────────────────────────────────────
class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final g1 = Paint()
      ..shader = RadialGradient(
        colors: [_C.accent1.withOpacity(0.15), _C.accent2.withOpacity(0.06), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: size.width * 0.65));
    canvas.drawCircle(Offset.zero, size.width * 0.65, g1);

    final g2 = Paint()
      ..shader = RadialGradient(
        colors: [_C.accent3.withOpacity(0.10), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width, size.height), radius: size.width * 0.55));
    canvas.drawCircle(Offset(size.width, size.height), size.width * 0.55, g2);

    const hexW = 60.0;
    final hexH = hexW * dart_math.sqrt(3) / 2;
    final cols = (size.width / hexW).ceil() + 2;
    final rows = (size.height / hexH).ceil() + 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.white.withOpacity(0.03);

    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final x = col * hexW + (row % 2) * hexW / 2;
        final y = row * hexH * 0.75;
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = i * dart_math.pi * 2 / 6;
          final px = x + hexW / 2 + dart_math.cos(angle) * hexW / 2;
          final py = y + hexH / 2 + dart_math.sin(angle) * hexH / 2;
          if (i == 0) path.moveTo(px, py); else path.lineTo(px, py);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── LOGIN PAGE ──────────────────────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final userController = TextEditingController();
  final passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  String? androidId;


  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    initLogin();
  }

  @override
  void dispose() {
    _controller.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  Future<void> initLogin() async {
    androidId = await _getAndroidId();
    
    // Ambil base URL dari API Config
    try {
      _baseUrl = await ApiConfig.baseUrl;
      print('✅ Base URL loaded: $_baseUrl');
    } catch (e) {
      print('❌ Failed to get base URL: $e');
    }

    final savedUser = prefs.getString("username");
    final savedPass = prefs.getString("password");
    final savedKey  = prefs.getString("key");

    if (savedUser != null && savedPass != null && savedKey != null && _baseUrl != null) {
      final uri = Uri.parse("$_baseUrl/myInfo?username=$savedUser&password=$savedPass&androidId=$androidId&key=$savedKey");
      try {
        final res  = await http.get(uri);

        if (data['valid'] == true) {
          Navigator.pushReplacement(context, _fadeRoute(SplashScreen(
            username: savedUser, password: savedPass,
            role: (data['role'] ?? '').toString(),
            sessionKey: data['key'], expiredDate: data['expiredDate'],
            listBug:  (data['listBug']   as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            listDoos: (data['listDDoS']  as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            news:     (data['news']      as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          )));
        }
      } catch (_) {}
    }
  }

  Future<String> _getAndroidId() async {
    final deviceInfo = DeviceInfoPlugin();
    final android = await deviceInfo.androidInfo;
    return android.id ?? "unknown_device";
  }

  PageRouteBuilder _fadeRoute(Widget page) => PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim.drive(Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic))), child: child),
  );

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    final password = passController.text.trim();
    setState(() => isLoading = true);

    try {
      // Ambil base URL terbaru
      _baseUrl = await ApiConfig.baseUrl;
      
      final validate = await http.post(
        Uri.parse("$_baseUrl/validate"),
        body: {"username": username, "password": password, "androidId": androidId ?? "unknown_device"},
      );
      final validData = jsonDecode(validate.body);

      if (validData['expired'] == true) {
        _showPopup(title: "⏳ Access Expired", message: "Your access has expired.\nPlease renew it.", color: _C.warning, showContact: true);
      } else if (validData['valid'] != true) {
        _showPopup(title: "Login Failed", message: "Invalid username or password.", color: _C.accent3);
      } else {

        prefs.setString("username", username);
        prefs.setString("password", password);
        prefs.setString("key", validData['key']);
        Navigator.pushReplacement(context, _fadeRoute(SplashScreen(
          username: username, password: password,
          role: (validData['role'] ?? '').toString(),
          sessionKey: validData['key'], expiredDate: validData['expiredDate'],
          listBug:  (validData['listBug']   as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          listDoos: (validData['listDDoS']  as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          news:     (validData['news']      as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        )));
      }
    } catch (e) {
      _showPopup(title: "Connection Error", message: "Failed to connect to the server.\nPlease check your internet connection.", color: _C.error);
    }

    setState(() => isLoading = false);
  }

  void _showPopup({required String title, required String message, Color color = _C.accent3, bool showContact = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withOpacity(0.4), width: 1),
        ),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Orbitron')),
        content: Text(message, style: const TextStyle(color: _C.textSec, fontSize: 14)),
        actions: [
          if (showContact)
            TextButton(
              onPressed: () async => await launchUrl(Uri.parse("https://t.me/pemxx08"), mode: LaunchMode.externalApplication),
              child: Text("Contact Admin", style: TextStyle(color: _C.accent1)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: _C.textMuted)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          // Hex background
          CustomPaint(
            size: Size.infinite,
            painter: _HexPainter(),
            child: const SizedBox.expand(),
          ),

          // Konten utama
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Logo ──
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween(begin: 0.5, end: 1.0),
                        curve: Curves.easeOutBack,
                        builder: (_, v, child) => Transform.scale(scale: v, child: child),
                        child: Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                              colors: [_C.accent1, _C.accent2],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(color: _C.accent1.withOpacity(0.3), blurRadius: 24, spreadRadius: 2),
                              BoxShadow(color: _C.accent2.withOpacity(0.2), blurRadius: 12),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Title ──
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child),
                        ),
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [_C.accent1, _C.accent2],
                              ).createShader(bounds),
                              child: const Text(
                                "WELCOME BACK",
                                style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w800,
                                  color: Colors.white, fontFamily: 'Orbitron', letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Sign in to continue",
                              style: TextStyle(color: _C.textSec, fontSize: 13, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Form card ──
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 700),
                        tween: Tween(begin: 0.9, end: 1.0),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, child) => Transform.scale(scale: v, child: child),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _C.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
                            boxShadow: [
                              BoxShadow(color: _C.accent2.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8)),
                              const BoxShadow(color: _C.shadowHeavy, blurRadius: 10, offset: Offset(0, 4)),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: userController,
                                  label: "Username",
                                  icon: Icons.person_outline_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: passController,
                                  label: "Password",
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  isPassword: true,
                                ),
                                const SizedBox(height: 24),

                                // ── Login Button ──
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: _AnimatedLoginButton(
                                    isLoading: isLoading,
                                    onPressed: login,
                                    gradient: const LinearGradient(
                                      colors: [_C.accent1, _C.accent2],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Footer label ──
                      const Text(
                        "CATACLYSM",
                        style: TextStyle(
                          color: _C.textMuted, fontSize: 9,
                          letterSpacing: 3, fontFamily: 'Orbitron',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.85, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: _C.textPrimary, fontFamily: 'Orbitron', fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _C.textSec, fontFamily: 'Orbitron', fontSize: 12),
          prefixIcon: Icon(icon, color: _C.accent1, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      key: ValueKey(_obscurePassword),
                      color: _C.textMuted,
                      size: 20,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                )
              : null,
          filled: true,
          fillColor: _C.surface2.withOpacity(0.8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.accent1, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.error, width: 1.5),
          ),
          errorStyle: const TextStyle(color: _C.error, fontSize: 11),
        ),
        validator: (v) => (v == null || v.isEmpty) ? "Please enter $label" : null,
      ),
    );
  }
}

// ─── ANIMATED LOGIN BUTTON ───────────────────────────────────────────────────
class _AnimatedLoginButton extends StatefulWidget {

  final VoidCallback onPressed;
  final Gradient gradient;

  const _AnimatedLoginButton({
    required this.isLoading,
    required this.onPressed,
    required this.gradient,
  });

  @override State<_AnimatedLoginButton> createState() => _AnimatedLoginButtonState();
}

class _AnimatedLoginButtonState extends State<_AnimatedLoginButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _glowCtrl;
  late Animation<double> _glow;

  @override void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _glowCtrl.dispose(); super.dispose(); }

  void _handleTap() {
    if (widget.isLoading) return;
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _isPressed = false);
      widget.onPressed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => GestureDetector(
        onTap: _handleTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          scale: _isPressed ? 0.97 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: _C.accent1.withOpacity(0.30 * _glow.value), blurRadius: 20, offset: const Offset(0, 6)),
                BoxShadow(color: _C.accent2.withOpacity(0.20 * _glow.value), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      "SIGN IN",
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: Colors.white, fontFamily: 'Orbitron', letterSpacing: 2.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// chat_page.dart (Dengan Reply & Persegi Panjang - FIXED)

class ChatTheme {




  static const accent1 = Color(0xFF00E5FF);





  static const textPrimary = Color(0xFFF5F5FF);



}

class ChatPage extends StatefulWidget {


  
  const ChatPage({
    super.key,
    required this.username,
    required this.sessionKey,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  WebSocketChannel? _channel;
  
  // Global chat
  List<dynamic> _globalMessages = [];
  bool _globalLoading = true;
  final TextEditingController _globalInputCtrl = TextEditingController();
  final ScrollController _globalScrollCtrl = ScrollController();
  Map<String, dynamic>? _globalReplyTo;
  
  // Private chat
  List<dynamic> _privateChats = [];
  List<dynamic> _privateMessages = [];

  bool _privateLoading = true;
  final TextEditingController _privateInputCtrl = TextEditingController();
  final ScrollController _privateScrollCtrl = ScrollController();
  Map<String, dynamic>? _privateReplyTo;
  
  // Profile
  Map<String, dynamic> _myProfile = {};
  
  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];
  
  // Base URL

  String? _wsUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _channel?.sink.close();
    _globalInputCtrl.dispose();
    _globalScrollCtrl.dispose();
    _privateInputCtrl.dispose();
    _privateScrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      _baseUrl = await ApiConfig.baseUrl;
      _wsUrl = await ApiConfig.urlRat;
      print('✅ Chat Base URL: $_baseUrl');
      print('✅ Chat WS URL: $_wsUrl');
      
      _loadProfile();
      _connectWebSocket();
      _loadGlobalMessages();
      _loadPrivateChats();
    } catch (e) {
      print('❌ Failed to initialize chat: $e');
    }
  }

  Future<void> _loadProfile() async {
    if (_baseUrl == null) return;
    try {


      final res = await http.get(Uri.parse('$_baseUrl/chat/profile?key=$sessionKey'));
      if (res.statusCode == 200) {

        if (data['valid'] == true) {
          setState(() => _myProfile = data['profile']);
        }
      }
    } catch (e) { print('Profile load error: $e'); }
  }

  void _connectWebSocket() async {
    try {


      
      // Gunakan wsUrl dari ApiConfig
      final wsUrl = _wsUrl ?? 'ws://serverku.lynzzofficial.com:2099';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.stream.listen(_handleWebSocketMessage, onError: (e) {
        print('WebSocket error: $e');
      });
      _channel!.sink.add(jsonEncode({ 'type': 'auth', 'key': sessionKey }));
    } catch (e) { print('Connection error: $e'); }
  }
  
  void _handleWebSocketMessage(dynamic data) {
    try {
      final msg = jsonDecode(data);
      if (msg['type'] == 'global_message') {
        _addGlobalMessage(msg['message']);
      } else if (msg['type'] == 'private_message') {
        _addPrivateMessage(msg['message']);
      } else if (msg['type'] == 'refresh_chat_list') {
        _loadPrivateChats();
      }
    } catch (e) { print('Parse error: $e'); }
  }

  // ==================== GLOBAL CHAT METHODS ====================
  
  Future<void> _loadGlobalMessages() async {
    if (_baseUrl == null) return;
    try {


      final res = await http.get(Uri.parse('$_baseUrl/chat/global/messages?key=$sessionKey&limit=100'));
      if (res.statusCode == 200) {

        if (data['valid'] == true) {
          setState(() {
            _globalMessages = data['messages'];
            _globalLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(_globalScrollCtrl);
          });
        }
      }
    } catch (e) { if (mounted) setState(() => _globalLoading = false); }
  }
  
  void _addGlobalMessage(dynamic msg) {
    setState(() => _globalMessages.add(msg));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(_globalScrollCtrl);
    });
  }
  
  void _scrollToBottom(ScrollController controller) {
    if (controller.hasClients) {
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  Future<void> _sendGlobalMessage() async {
    if (_baseUrl == null) return;
    String text = _globalInputCtrl.text.trim();
    if (text.isEmpty && _globalReplyTo == null) return;
    
    String finalText = text;
    if (_globalReplyTo != null) {
      finalText = '@${_globalReplyTo!['sender']} ${text}';
    }
    
    setState(() => _globalInputCtrl.text = '');
    
    try {


      final body = jsonEncode({ 
        'message': finalText, 
        'type': 'text',
        'replyTo': _globalReplyTo?['id']
      });
      
      final res = await http.post(
        Uri.parse('$_baseUrl/chat/global/send?key=$sessionKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      
      if (res.statusCode == 200) {

        if (data['valid'] == true) {
          setState(() => _globalReplyTo = null);
          _loadGlobalMessages();
        }
      }
    } catch (e) { print('Send error: $e'); }
  }

  // ==================== PRIVATE CHAT METHODS ====================
  
  Future<void> _loadPrivateChats() async {
    if (_baseUrl == null) return;
    try {


      final res = await http.get(Uri.parse('$_baseUrl/chat/private/users?key=$sessionKey'));
      if (res.statusCode == 200) {

        if (data['valid'] == true) {
          setState(() {
            _privateChats = data['users'];
            _privateLoading = false;
          });
        }
      }
    } catch (e) { if (mounted) setState(() => _privateLoading = false); }
  }
  
  Future<void> _loadPrivateMessages(String withUser) async {
    if (_baseUrl == null) return;
    setState(() => _privateLoading = true);
    try {


      final res = await http.get(Uri.parse('$_baseUrl/chat/private/messages/$withUser?key=$sessionKey&limit=100'));
      if (res.statusCode == 200) {

        if (data['valid'] == true) {
          setState(() {
            _privateMessages = data['messages'];
            _privateLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(_privateScrollCtrl);
          });
          
          await http.post(Uri.parse('$_baseUrl/chat/private/mark-read/$withUser?key=$sessionKey'));
        }
      }
    } catch (e) { setState(() => _privateLoading = false); }
  }
  
  void _addPrivateMessage(dynamic msg) {
    final isCurrentChat = _selectedUser == msg['sender'] || _selectedUser == msg['receiver'];
    if (isCurrentChat) {
      setState(() => _privateMessages.add(msg));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(_privateScrollCtrl);
      });
    }
    _loadPrivateChats();
  }
  
  Future<void> _sendPrivateMessage() async {
    if (_baseUrl == null) return;
    String text = _privateInputCtrl.text.trim();
    if (text.isEmpty || _selectedUser == null) return;

    if (_privateReplyTo != null) {
      finalText = '@${_privateReplyTo!['sender']} ${text}';
    }
    
    setState(() => _privateInputCtrl.text = '');
    
    try {


      final body = jsonEncode({ 
        'message': finalText, 
        'type': 'text',
        'replyTo': _privateReplyTo?['id']
      });
      
      final res = await http.post(
        Uri.parse('$_baseUrl/chat/private/send/${_selectedUser}?key=$sessionKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      
      if (res.statusCode == 200) {

        if (data['valid'] == true) {
          setState(() => _privateReplyTo = null);
          _loadPrivateMessages(_selectedUser!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Gagal mengirim pesan')),
          );
        }
      }
    } catch (e) { 
      print('Send error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  Future<void> _searchAndStartChat() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchUserSheet(
        sessionKey: widget.sessionKey,
        currentUsername: widget.username,
        onSelectUser: (user) {
          Navigator.pop(ctx);
          setState(() {
            _selectedUser = user['username'];
            _privateReplyTo = null;
          });
          _loadPrivateMessages(user['username']);
          _tabController.animateTo(1);
        },
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final time = DateTime.parse(timestamp);

      final diff = now.difference(time);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }

  // ==================== BUILD WIDGETS ====================
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatTheme.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Tab Bar - PERSEGI PANJANG SETENGAH KOTAK
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 48,
            decoration: BoxDecoration(
              color: ChatTheme.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [ChatTheme.accent1, ChatTheme.accent2],
                ),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: ChatTheme.textMuted,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(icon: Icon(Icons.public_rounded, size: 18), text: 'GLOBAL'),
                Tab(icon: Icon(Icons.lock_rounded, size: 18), text: 'PRIVATE'),
              ],
            ),
          ),
          // Tab View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGlobalChat(),
                _buildPrivateChat(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: ChatTheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: ChatTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CELTICS CHAT',
            style: TextStyle(
              color: ChatTheme.textMuted,
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '@${widget.username}',
            style: TextStyle(color: ChatTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: ChatTheme.accent1),
          onPressed: () {
            _loadGlobalMessages();
            _loadPrivateChats();
            if (_selectedUser != null) _loadPrivateMessages(_selectedUser!);
          },
        ),
      ],
    );
  }

  // ==================== GLOBAL CHAT TAB ====================
  
  Widget _buildGlobalChat() {
    return Column(
      children: [
        if (_globalReplyTo != null) _buildReplyPreviewBar(isGlobal: true),
        Expanded(
          child: _globalLoading
              ? const Center(child: CircularProgressIndicator(color: ChatTheme.accent1))
              : _globalMessages.isEmpty
                  ? _buildEmptyState('Belum ada pesan', 'Jadilah yang pertama mengirim pesan!')
                  : ListView.builder(
                      controller: _globalScrollCtrl,
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _globalMessages.length,
                      itemBuilder: (ctx, i) => _buildGlobalMessageBubble(_globalMessages[i]),
                    ),
        ),
        _buildInputBar(
          controller: _globalInputCtrl,
          onSend: _sendGlobalMessage,
          hint: 'Type a message...',
          isGlobal: true,
        ),
      ],
    );
  }

  Widget _buildGlobalMessageBubble(dynamic msg) {
    final isMe = msg['sender'] == widget.username;
    final profile = msg['senderProfile'] ?? {};
    final name = profile['name'] ?? msg['sender'];
    final replyTo = msg['replyTo'];
    
    return GestureDetector(
      onLongPress: () {
        setState(() {
          _globalReplyTo = {
            'id': msg['id'],
            'sender': msg['sender'],
            'message': msg['message'],
          };
        });
      },
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 60 : 12,
          right: isMe ? 12 : 60,
          top: 8,
          bottom: 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              GestureDetector(
                onTap: () {
                  if (msg['sender'] != widget.username) {
                    setState(() {
                      _selectedUser = msg['sender'];
                      _privateReplyTo = null;
                    });
                    _loadPrivateMessages(msg['sender']);
                    _tabController.animateTo(1);
                  }
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: ChatTheme.surface3,
                  child: Text(name[0].toUpperCase(), style: TextStyle(color: ChatTheme.accent1)),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(name, style: TextStyle(color: ChatTheme.textSecondary, fontSize: 11)),
                    ),
                  if (replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ChatTheme.surface3,
                        borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: isMe ? ChatTheme.accent2 : ChatTheme.accent1, width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replying to @${replyTo['sender']}',
                            style: TextStyle(color: isMe ? ChatTheme.accent2 : ChatTheme.accent1, fontSize: 10),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            replyTo['message'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: ChatTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? ChatTheme.accent2.withOpacity(0.2) : ChatTheme.surface2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isMe ? ChatTheme.accent2.withOpacity(0.3) : ChatTheme.surface3),
                    ),
                    child: Text(
                      msg['message'] ?? '',
                      style: TextStyle(
                        color: isMe ? ChatTheme.accent1 : ChatTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
                    child: Text(
                      _formatTime(msg['timestamp']),
                      style: TextStyle(color: ChatTheme.textMuted, fontSize: 9),
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

  // ==================== PRIVATE CHAT TAB ====================
  
  Widget _buildPrivateChat() {

  }

  Widget _buildChatList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: GestureDetector(
            onTap: _searchAndStartChat,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: ChatTheme.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ChatTheme.surface3),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: ChatTheme.textMuted),
                  const SizedBox(width: 12),
                  Text('Cari user baru...', style: TextStyle(color: ChatTheme.textMuted)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _privateChats.isEmpty
              ? _buildEmptyState('Belum ada chat', 'Cari user untuk memulai percakapan private!')
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _privateChats.length,
                  itemBuilder: (ctx, i) => _buildChatListItem(_privateChats[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildChatListItem(dynamic chat) {
    final profile = chat['profile'] ?? {};
    final lastMsg = chat['lastMessage'];
    final isUnread = lastMsg != null && lastMsg['sender'] != widget.username && lastMsg['read'] != true;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUser = chat['username'];
          _privateReplyTo = null;
        });
        _loadPrivateMessages(chat['username']);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnread ? ChatTheme.accent1.withOpacity(0.1) : ChatTheme.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isUnread ? ChatTheme.accent1.withOpacity(0.3) : ChatTheme.surface3),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: ChatTheme.surface3,
              child: Text(chat['username'][0].toUpperCase(),
                  style: TextStyle(color: ChatTheme.accent1, fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        profile['name'] ?? chat['username'],
                        style: TextStyle(
                          color: ChatTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: ChatTheme.accent1,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (lastMsg != null)
                    Text(
                      '${lastMsg['sender'] == widget.username ? "You: " : ""}${lastMsg['message'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isUnread ? ChatTheme.textSecondary : ChatTheme.textMuted,
                        fontSize: 12,
                        fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
            if (lastMsg != null)
              Text(
                _formatTime(lastMsg['timestamp']),
                style: TextStyle(color: ChatTheme.textMuted, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    final profile = _privateChats.firstWhere(
      (c) => c['username'] == _selectedUser,
      orElse: () => ({'profile': {}}),
    )['profile'] ?? {};
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ChatTheme.surface,
        border: Border(bottom: BorderSide(color: ChatTheme.surface2)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: ChatTheme.textPrimary),
            onPressed: () => setState(() {
              _selectedUser = null;
              _privateReplyTo = null;
            }),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: ChatTheme.surface3,
            child: Text(_selectedUser![0].toUpperCase(),
                style: TextStyle(color: ChatTheme.accent1, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile['name'] ?? _selectedUser!,
                  style: TextStyle(color: ChatTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
                if (profile['bio'] != null && profile['bio'].isNotEmpty)
                  Text(
                    profile['bio'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: ChatTheme.textMuted, fontSize: 10),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ChatTheme.accent2.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ChatTheme.accent2.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, color: ChatTheme.accent2, size: 12),
                const SizedBox(width: 4),
                Text('PRIVATE', style: TextStyle(color: ChatTheme.accent2, fontSize: 9, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateMessageBubble(dynamic msg) {
    final isMe = msg['fromMe'] == true;

    
    return GestureDetector(
      onLongPress: () {
        setState(() {
          _privateReplyTo = {
            'id': msg['id'],
            'sender': msg['sender'],
            'message': msg['message'],
          };
        });
      },
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 60 : 12,
          right: isMe ? 12 : 60,
          top: 8,
          bottom: 8,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (replyTo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ChatTheme.surface3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(color: isMe ? ChatTheme.accent2 : ChatTheme.accent1, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replying to @${replyTo['sender']}',
                      style: TextStyle(color: isMe ? ChatTheme.accent2 : ChatTheme.accent1, fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      replyTo['message'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ChatTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? ChatTheme.accent2.withOpacity(0.2) : ChatTheme.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isMe ? ChatTheme.accent2.withOpacity(0.3) : ChatTheme.surface3),
              ),
              child: Text(
                msg['message'] ?? '',
                style: TextStyle(
                  color: isMe ? ChatTheme.accent1 : ChatTheme.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: ChatTheme.accent2.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline_rounded, color: ChatTheme.accent2, size: 8),
                        const SizedBox(width: 2),
                        Text('E2EE', style: TextStyle(color: ChatTheme.accent2, fontSize: 7)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(msg['timestamp']),
                    style: TextStyle(color: ChatTheme.textMuted, fontSize: 9),
                  ),
                  if (isMe && msg['read'] == true)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.done_all_rounded, color: ChatTheme.accent1, size: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== REPLY PREVIEW BAR ====================
  
  Widget _buildReplyPreviewBar({required bool isGlobal}) {
    final replyData = isGlobal ? _globalReplyTo : _privateReplyTo;
    if (replyData == null) return const SizedBox();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ChatTheme.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: ChatTheme.accent1, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, color: ChatTheme.accent1, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to @${replyData['sender']}',
                  style: TextStyle(color: ChatTheme.accent1, fontSize: 10),
                ),
                Text(
                  replyData['message'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ChatTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              if (isGlobal) _globalReplyTo = null;

            }),
            child: Icon(Icons.close_rounded, color: ChatTheme.textMuted, size: 16),
          ),
        ],
      ),
    );
  }

  // ==================== INPUT BAR ====================
  
  Widget _buildInputBar({
    required TextEditingController controller,
    required VoidCallback onSend,
    required String hint,
    required bool isGlobal,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ChatTheme.surface,
        boxShadow: [
          BoxShadow(color: ChatTheme.shadowHeavy, blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: ChatTheme.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ChatTheme.surface3),
              ),
              child: TextField(
                controller: controller,
                style: TextStyle(color: ChatTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: ChatTheme.textMuted),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [ChatTheme.accent1, ChatTheme.accent2]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, color: ChatTheme.textMuted, size: 48),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: ChatTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: ChatTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ==================== SEARCH USER SHEET ====================

class _SearchUserSheet extends StatefulWidget {

  final String currentUsername;
  final Function(Map<String, dynamic>) onSelectUser;
  
  const _SearchUserSheet({
    required this.sessionKey,
    required this.currentUsername,
    required this.onSelectUser,
  });

  @override
  State<_SearchUserSheet> createState() => _SearchUserSheetState();
}

class _SearchUserSheetState extends State<_SearchUserSheet> {

  List<dynamic> _results = [];

  Timer? _debounce;


  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBaseUrl() async {
    try {
      _baseUrl = await ApiConfig.baseUrl;
    } catch (e) {
      print('Failed to load base URL: $e');
    }
  }

  void _search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (_baseUrl == null) return;
      if (query.length < 2) {
        setState(() => _results = []);
        return;
      }
      setState(() => _loading = true);
      try {


        final res = await http.get(Uri.parse('$_baseUrl/chat/search-users?key=$sessionKey&q=$query'));
        if (res.statusCode == 200) {

          if (data['valid'] == true) {
            setState(() => _results = data['users'] ?? []);
          }
        }
      } catch (e) { print('Search error: $e'); }
      setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: ChatTheme.surface,
            boxShadow: [BoxShadow(color: ChatTheme.shadowHeavy, blurRadius: 20)],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ChatTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [ChatTheme.accent1, ChatTheme.accent2]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'CARI USER',
                        style: TextStyle(
                          color: ChatTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ChatTheme.surface2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.close_rounded, color: ChatTheme.textMuted, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _search,
                  style: TextStyle(color: ChatTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Masukkan username...',
                    hintStyle: TextStyle(color: ChatTheme.textMuted),
                    prefixIcon: Icon(Icons.person_search_rounded, color: ChatTheme.accent1),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ChatTheme.surface3),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ChatTheme.accent1),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: ChatTheme.accent1))
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_off_rounded, color: ChatTheme.textMuted, size: 48),
                                const SizedBox(height: 12),
                                Text('Tidak ada user ditemukan', style: TextStyle(color: ChatTheme.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _results.length,
                            itemBuilder: (ctx, i) {
                              final user = _results[i];
                              final profile = user['profile'] ?? {};
                              return GestureDetector(
                                onTap: () => widget.onSelectUser(user),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: ChatTheme.surface2,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: ChatTheme.surface3),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: ChatTheme.surface3,
                                        child: Text(user['username'][0].toUpperCase(),
                                            style: TextStyle(color: ChatTheme.accent1, fontSize: 18)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              profile['name'] ?? user['username'],
                                              style: TextStyle(
                                                color: ChatTheme.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (profile['bio'] != null && profile['bio'].isNotEmpty)
                                              Text(
                                                profile['bio'],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(color: ChatTheme.textMuted, fontSize: 11),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: ChatTheme.accent2.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          user['role']?.toUpperCase() ?? 'MEMBER',
                                          style: TextStyle(color: ChatTheme.accent2, fontSize: 9),
                                        ),
                                      ),
                                    ],
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
}