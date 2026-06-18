import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'api_config.dart';
import 'splash.dart';

// ─── Palette: Dark Premium dengan Warna Cerah (Tanpa Hitam) ──────────────────
class _C {
  // Background - navy/indigo tones
  static const bg         = Color(0xFF0B1120);    // navy gelap
  static const surface    = Color(0xFF111827);    // slate gelap
  static const card       = Color(0xFF1E293B);    // slate medium
  static const border     = Color(0xFF334155);    // slate terang
  static const borderLit  = Color(0xFF475569);    // slate lebih terang

  // Warna aksen - biru, cyan, emas (cerah)
  static const steel      = Color(0xFF60A5FA);    // biru terang
  static const blueMid    = Color(0xFF3B82F6);    // biru medium
  static const blueLight  = Color(0xFF93C5FD);    // biru muda
  static const chrome     = Color(0xFF38BDF8);    // cyan
  static const frost      = Color(0xFFBAE6FD);    // cyan muda

  // Warna status
  static const green      = Color(0xFF22C55E);
  static const amber      = Color(0xFFF59E0B);
  static const red        = Color(0xFFEF4444);

  // Teks
  static const text       = Color(0xFFF3F4F6);    // putih
  static const textSub    = Color(0xFF9CA3AF);    // abu terang
  static const textDim    = Color(0xFF6B7280);    // abu medium

