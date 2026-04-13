import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/sheets_service.dart';

// ============================================================
//  DEBUG PAGE — Database Viewer
//  Taruh di: lib/features/debug/debug_page.dart
// ============================================================

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _produk     = [];
  List<Map<String, dynamic>> _transaksi  = [];
  List<Map<String, dynamic>> _items      = [];
  List<Map<String, dynamic>> _users      = [];

  bool   _loading      = true;
  String _errorMessage = '';
  int    _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading      = true;
      _errorMessage = '';
    });

    try {
      // Ambil data via DatabaseHelper (bukan langsung akses .database)
      final produk    = await DatabaseHelper.instance.getProducts();
      final transaksi = await DatabaseHelper.instance.getOrders();
      final pending = await SheetsService.instance.getPendingCount();

      // Order items — query manual via db
      List<Map<String, dynamic>> enrichedItems = [];
      try {
        final db = await DatabaseHelper.instance.database;
        final rawItems = await db.rawQuery('''
          SELECT
            oi.id         AS item_id,
            oi.order_id,
            oi.quantity,
            oi.subtotal,
            p.name        AS product_name,
            o.created_at  AS order_date,
            o.payment_method
          FROM order_items oi
          LEFT JOIN products p ON p.id = oi.product_id
          LEFT JOIN orders   o ON o.id = oi.order_id
          ORDER BY o.created_at DESC
          LIMIT 100
        ''');
        enrichedItems = rawItems;
      } catch (e) {
        // Kalau query gagal, tetap lanjut dengan data kosong
        enrichedItems = [];
      }

      // Users
      List<Map<String, dynamic>> users = [];
      try {
        final db = await DatabaseHelper.instance.database;
        users    = await db.query('users');
      } catch (_) {
        users = [];
      }

      if (!mounted) return;
      setState(() {
        _produk      = produk;
        _transaksi   = transaksi;
        _items       = enrichedItems;
        _users       = users;
        _pendingCount = pending;
        _loading     = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading      = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ── Format helpers ────────────────────────────────────────
  String _formatRp(dynamic val) {
    final d = (val as num?)?.toDouble() ?? 0.0;
    return 'Rp ${d.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
  }

  String _shortDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h  = dt.hour.toString().padLeft(2, '0');
      final m  = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month}/${dt.year} $h:$m';
    } catch (_) {
      return iso.length > 16 ? iso.substring(0, 16) : iso;
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         const Text('Disalin ke clipboard'),
        backgroundColor: PosColors.success,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadius.md)),
        margin:   const EdgeInsets.all(16),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ── Summary stats ─────────────────────────────────────────
  double get _totalOmzet => _transaksi.fold(
      0.0,
      (s, t) =>
          s + ((t['total_price'] as num?)?.toDouble() ?? 0.0));

  int get _stokHabis =>
      _produk.where((p) => (p['stock'] as int? ?? 0) == 0).length;

  // _stokRendah unused - removed

  // ============================================================
  //  BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final pad      = isMobile ? 16.0 : 24.0;

    if (_loading) {
      return const Scaffold(
        backgroundColor: PosColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: PosColors.primary),
              SizedBox(height: 16),
              Text('Memuat database...',
                  style: TextStyle(color: PosColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: PosColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 56, color: PosColors.error),
                const SizedBox(height: 16),
                const Text('Gagal memuat database',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: PosColors.textPrimary)),
                const SizedBox(height: 8),
                Text(_errorMessage,
                    style: const TextStyle(
                        fontSize: 12, color: PosColors.textMuted),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon:  const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('🔍 ', style: TextStyle(fontSize: 22)),
                          Text('Database Viewer',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: PosColors.textPrimary,
                                  letterSpacing: -0.4)),
                        ]),
                        SizedBox(height: 4),
                        Text('Lihat isi database secara langsung',
                            style: TextStyle(
                                fontSize: 13,
                                color: PosColors.textSecondary)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap:        _load,
                    borderRadius: BorderRadius.circular(PosRadius.md),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:        PosColors.surface,
                        borderRadius:
                            BorderRadius.circular(PosRadius.md),
                        border: Border.all(color: PosColors.border),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          size: 18,
                          color: PosColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Summary cards
            _buildSummaryCards(pad),
            const SizedBox(height: 12),

            // Sheets queue badge
            if (_pendingCount > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color:        PosColors.warningBg,
                    borderRadius: BorderRadius.circular(PosRadius.md),
                    border: Border.all(
                        color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.schedule_rounded,
                        size: 15, color: PosColors.warning),
                    const SizedBox(width: 8),
                    Text(
                      '$_pendingCount transaksi belum terkirim ke Google Sheets',
                      style: const TextStyle(
                          fontSize: 12, color: PosColors.warning,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ),
            if (_pendingCount > 0) const SizedBox(height: 8),

            // Tab bar
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: pad),
              child: Container(
                decoration: posCardDecoration(withShadow: false),
                child: TabBar(
                  controller:              _tabCtrl,
                  labelColor:              PosColors.primary,
                  unselectedLabelColor:    PosColors.textMuted,
                  indicatorColor:          PosColors.primary,
                  indicatorSize:           TabBarIndicatorSize.tab,
                  isScrollable:            isMobile,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  unselectedLabelStyle:
                      const TextStyle(fontSize: 12),
                  tabs: [
                    Tab(text: 'Produk (${_produk.length})'),
                    Tab(text: 'Transaksi (${_transaksi.length})'),
                    Tab(text: 'Items (${_items.length})'),
                    Tab(text: 'Users (${_users.length})'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildProdukTab(pad),
                  _buildTransaksiTab(pad),
                  _buildItemsTab(pad),
                  _buildUsersTab(pad),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary cards ─────────────────────────────────────────
  Widget _buildSummaryCards(double pad) {
    final cards = [
      _DbStat('Produk',    '${_produk.length}',
          Icons.inventory_2_rounded, PosColors.info),
      _DbStat('Transaksi', '${_transaksi.length}',
          Icons.receipt_long_rounded, PosColors.success),
      _DbStat('Omzet',     _formatRp(_totalOmzet),
          Icons.attach_money_rounded, PosColors.primary),
      _DbStat('Stok Habis','$_stokHabis',
          Icons.warning_rounded, PosColors.error),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: Row(
        children: cards.map((c) => Container(
          width:  155,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(14),
          decoration: posCardDecoration(),
          child: Row(children: [
            Icon(c.icon, size: 20, color: c.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.label,
                      style: const TextStyle(
                          fontSize: 11, color: PosColors.textMuted,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(c.value,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: c.color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
        )).toList(),
      ),
    );
  }

  // ── Tab: Produk ───────────────────────────────────────────
  Widget _buildProdukTab(double pad) {
    if (_produk.isEmpty) return _emptyState('Belum ada produk');

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
      itemCount: _produk.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p     = _produk[i];
        final stock = p['stock'] as int? ?? 0;
        final Color rowColor;
        if (stock == 0)      rowColor = PosColors.errorBg;
        else if (stock < 10) rowColor = PosColors.warningBg;
        else                 rowColor = PosColors.surface;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        rowColor,
            borderRadius: BorderRadius.circular(PosRadius.md),
            border:       Border.all(color: PosColors.border),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['name'] as String? ?? '-',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: PosColors.textPrimary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _Tag(p['category'] as String? ?? '-',
                        PosColors.infoBg, PosColors.info),
                    const SizedBox(width: 6),
                    _Tag(_formatRp(p['price'] as num? ?? 0),
                        PosColors.primaryBg, PosColors.primary),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Stok: $stock',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: stock == 0
                            ? PosColors.error
                            : stock < 10
                                ? PosColors.warning
                                : PosColors.success)),
                const SizedBox(height: 4),
                _Tag(
                  stock > 0 ? 'Aktif' : 'Habis',
                  stock > 0 ? PosColors.successBg : PosColors.errorBg,
                  stock > 0 ? PosColors.success   : PosColors.error,
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy_rounded,
                  size: 16, color: PosColors.textMuted),
              onPressed: () => _copy(
                  '${p['name']}\t${p['category']}\t'
                  '${p['price']}\t$stock'),
              tooltip: 'Copy baris',
            ),
          ]),
        );
      },
    );
  }

  // ── Tab: Transaksi ────────────────────────────────────────
  Widget _buildTransaksiTab(double pad) {
    if (_transaksi.isEmpty) return _emptyState('Belum ada transaksi');

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
      itemCount: _transaksi.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final t      = _transaksi[i];
        final id     = (t['id'] as String? ?? '');
        final shortId = id.length >= 8
            ? id.substring(0, 8).toUpperCase()
            : id.toUpperCase();
        final total  = (t['total_price'] as num?)?.toDouble() ?? 0.0;
        final method = t['payment_method'] as String? ?? '-';
        final status = t['status'] as String? ?? '-';
        final date   = _shortDate(t['created_at'] as String?);
        final isPaid = status == 'Paid';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isPaid ? PosColors.successBg : PosColors.warningBg,
            borderRadius: BorderRadius.circular(PosRadius.md),
            border: Border.all(
              color: isPaid
                  ? const Color(0xFF9AE6B4)
                  : const Color(0xFFFDE68A),
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#$shortId',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: PosColors.primary)),
                  const SizedBox(height: 4),
                  Text(date,
                      style: const TextStyle(
                          fontSize: 12, color: PosColors.textMuted)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _Tag(method == 'Cash' ? 'Tunai' : method,
                        PosColors.infoBg, PosColors.info),
                    const SizedBox(width: 6),
                    _Tag(status,
                        isPaid ? PosColors.successBg : PosColors.warningBg,
                        isPaid ? PosColors.success   : PosColors.warning),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatRp(total),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800,
                        color: PosColors.primary)),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.copy_rounded,
                  size: 16, color: PosColors.textMuted),
              onPressed: () => _copy(
                  '#$shortId\t$date\t${_formatRp(total)}\t$method'),
              tooltip: 'Copy baris',
            ),
          ]),
        );
      },
    );
  }

  // ── Tab: Order Items ──────────────────────────────────────
  Widget _buildItemsTab(double pad) {
    if (_items.isEmpty) {
      return _emptyState('Belum ada detail item transaksi');
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item     = _items[i];
        final orderId  = (item['order_id'] as String? ?? '');
        final shortOrd = orderId.length >= 8
            ? orderId.substring(0, 8).toUpperCase()
            : orderId.toUpperCase();
        final name     = item['product_name'] as String? ?? 'Produk Dihapus';
        final qty      = item['quantity'] as int? ?? 0;
        final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
        final date     = _shortDate(item['order_date'] as String?);
        final method   = item['payment_method'] as String? ?? '-';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: posCardDecoration(withShadow: false),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: PosColors.textPrimary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _Tag('Order #$shortOrd',
                        PosColors.primaryBg, PosColors.primary),
                    const SizedBox(width: 6),
                    _Tag(method == 'Cash' ? 'Tunai' : method,
                        PosColors.infoBg, PosColors.info),
                  ]),
                  const SizedBox(height: 4),
                  Text(date,
                      style: const TextStyle(
                          fontSize: 11, color: PosColors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('x$qty',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: PosColors.textSecondary)),
                const SizedBox(height: 4),
                Text(_formatRp(subtotal),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: PosColors.primary)),
              ],
            ),
          ]),
        );
      },
    );
  }

  // ── Tab: Users ────────────────────────────────────────────
  Widget _buildUsersTab(double pad) {
    if (_users.isEmpty) return _emptyState('Belum ada user');

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final u       = _users[i];
        final username = u['username'] as String? ?? '-';
        final role    = u['role']     as String? ?? '-';
        final created = _shortDate(u['created_at'] as String?);
        final isAdmin = role == 'admin';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: posCardDecoration(),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isAdmin
                    ? PosColors.primaryBg
                    : PosColors.successBg,
                borderRadius: BorderRadius.circular(PosRadius.md),
              ),
              child: Icon(
                isAdmin
                    ? Icons.admin_panel_settings_rounded
                    : Icons.point_of_sale_rounded,
                color: isAdmin ? PosColors.primary : PosColors.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(username,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: PosColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Dibuat: $created',
                      style: const TextStyle(
                          fontSize: 11, color: PosColors.textMuted)),
                ],
              ),
            ),
            _Tag(
              role.toUpperCase(),
              isAdmin ? PosColors.primaryBg : PosColors.successBg,
              isAdmin ? PosColors.primary   : PosColors.success,
            ),
          ]),
        );
      },
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded,
              size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg,
              style: const TextStyle(
                  fontSize: 14, color: PosColors.textMuted)),
        ],
      ),
    );
  }
}

// ── Small widgets ─────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String text;
  final Color  bg;
  final Color  fg;
  const _Tag(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(PosRadius.xxl),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _DbStat {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  const _DbStat(this.label, this.value, this.icon, this.color);
}