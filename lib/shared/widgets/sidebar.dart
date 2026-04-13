import 'package:flutter/material.dart';
import '../../theme.dart';

class Sidebar extends StatelessWidget {
  final int          selectedIndex;
  final Function(int) onMenuTap;
  final String       userRole;
  final String       username;
  final VoidCallback onLogout;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onMenuTap,
    required this.userRole,
    required this.username,
    required this.onLogout,
  });

  static const List<_MenuItem> _adminMenus = [
    _MenuItem(index: 0, icon: Icons.grid_view_rounded,      label: 'Dashboard'),
    _MenuItem(index: 1, icon: Icons.storefront_rounded,     label: 'Kasir'),
    _MenuItem(index: 2, icon: Icons.inventory_2_rounded,    label: 'Produk'),
    _MenuItem(index: 3, icon: Icons.receipt_long_rounded,   label: 'Transaksi'),
    _MenuItem(index: 4, icon: Icons.bar_chart_rounded,      label: 'Laporan'),
    _MenuItem(index: 5, icon: Icons.settings_rounded,       label: 'Setting'),
    _MenuItem(index: 6, icon: Icons.bug_report_rounded,     label: 'Database'),
  ];

  static const List<_MenuItem> _kasirMenus = [
    _MenuItem(index: 0, icon: Icons.grid_view_rounded,    label: 'Dashboard'),
    _MenuItem(index: 1, icon: Icons.storefront_rounded,   label: 'Kasir'),
    _MenuItem(index: 2, icon: Icons.receipt_long_rounded, label: 'Transaksi'),
  ];

  List<_MenuItem> get _menus =>
      userRole == 'kasir' ? _kasirMenus : _adminMenus;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: PosColors.sidebarBg,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: _menus
                    .map((m) => _SidebarItem(
                          item:       m,
                          isSelected: selectedIndex == m.index,
                          onTap:      () => onMenuTap(m.index),
                        ))
                    .toList(),
              ),
            ),
            _buildLogout(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(PosRadius.md),
            child: Image.asset(
              'assets/images/logo/logo_usaha.jpg',
              width: 44, height: 44, fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color:        PosColors.primary,
                  borderRadius: BorderRadius.circular(PosRadius.md),
                ),
                child: const Icon(Icons.restaurant,
                    color: Colors.white, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Seblak POS',
                    style: TextStyle(
                        color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(
                  userRole == 'admin' ? 'Admin Panel' : 'Kasir Panel',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: _LogoutButton(onTap: onLogout),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'v1.0 • $username',
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 10, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Sidebar Item ──────────────────────────────────────────

class _SidebarItem extends StatefulWidget {
  final _MenuItem    item;
  final bool         isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.isSelected;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        cursor:  SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve:    Curves.easeOut,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: sel
                  ? PosColors.primary
                  : _hovered
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(PosRadius.md),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3, height: 18,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(widget.item.icon,
                    size: 19,
                    color: sel ? Colors.white : PosColors.sidebarText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.item.label,
                      style: TextStyle(
                          color: sel ? Colors.white : PosColors.sidebarText,
                          fontSize: 13.5,
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: -0.1)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Logout Button ─────────────────────────────────────────

class _LogoutButton extends StatefulWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.red.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(PosRadius.md),
            border: Border.all(
              color: _hovered
                  ? PosColors.primary.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 13),
              Icon(Icons.logout_rounded,
                  size: 19,
                  color: _hovered
                      ? PosColors.primary
                      : PosColors.sidebarText),
              const SizedBox(width: 10),
              Text('Logout',
                  style: TextStyle(
                      color: _hovered
                          ? PosColors.primary
                          : PosColors.sidebarText,
                      fontSize: 13.5, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────

class _MenuItem {
  final int      index;
  final IconData icon;
  final String   label;
  const _MenuItem(
      {required this.index, required this.icon, required this.label});
}