  // Gradien
  static const LinearGradient metalGrad = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGrad = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF3B82F6), Color(0xFF6366F1)],
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
    _logoGlow = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOut));

    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _btnPulse = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut));

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -5.0),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 5.0),   weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: 0.0),    weight: 1),
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
      barrierColor: Colors.black87,
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
            gradient: LinearGradient(
              colors: [_C.card, _C.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.15), blurRadius: 50),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(color: _C.text,
                fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textSub,
                    fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            if (showContact) ...[
              _GradBtn(
                label: 'HUBUNGI ADMIN',
                fullWidth: true,
                onTap: () async {
                  Navigator.pop(ctx);
                  await launchUrl(Uri.parse('https://t.me/maklongemis'),
                      mode: LaunchMode.externalApplication);
                },
              ),
              const SizedBox(height: 12),
            ],
            _OutlineBtn(
              label: showContact ? 'TUTUP' : 'OK',
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
                        horizontal: 20, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 28),
                        _buildHeading(),
                        const SizedBox(height: 32),
                        AnimatedBuilder(
                          animation: _shake,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(_shake.value, 0),
                            child: child,
                          ),
                          child: _buildForm(),
                        ),
                        const SizedBox(height: 24),
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
          // Outer ring glow
          Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _C.blueMid.withOpacity(_logoGlow.value * 0.15),
                  Colors.transparent,
                ],
                radius: 0.8,
              ),
            ),
          ),
          // Outer ring
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _C.blueMid.withOpacity(_logoGlow.value * 0.3),
                width: 1.5,
              ),
            ),
          ),
          // Mid ring
          Container(
            width: 92, height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _C.blueLight.withOpacity(_logoGlow.value * 0.5),
                width: 2,
              ),
            ),
          ),
          // Core
          Hero(
            tag: 'logo',
            child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF111827)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _C.blueLight.withOpacity(_logoGlow.value * 0.8),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.blueMid.withOpacity(_logoGlow.value * 0.6),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset('assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.rocket_rounded, color: _C.blueLight, size: 40)),
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
          colors: [Color(0xFF60A5FA), Color(0xFF38BDF8), Color(0xFFA78BFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(b),
        child: const Text(
          'ASTRAL ENGINE',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.border, width: 1),
        ),
        child: const Text('Masuk untuk melanjutkan',
            style: TextStyle(color: _C.textSub, fontSize: 13,
                fontWeight: FontWeight.w500)),
      ),
    ]);
  }

  // ─── Form ─────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.card, _C.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _C.border, width: 1),
        boxShadow: [
          BoxShadow(color: _C.blueMid.withOpacity(0.1),
              blurRadius: 40, offset: const Offset(0, 15)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(children: [
          // Section header with icon
          Row(children: [
            Container(
              width: 5, height: 20,
              decoration: BoxDecoration(
                gradient: _C.accentGrad,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.account_circle_rounded,
                color: _C.blueMid, size: 18),
            const SizedBox(width: 8),
            const Text('KREDENSIAL AKUN',
                style: TextStyle(color: _C.text, fontSize: 13,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 22),

          // Username
          _LoginField(
            controller: userCtrl,
            label: 'Username',
            icon: Icons.person_outline_rounded,
            validator: (v) => (v == null || v.isEmpty)
                ? 'Username tidak boleh kosong' : null,
          ),
          const SizedBox(height: 16),

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
          const SizedBox(height: 28),

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
              Uri.parse('https://t.me/maklongemis'),
              mode: LaunchMode.externalApplication),
          child: ShaderMask(
            shaderCallback: (b) => _C.accentGrad.createShader(b),
            child: const Text('BELI SEKARANG',
                style: TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ),
      ]),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.circle, color: _C.blueMid, size: 5),
        const SizedBox(width: 8),
        const Text('© 2026 ASTRAL ENGINE',
            style: TextStyle(color: _C.textDim, fontSize: 11,
                fontWeight: FontWeight.w500, letterSpacing: 0.5)),
        const SizedBox(width: 8),
        Icon(Icons.circle, color: _C.blueMid, size: 5),
      ]),
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
        color: _C.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused ? _C.blueMid : _C.border,
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [BoxShadow(color: _C.blueMid.withOpacity(0.15),
                blurRadius: 16, offset: const Offset(0, 4))]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscure,
        validator: widget.validator,
        style: const TextStyle(color: _C.text, fontSize: 15,
            fontWeight: FontWeight.w500),
        cursorColor: _C.blueMid,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(color: _focused ? _C.blueLight : _C.textSub, 
              fontSize: 13, fontWeight: FontWeight.w500),
          floatingLabelStyle:
              const TextStyle(color: _C.blueMid, fontSize: 11),
          prefixIcon: Icon(widget.icon,
              color: _focused ? _C.blueLight : _C.textSub, size: 20),
          suffixIcon: widget.onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    widget.obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _focused ? _C.blueLight : _C.textSub, size: 20,
                  ),
                  onPressed: widget.onToggleObscure,
                )
              : null,
          errorStyle: const TextStyle(color: _C.red, fontSize: 11),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: widget.isLoading ? _C.metalGrad : _C.accentGrad,
              borderRadius: BorderRadius.circular(18),
              boxShadow: _down || widget.isLoading
                  ? []
                  : [
                      BoxShadow(
                        color: _C.blueMid.withOpacity(
                            widget.pulseAnim.value * 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: widget.isLoading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Row(
                        key: ValueKey('idle'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.login_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text('MASUK',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
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
          height: 48,
          width: widget.fullWidth ? double.infinity : null,
          decoration: BoxDecoration(
            gradient: _C.metalGrad,
            borderRadius: BorderRadius.circular(14),
            boxShadow: _down ? [] : [
              BoxShadow(color: _C.blueMid.withOpacity(0.4),
                  blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Center(
            child: Text(widget.label,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 14,
                    letterSpacing: 0.5)),
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
        height: 48,
        width: widget.fullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: _down ? _C.border.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border, width: 1.5),
        ),
        child: Center(
          child: Text(widget.label,
              style: const TextStyle(color: _C.textSub,
                  fontWeight: FontWeight.w700, fontSize: 14,
                  letterSpacing: 0.5)),
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
      ..color = _C.border.withOpacity(0.2)
      ..strokeWidth = 0.8;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        _C.blueMid.withOpacity(0.12 + math.sin(t * math.pi * 2) * 0.04),
        Colors.transparent,
      ], radius: 0.75).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.35),
          radius: size.width * 0.7));
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.35), size.width * 0.7, glow);

    final glow2 = Paint()
      ..shader = RadialGradient(colors: [
        _C.chrome.withOpacity(0.08 + math.cos(t * math.pi * 2) * 0.03),
        Colors.transparent,
      ], radius: 0.5).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.15, size.height * 0.75),
          radius: size.width * 0.4));
    canvas.drawCircle(
        Offset(size.width * 0.15, size.height * 0.75), size.width * 0.4, glow2);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

