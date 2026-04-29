import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../core/database/database_helper.dart';
import '../../home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool get _canLogin => _usernameCtrl.text.trim().isNotEmpty && _passwordCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
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
      _error = null;
    });

    final user = await DatabaseHelper.instance.login(_usernameCtrl.text.trim(), _passwordCtrl.text.trim());

    if (!mounted) return;
    setState(() => _loading = false);

    if (user != null) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => HomePage(userRole: user['role'] as String, username: user['username'] as String),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else {
      setState(() => _error = 'Username atau password salah. Coba lagi.');
      _passwordCtrl.clear();
      _passwordFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    
    // Lebar card: maksimal 450px, di tablet di tengah
    final cardWidth = isTablet ? 450.0 : size.width * 0.9;
    final horizontalPadding = isTablet ? 32.0 : 24.0;
    final verticalPadding = isTablet ? 48.0 : 60.0;

    return Scaffold(
      backgroundColor: PosColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PosColors.background,
              PosColors.primaryBg,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: PosColors.surface,
                      borderRadius: BorderRadius.circular(PosRadius.xl),
                      boxShadow: const [PosShadows.lg],
                      border: Border.all(color: PosColors.border),
                    ),
                    child: _formContent(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildLogo(),
        const SizedBox(height: 24),
        _buildTitle(),
        const SizedBox(height: 32),
        _buildUsernameField(),
        const SizedBox(height: 16),
        _buildPasswordField(),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _error != null ? _ErrorBanner(message: _error!) : const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
        _buildLoginButton(),
        const SizedBox(height: 20),
        _buildKasirHint(),
      ],
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadius.xl),
        border: Border.all(color: PosColors.border, width: 1.5),
        boxShadow: const [PosShadows.md],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PosRadius.xl - 1.5),
        child: Image.asset(
          'assets/images/logo/logo_usaha.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              color: PosColors.primaryBg,
              borderRadius: BorderRadius.circular(PosRadius.xl - 1.5),
            ),
            child: const Icon(Icons.restaurant_rounded, color: PosColors.primary, size: 36),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        const Text(
          'Seblak Kacida',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: PosColors.textPrimary, letterSpacing: -0.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: PosColors.primaryBg, borderRadius: BorderRadius.circular(PosRadius.xxl)),
          child: const Text('Point of Sale System',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PosColors.primary, letterSpacing: 0.3)),
        ),
        const SizedBox(height: 12),
        const Text('Masuk untuk mulai berjualan',
            style: TextStyle(fontSize: 14, color: PosColors.textSecondary), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Username'),
        const SizedBox(height: 8),
        TextField(
          controller: _usernameCtrl,
          focusNode: _usernameFocus,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 15, color: PosColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Masukkan username',
            hintStyle: const TextStyle(fontSize: 14),
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
            fillColor: PosColors.surface,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.primary, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.error, width: 1.5)),
          ),
        ),
      ],
    );
  }
 
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Password'),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          focusNode: _passwordFocus,
          obscureText: _obscure,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _login(),
          textInputAction: TextInputAction.done,
          style: const TextStyle(fontSize: 15, color: PosColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Masukkan password',
            hintStyle: const TextStyle(fontSize: 14),
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: PosColors.textMuted),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            fillColor: PosColors.surface,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.primary, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.error, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_canLogin && !_loading) ? _login : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: PosColors.primary,
          disabledBackgroundColor: PosColors.primaryLight.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosRadius.md)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Text('Masuk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildKasirHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PosColors.surfaceAlt,
        borderRadius: BorderRadius.circular(PosRadius.md),
        border: Border.all(color: PosColors.border),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: PosColors.info),
              SizedBox(width: 8),
              Text(
                'Info Login Kasir',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PosColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: PosColors.primaryBg,
                  borderRadius: BorderRadius.circular(PosRadius.sm),
                ),
                child: const Text(
                  'Username: kasir',
                  style: TextStyle(fontSize: 12, color: PosColors.primary, fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: PosColors.primaryBg,
                  borderRadius: BorderRadius.circular(PosRadius.sm),
                ),
                child: const Text(
                  'Password: kasir123',
                  style: TextStyle(fontSize: 12, color: PosColors.primary, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '(tanyakan ke owner untuk login admin)',
            style: TextStyle(fontSize: 10, color: PosColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SMALL WIDGETS
// ============================================================

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PosColors.errorBg,
        borderRadius: BorderRadius.circular(PosRadius.md),
        border: Border.all(color: PosColors.primaryLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: PosColors.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: PosColors.error, fontWeight: FontWeight.w500))),
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
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PosColors.textSecondary));
  }
}