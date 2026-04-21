import 'package:flutter/material.dart';
import 'theme.dart';
import 'core/utils/responsive.dart';
import 'shared/widgets/sidebar.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/kasir/kasir_page.dart';
import 'features/produk/produk_page.dart';
import 'features/transaksi/transaksi_page.dart';
import 'features/laporan/laporan_page.dart';
import 'features/setting/setting_page.dart';
import 'features/debug/debug_page.dart';

class HomePage extends StatefulWidget {
  final String userRole;
  final String username;

  const HomePage({
    super.key,
    required this.userRole,
    required this.username,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 1;

  bool get _isKasir => widget.userRole == 'kasir';

  late final List<Widget> _adminPages = [
    const DashboardPage(),
    const KasirPage(),
    const ProdukPage(),
    const TransaksiPage(),
    const LaporanPage(),
    const SettingPage(),
    const DebugPage(),   // index 6
  ];

  late final List<Widget> _kasirPages = [
    const DashboardPage(),
    const KasirPage(),
    const TransaksiPage(),
  ];

  List<Widget> get _pages => _isKasir ? _kasirPages : _adminPages;

  @override
  void initState() {
    super.initState();
    // Sheets service disabled
  }

  String get _pageTitle {
    if (_isKasir) {
      switch (_selectedIndex) {
        case 0: return 'Dashboard';
        case 1: return 'Kasir';
        case 2: return 'Transaksi';
        default: return 'Seblak Kacida';
      }
    }
    switch (_selectedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'Kasir';
      case 2: return 'Produk';
      case 3: return 'Transaksi';
      case 4: return 'Laporan';
      case 5: return 'Setting';
      case 6: return 'Database';
      default: return 'Seblak Kacida';
    }
  }

  void _onMenuTap(int index) {
    if (index >= _pages.length) return;
    setState(() => _selectedIndex = index);
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => _LogoutDialog(
        onConfirm: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (_) => false,
          );
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: PosColors.background,
      appBar:  isMobile ? _buildAppBar() : null,
      drawer:  isMobile ? _buildDrawer()  : null,
      body: Row(
        children: [
          if (!isMobile)
            Sidebar(
              selectedIndex: _selectedIndex,
              onMenuTap:     _onMenuTap,
              userRole:      widget.userRole,
              username:      widget.username,
              onLogout:      _logout,
            ),
          Expanded(
            child: ClipRect(
              child: IndexedStack(
                index:    _selectedIndex.clamp(0, _pages.length - 1),
                children: _pages,
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: PosColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded,
              color: PosColors.textPrimary, size: 24),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(PosRadius.sm),
            child: Image.asset(
              'assets/images/logo/logo_usaha.jpg',
              width: 28, height: 28, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color:        PosColors.primary,
                  borderRadius: BorderRadius.circular(PosRadius.sm),
                ),
                child: const Icon(Icons.restaurant,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(_pageTitle,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700,
                  color: PosColors.textPrimary, letterSpacing: -0.3)),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: PosColors.border),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: PosColors.sidebarBg,
      width: 240,
      child: Sidebar(
        selectedIndex: _selectedIndex,
        onMenuTap: (index) {
          Navigator.of(context).pop();
          _onMenuTap(index);
        },
        userRole: widget.userRole,
        username: widget.username,
        onLogout: () {
          Navigator.of(context).pop();
          _logout();
        },
      ),
    );
  }
}

// ── Logout Dialog ─────────────────────────────────────────

class _LogoutDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _LogoutDialog(
      {required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PosColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(PosSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color:        PosColors.errorBg,
                borderRadius: BorderRadius.circular(PosRadius.xl),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: PosColors.primary, size: 28),
            ),
            const SizedBox(height: PosSpacing.md),
            const Text('Keluar dari Akun?',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    color: PosColors.textPrimary,
                    letterSpacing: -0.3)),
            const SizedBox(height: 6),
            const Text(
              'Anda akan keluar dari sesi ini.\nPastikan semua transaksi sudah selesai.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: PosColors.textSecondary,
                  height: 1.5),
            ),
            const SizedBox(height: PosSpacing.lg),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: PosColors.border)),
                  child: const Text('Batal',
                      style: TextStyle(
                          color: PosColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: PosColors.primary,
                      padding:
                          const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Keluar',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