enum _AlertType { error, warning, success }

const String baseUrl = "http://public.queen-official.com:2720";

// ─── Palette: Biru Tua Metalik (konsisten seluruh app) ───────────────────────
class _C {
  static const bg        = Color(0xFF050A12);
  static const steel     = Color(0xFF1A4F8A);
  static const blueMid   = Color(0xFF2370BE);
  static const blueLight = Color(0xFF4A94E8);
  static const chrome    = Color(0xFF7AB4E8);
  static const frost     = Color(0xFFADD4F5);
  static const text      = Color(0xFFDEEEFB);
  static const textSub   = Color(0xFF6A92B8);
  static const border    = Color(0xFF162B4A);
}

class SplashScreen extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const SplashScreen({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.sessionKey,
    required this.listBug,
    required this.listDoos,
    required this.news,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoCtrl;
  bool _videoReady = false;
  bool _fadeOutStarted = false;
  bool _isSkipped = false;

  // Animations
  late AnimationController _fadeOutCtrl;   // video fade to black
  late AnimationController _uiCtrl;        // UI entrance
  late AnimationController _glowCtrl;      // text glow pulse
  late AnimationController _ringCtrl;      // rotating ring
  late AnimationController _progressCtrl;  // loading bar
  late AnimationController _particleCtrl;  // floating particles
  late AnimationController _skipBtnCtrl;   // skip button animation

  late Animation<double> _uiFade;
  late Animation<Offset>  _uiSlide;
  late Animation<double>  _glowAnim;
  late Animation<double>  _fadeOut;
  late Animation<double>  _skipBtnOpacity;
  late Animation<Offset>  _skipBtnSlide;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initVideo();
  }

  void _initAnimations() {
    _fadeOutCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeOut = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _fadeOutCtrl, curve: Curves.easeIn));

    _uiCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _uiFade  = CurvedAnimation(parent: _uiCtrl, curve: Curves.easeOut);
    _uiSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _uiCtrl, curve: Curves.easeOutCubic));

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat();

    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4));

    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();

    _skipBtnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _skipBtnOpacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _skipBtnCtrl, curve: Curves.easeOut));
    _skipBtnSlide = Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _skipBtnCtrl, curve: Curves.easeOutCubic));
    
    // Show skip button after 0.5 seconds
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _skipBtnCtrl.forward();
    });
  }

  void _initVideo() {
    _videoCtrl = VideoPlayerController.asset('assets/videos/splash.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoCtrl.setLooping(false);
        _videoCtrl.play();

        // Start UI animations after video loads
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _uiCtrl.forward();
            _progressCtrl.forward();
          }
        });

        _videoCtrl.addListener(_onVideoProgress);
      }).catchError((_) {
        // Fallback: no video, still show UI and auto-navigate
        if (mounted) {
          setState(() => _videoReady = false);
          _uiCtrl.forward();
          _progressCtrl.forward();
          Future.delayed(const Duration(seconds: 4), _navigate);
        }
      });
  }

  void _onVideoProgress() {
    if (!mounted || _isSkipped) return;
    final pos = _videoCtrl.value.position;
    final dur = _videoCtrl.value.duration;
    if (dur == Duration.zero) return;

    // Start fade-out 1s before end
    if (pos >= dur - const Duration(seconds: 1) && !_fadeOutStarted) {
      _fadeOutStarted = true;
      _fadeOutCtrl.forward();
    }

    // Navigate when done
    if (pos >= dur) _navigate();
  }

  void _skip() {
    if (_isSkipped) return;
    _isSkipped = true;
    
    // Stop video
    _videoCtrl.pause();
    _videoCtrl.removeListener(_onVideoProgress);
    
    // Start fade out and navigate
    _fadeOutStarted = true;
    _fadeOutCtrl.forward().then((_) {
      if (mounted) _navigate();
    });
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => DashboardPage(
          username:    widget.username,
          password:    widget.password,
          role:        widget.role,
          expiredDate: widget.expiredDate,
          sessionKey:  widget.sessionKey,
          listBug:     widget.listBug,
          listDoos:    widget.listDoos,
          news:        widget.news,
        ),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoCtrl.removeListener(_onVideoProgress);
    _videoCtrl.dispose();
    _fadeOutCtrl.dispose();
    _uiCtrl.dispose();
    _glowCtrl.dispose();
    _ringCtrl.dispose();
    _progressCtrl.dispose();
    _particleCtrl.dispose();
    _skipBtnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Particles background ─────────────────────────────────────
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ParticlePainter(_particleCtrl.value),
              size: size,
            ),
          ),

          // ── Video (full cover) ────────────────────────────────────────
          if (_videoReady && !_isSkipped)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width:  _videoCtrl.value.size.width,
                  height: _videoCtrl.value.size.height,
                  child: VideoPlayer(_videoCtrl),
                ),
              ),
            ),

          // ── Dark overlay for readability ──────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(_videoReady && !_isSkipped ? 0.2 : 0.0),
                    Colors.black.withOpacity(_videoReady && !_isSkipped ? 0.7 : 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── SKIP BUTTON (Top Right) ─────────────────────────────────────
          Positioned(
            top: 16,
            right: 16,
            child: FadeTransition(
              opacity: _skipBtnOpacity,
              child: SlideTransition(
                position: _skipBtnSlide,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _skip,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _C.border.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _C.blueMid.withOpacity(0.5),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _C.blueMid.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.skip_next_rounded,
                            size: 16,
                            color: _C.blueLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Skip',
                            style: TextStyle(
                              color: _C.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
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

          // ── Center logo & title ───────────────────────────────────────
          Positioned.fill(
            child: FadeTransition(
              opacity: _uiFade,
              child: SlideTransition(
                position: _uiSlide,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogoRing(),
                    const SizedBox(height: 36),
                    _buildTitle(),
                    const SizedBox(height: 10),
                    _buildSubtitle(),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom progress & tagline ─────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: FadeTransition(
              opacity: _uiFade,
              child: _buildBottomBar(),
            ),
          ),

          // ── Fade-out overlay ──────────────────────────────────────────
          if (_fadeOutStarted)
            FadeTransition(
              opacity: _fadeOut,
              child: Container(color: _C.bg),
            ),
        ],
      ),
    );
  }

  // ─── Logo Ring ────────────────────────────────────────────────────────────
  Widget _buildLogoRing() {
    return AnimatedBuilder(
      animation: Listenable.merge([_ringCtrl, _glowCtrl]),
      builder: (_, __) => SizedBox(
        width: 160, height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer static ring
            Container(
              width: 158, height: 158,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _C.blueMid.withOpacity(_glowAnim.value * 0.15),
                  width: 1,
                ),
              ),
            ),
            // Rotating dashed-style ring
            Transform.rotate(
              angle: _ringCtrl.value * math.pi * 2,
              child: Container(
                width: 138, height: 138,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      _C.blueLight.withOpacity(_glowAnim.value * 0.7),
                      Colors.transparent,
                      _C.chrome.withOpacity(_glowAnim.value * 0.4),
                      Colors.transparent,
                      _C.blueLight.withOpacity(_glowAnim.value * 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Counter-rotating inner ring
            Transform.rotate(
              angle: -_ringCtrl.value * math.pi * 2 * 0.6,
              child: Container(
                width: 118, height: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _C.steel.withOpacity(_glowAnim.value * 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            // Core glow
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.bg,
                boxShadow: [
                  BoxShadow(
                    color: _C.blueMid.withOpacity(_glowAnim.value * 0.55),
                    blurRadius: 40,
                    spreadRadius: 0,
                  ),
                ],
                border: Border.all(
                  color: _C.blueLight.withOpacity(_glowAnim.value * 0.5),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(Icons.water_rounded,
                        color: _C.blueLight.withOpacity(_glowAnim.value),
                        size: 44),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Title ────────────────────────────────────────────────────────────────
  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => ShaderMask(
        shaderCallback: (b) => LinearGradient(
          colors: [
            _C.chrome,
            _C.frost.withOpacity(0.9 + _glowAnim.value * 0.1),
            _C.blueLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(b),
        child: Text(
          'Super Nova',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                color: _C.blueMid.withOpacity(_glowAnim.value * 0.8),
                blurRadius: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _C.border.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _C.blueMid.withOpacity(_glowAnim.value * 0.25),
          ),
        ),
        child: Text(
          'Powered by @yatimloehk',
          style: TextStyle(
            color: _C.textSub.withOpacity(0.7 + _glowAnim.value * 0.3),
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // ─── Bottom Bar ───────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 52),
      child: Column(
        children: [
          // Loading dots
          _LoadingDots(),
          const SizedBox(height: 18),

          // Progress bar
          AnimatedBuilder(
            animation: _progressCtrl,
            builder: (_, __) => Column(children: [
              // Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(children: [
                  Container(
                    height: 3,
                    width: double.infinity,
                    color: _C.border.withOpacity(0.5),
                  ),
                  Container(
                    height: 3,
                    width: (MediaQuery.of(context).size.width - 64) *
                        _progressCtrl.value,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_C.steel, _C.blueMid, _C.blueLight],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: _C.blueMid.withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Text(
                '${(_progressCtrl.value * 100).toInt()}%  Memuat...',
                style: const TextStyle(
                  color: _C.textSub,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Loading Dots ─────────────────────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
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
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.blueMid.withOpacity(0.35 + s * 0.65),
                  boxShadow: [
                    BoxShadow(
                      color: _C.blueMid.withOpacity(s * 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Particle Painter ─────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double t;
  _ParticlePainter(this.t);

  static final _rand = math.Random(42);
  static final _particles = List.generate(28, (i) => _Particle(
    x: _rand.nextDouble(),
    y: _rand.nextDouble(),
    size: 1.0 + _rand.nextDouble() * 2.0,
    speed: 0.04 + _rand.nextDouble() * 0.1,
    phase: _rand.nextDouble(),
    opacity: 0.15 + _rand.nextDouble() * 0.35,
  ));

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final grid = Paint()
      ..color = const Color(0xFF162B4A).withOpacity(0.3)
      ..strokeWidth = 0.5;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Central glow
    final center = Offset(size.width / 2, size.height * 0.38);
    final glow   = Paint()
      ..shader = RadialGradient(colors: [
        _C.steel.withOpacity(0.18 + math.sin(t * math.pi * 2) * 0.06),
        Colors.transparent,
      ], radius: 0.6).createShader(
          Rect.fromCircle(center: center, radius: size.width * 0.7));
    canvas.drawCircle(center, size.width * 0.7, glow);

    // Floating particles
    for (final p in _particles) {
      final px = p.x * size.width;
      final rawY = p.y + (t * p.speed) % 1.0;
      final py = (rawY % 1.0) * size.height;
      final drift = math.sin((t + p.phase) * math.pi * 2) * 8;
      final osc = math.sin((t * 2 + p.phase) * math.pi);
      final opacity = p.opacity * (0.5 + osc * 0.5);

      canvas.drawCircle(
        Offset(px + drift, py),
        p.size,
        Paint()..color = _C.blueLight.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

class _Particle {
  final double x, y, size, speed, phase, opacity;
  const _Particle({
    required this.x, required this.y, required this.size,
    required this.speed, required this.phase, required this.opacity,
  });
}