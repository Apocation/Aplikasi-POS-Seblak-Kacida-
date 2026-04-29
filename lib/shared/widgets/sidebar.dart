import 'package:flutter/material.dart';
import '../../theme.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onMenuTap;
  final String userRole;
  final String username;
  final VoidCallback onLogout;
  final double customWidth;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onMenuTap,
    required this.userRole,
    required this.username,
    required this.onLogout,
    this.customWidth = 180, // DIKECILKAN dari 200 jadi 180
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  static const List<_MenuItem> _adminMenus = [
    _MenuItem(index: 0, icon: Icons.grid_view_rounded, label: 'Dashboard'),
    _MenuItem(index: 1, icon: Icons.storefront_rounded, label: 'Kasir'),
    _MenuItem(index: 2, icon: Icons.inventory_2_rounded, label: 'Produk'),
    _MenuItem(index: 3, icon: Icons.receipt_long_rounded, label: 'Transaksi'),
    _MenuItem(index: 4, icon: Icons.bar_chart_rounded, label: 'Laporan'),
    _MenuItem(index: 5, icon: Icons.settings_rounded, label: 'Setting'),
    _MenuItem(index: 6, icon: Icons.bug_report_rounded, label: 'Database'),
  ];

  static const List<_MenuItem> _kasirMenus = [
    _MenuItem(index: 0, icon: Icons.grid_view_rounded, label: 'Dashboard'),
    _MenuItem(index: 1, icon: Icons.storefront_rounded, label: 'Kasir'),
    _MenuItem(index: 2, icon: Icons.receipt_long_rounded, label: 'Transaksi'),
  ];

  List<_MenuItem> get _menus => userRole == 'kasir' ? _kasirMenus : _adminMenus;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: customWidth,
      color: PosColors.sidebarBg,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: _menus
                    .map((m) => _SidebarItem(
                          item: m,
                          isSelected: selectedIndex == m.index,
                          onTap: () => onMenuTap(m.index),
                          isCollapsed: isCollapsed,
                        ))
                    .toList(),
              ),
            ),
            _buildLogout(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
      ),
      child: Column(
        children: [
          // HANYA LOGO (tanpa tombol ☰)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PosRadius.md),
              child: Image.asset(
                'assets/images/logo/logo_usaha.jpg',
                width: isCollapsed ? 36 : 44,
                height: isCollapsed ? 36 : 44,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: isCollapsed ? 36 : 44,
                  height: isCollapsed ? 36 : 44,
                  decoration: BoxDecoration(
                    color: PosColors.primary,
                    borderRadius: BorderRadius.circular(PosRadius.md),
                  ),
                  child: const Icon(Icons.restaurant, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(height: 12),
            const Text(
              'Seblak Kacida',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              userRole == 'admin' ? 'Admin Panel' : 'Kasir Panel',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: _LogoutButton(
        onTap: onLogout,
        isCollapsed: isCollapsed,
      ),
    );
  }
}

// ── Sidebar Item ──────────────────────────────────────────

class _SidebarItem extends StatefulWidget {
  final _MenuItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCollapsed;

  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.isCollapsed = false,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.isSelected;
    final collapsed = widget.isCollapsed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 12,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: sel
                  ? PosColors.primary
                  : _hovered
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(PosRadius.md),
            ),
            child: Center(
              child: collapsed
                  ? Tooltip(
                      message: widget.item.label,
                      child: Icon(
                        widget.item.icon,
                        size: 22,
                        color: sel ? Colors.white : PosColors.sidebarText,
                      ),
                    )
                  : Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 3,
                          height: 18,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: sel
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Icon(
                          widget.item.icon,
                          size: 19,
                          color: sel ? Colors.white : PosColors.sidebarText,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.item.label,
                            style: TextStyle(
                              color: sel ? Colors.white : PosColors.sidebarText,
                              fontSize: 13.5,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                              letterSpacing: -0.1,
                            ),
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

// ── Logout Button ─────────────────────────────────────────

class _LogoutButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isCollapsed;

  const _LogoutButton({
    required this.onTap,
    this.isCollapsed = false,
  });

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.isCollapsed;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 12,
            vertical: 11,
          ),
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
          child: collapsed
              ? Tooltip(
                  message: 'Logout',
                  child: Icon(
                    Icons.logout_rounded,
                    size: 22,
                    color: _hovered ? PosColors.primary : PosColors.sidebarText,
                  ),
                )
              : Row(
                  children: [
                    const SizedBox(width: 13),
                    Icon(
                      Icons.logout_rounded,
                      size: 19,
                      color: _hovered ? PosColors.primary : PosColors.sidebarText,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: _hovered ? PosColors.primary : PosColors.sidebarText,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────

class _MenuItem {
  final int index;
  final IconData icon;
  final String label;

  const _MenuItem({
    required this.index,
    required this.icon,
    required this.label,
  });
}