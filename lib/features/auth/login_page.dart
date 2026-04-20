import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../core/database/database_helper.dart';
import '../../home_page.dart';


// ============================================================
//  LOGIN PAGE
//  Clean light theme, logo usaha, form username + password
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscure   = true;
  bool _loading   = false;
  String? _error;

  // Animasi fade-in saat halaman muncul
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  bool get _canLogin =>
      _usernameCtrl.text.trim().isNotEmpty &&
      _passwordCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_canLogin) return;

    setState(() {
      _loading = true;
      _error   = null;
    });

    final user = await DatabaseHelper.instance.login(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (user != null) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => HomePage(
            userRole: user['role'] as String,
            username: user['username'] as String,
          ),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else {
      setState(() =>
          _error = 'Username atau password salah. Coba lagi.');
      // Shake effect — rebuild dengan error
      _passwordCtrl.clear();
      _passwordFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size       = MediaQuery.of(context).size;
    final isWide     = size.width > 700;
    final cardWidth  = isWide ? 420.0 : size.width.toDouble();

    return Scaffold(
      backgroundColor: PosColors.background,
      body: isWide
          ? _wideLayout(cardWidth)
          : _mobileLayout(),
    );
  }

  // ── Wide layout: center card ──────────────────────────────
  Widget _wideLayout(double cardWidth) {
    return Stack(
      children: [
        // Dekorasi bg
        Positioned(
          top:    -80,
          right:  -80,
          child:  _BgCircle(size: 320, color: PosColors.primaryBg),
        ),
        Positioned(
          bottom: -60,
          left:   -60,
          child:  _BgCircle(size: 260, color: PosColors.infoBg),
        ),
        // Card center
        Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                width:  cardWidth,
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: PosColors.surface,
                  borderRadius: BorderRadius.circular(PosRadius.xxl),
                  boxShadow: const [PosShadows.lg],
                  border: Border.all(color: PosColors.border),
                ),
                child: _formContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile layout: full scroll ────────────────────────────
  Widget _mobileLayout() {
    return SingleChildScrollView(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
            child: _formContent(),
          ),
        ),
      ),
    );
  }

  // ── Form content (shared) ─────────────────────────────────
  Widget _formContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildLogo(),
        const SizedBox(height: 28),
        _buildTitle(),
        const SizedBox(height: 32),
        _buildUsernameField(),
        const SizedBox(height: 14),
        _buildPasswordField(),
        const SizedBox(height: 12),
        // Error message
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _error != null
              ? _ErrorBanner(message: _error!)
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        _buildLoginButton(),
        const SizedBox(height: 28),
        _buildFooterHint(),
      ],
    );
  }

  // ── Logo ──────────────────────────────────────────────────
  Widget _buildLogo() {
    return Column(
      children: [
        // Logo usaha
        Container(
          width:  80,
          height: 80,
          decoration: BoxDecoration(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadius.xl),
            border: Border.all(color: PosColors.border, width: 1.5),
            boxShadow: const [PosShadows.md],
          ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(PosRadius.xl - 1.5),
            child: Image.asset(
              'assets/images/logo/logo_usaha.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                decoration: BoxDecoration(
                  color: PosColors.primaryBg,
                  borderRadius:
                      BorderRadius.circular(PosRadius.xl - 1.5),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: PosColors.primary,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Title ─────────────────────────────────────────────────
  Widget _buildTitle() {
    return Column(
      children: [
        const Text(
          'Seblak Kacida',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: PosColors.textPrimary,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: PosColors.primaryBg,
            borderRadius: BorderRadius.circular(PosRadius.xxl),
          ),
          child: const Text(
            'Point of Sale System',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PosColors.primary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Masuk untuk mulai berjualan',
          style: TextStyle(
            fontSize: 14,
            color: PosColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Username field ────────────────────────────────────────
  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Username'),
        const SizedBox(height: 6),
        TextField(
          controller:  _usernameCtrl,
          focusNode:   _usernameFocus,
          onChanged:   (_) => setState(() => _error = null),
          onSubmitted: (_) =>
              FocusScope.of(context).requestFocus(_passwordFocus),
          textInputAction: TextInputAction.next,
          style: const TextStyle(
              fontSize: 14, color: PosColors.textPrimary),
          decoration: InputDecoration(
            hintText:   'Masukkan username',
            prefixIcon: const Icon(Icons.person_outline_rounded,
                size: 18),
            fillColor:  PosColors.surface,
            filled:     true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PosRadius.md),
              borderSide:
                  const BorderSide(color: PosColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PosRadius.md),
              borderSide:
                  const BorderSide(color: PosColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PosRadius.md),
              borderSide: const BorderSide(
                  color: PosColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PosRadius.md),
              borderSide: const BorderSide(
                  color: PosColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── Password field ────────────────────────────────────────
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Password'),
        const SizedBox(height: 6),
        TextField(
          controller:     _passwordCtrl,
          focusNode:      _passwordFocus,
          obscureText:    _obscure,
          onChanged:      (_) => setState(() => _error = null),
          onSubmitted:    (_) => _login(),
          textInputAction: TextInputAction.done,
          style: const TextStyle(
              fontSize: 14, color: PosColors.textPrimary),
          decoration: InputDecoration(
            hintText:   'Masukkan password',
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: PosColors.textMuted,
              ),
              onPressed: () =>
                  setState(() => _obscure = !_obscure),
            ),
            fillColor:  PosColors.surface,
            filled:     true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PosRadius.md),
              borderSide:
                  const BorderSide(color: PosColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PosRadius.md),
              borderSide:
                  const BorderSide(color: PosColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PosRadius.md),
              borderSide: const BorderSide(
                  color: PosColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PosRadius.md),
              borderSide: const BorderSide(
                  color: PosColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── Login button ──────────────────────────────────────────
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_canLogin && !_loading) ? _login : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: PosColors.primary,
          disabledBackgroundColor:
              PosColors.primaryLight.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadius.md),
          ),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width:  20,
                height: 20,
                child:  CircularProgressIndicator(
                  color:       Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Masuk',
                style: TextStyle(
                  fontSize:    15,
                  fontWeight:  FontWeight.w700,
                  color:       Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }

  // ── Footer hint ───────────────────────────────────────────
  Widget _buildFooterHint() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: PosColors.surfaceAlt,
                borderRadius:
                    BorderRadius.circular(PosRadius.md),
              ),
              child: Column(
                children: const [
                  Text(
                    'Default Login',
                    style: TextStyle(
                      fontSize:   11,
                      color:      PosColors.textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  _LoginHint(role: 'Admin',
                      user: 'admin', pass: 'admin123'),
                  SizedBox(height: 4),
                  _LoginHint(role: 'Kasir',
                      user: 'kasir', pass: 'kasir123'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
//  SMALL WIDGETS
// ============================================================

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color:        PosColors.errorBg,
        borderRadius: BorderRadius.circular(PosRadius.md),
        border:       Border.all(color: PosColors.primaryLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: PosColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize:   13,
                color:      PosColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize:   13,
        fontWeight: FontWeight.w600,
        color:      PosColors.textSecondary,
      ),
    );
  }
}

class _LoginHint extends StatelessWidget {
  final String role;
  final String user;
  final String pass;
  const _LoginHint({
    required this.role,
    required this.user,
    required this.pass,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$role: ',
          style: const TextStyle(
              fontSize: 11, color: PosColors.textMuted),
        ),
        Text(
          '$user / $pass',
          style: const TextStyle(
            fontSize:   11,
            fontWeight: FontWeight.w600,
            color:      PosColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BgCircle extends StatelessWidget {
  final double size;
  final Color  color;
  const _BgCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        color:  color,
        shape:  BoxShape.circle,
      ),
    );
  }
}