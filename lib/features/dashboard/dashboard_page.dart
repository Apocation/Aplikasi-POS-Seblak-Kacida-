import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/data_notifier.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with DataRefreshMixin {

  Map<String, dynamic>       _stats       = {};
  List<Map<String, dynamic>> _topItems    = [];
  List<Map<String, dynamic>> _lowStock    = [];
  List<Map<String, dynamic>> _recentOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // DataRefreshMixin — reload saat ada perubahan DB
  @override
  void onDataChanged() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final results = await Future.wait([
      DatabaseHelper.instance.getDashboardStats(),
      DatabaseHelper.instance.getTopSellingProductsToday(),
      DatabaseHelper.instance.getLowStockProducts(),
      DatabaseHelper.instance.getRecentOrders(limit: 5),
    ]);

    if (!mounted) return;
    setState(() {
      _stats        = results[0] as Map<String, dynamic>;
      _topItems     = results[1] as List<Map<String, dynamic>>;
      _lowStock     = results[2] as List<Map<String, dynamic>>;
      _recentOrders = results[3] as List<Map<String, dynamic>>;
      _loading      = false;
    });
  }

  String _formatRp(dynamic val) {
    final d = (val as num?)?.toDouble() ?? 0.0;
    return 'Rp ${d.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
  }

  String _formatTime(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}'
          '.${dt.minute.toString().padLeft(2,'0')}'
          '.${dt.second.toString().padLeft(2,'0')}';
    } catch (_) {
      return iso.length > 19 ? iso.substring(11, 19) : iso;
    }
  }

  String _shortId(String? id) {
    if (id == null || id.length < 8) return id ?? '-';
    return '#${id.substring(0, 8).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color:     PosColors.primary,
          onRefresh: _load,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: PosColors.primary))
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(
                      isMobile ? PosSpacing.md : PosSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      SizedBox(height: isMobile ? 20 : 24),
                      _buildStatCards(isMobile),
                      const SizedBox(height: 20),
                      _buildMidRow(isMobile),
                      const SizedBox(height: 20),
                      _buildRecentTransaksi(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now    = DateTime.now();
    final days   = ['Minggu','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'];
    final months = ['Jan','Feb','Mar','Apr','Mei','Jun',
                    'Jul','Agt','Sep','Okt','Nov','Des'];
    final dateStr =
        '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dashboard',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800,
                      color: PosColors.textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 13, color: PosColors.textSecondary,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        _IconBtn(icon: Icons.refresh_rounded, onTap: _load, tooltip: 'Refresh'),
      ],
    );
  }

  Widget _buildStatCards(bool isMobile) {
    final avg = (_stats['todayOrders'] ?? 0) > 0
        ? ((_stats['todayRevenue'] ?? 0.0) / (_stats['todayOrders'] as int))
        : 0.0;

    final cards = [
      _StatData('Pendapatan Hari Ini', _formatRp(_stats['todayRevenue']),
          Icons.attach_money_rounded, PosColors.primary, PosColors.primaryBg),
      _StatData('Transaksi Hari Ini', '${_stats['todayOrders'] ?? 0}',
          Icons.shopping_bag_rounded, PosColors.info, PosColors.infoBg),
      _StatData('Rata-rata per Transaksi', _formatRp(avg),
          Icons.trending_up_rounded, PosColors.textPrimary, PosColors.surfaceAlt),
      _StatData('Stok Rendah', '${_stats['lowStockProducts'] ?? 0}',
          Icons.warning_amber_rounded, PosColors.warning, PosColors.warningBg),
    ];

    if (isMobile) {
      return Column(children: [
        Row(children: [
          Expanded(child: _StatCard(data: cards[0])),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(data: cards[1])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(data: cards[2])),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(data: cards[3])),
        ]),
      ]);
    }

    return Row(
      children: cards.asMap().entries.map((e) {
        final isLast = e.key == cards.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 14),
            child: _StatCard(data: e.value),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMidRow(bool isMobile) {
    if (isMobile) {
      return Column(children: [
        _buildTopItems(),
        const SizedBox(height: 16),
        _buildLowStock(),
      ]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildTopItems()),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: _buildLowStock()),
      ],
    );
  }

  Widget _buildTopItems() {
    return _Panel(
      icon:  '🔥',
      title: 'Item Terlaris Hari Ini',
      child: _topItems.isEmpty
          ? _empty('Belum ada transaksi hari ini')
          : Column(
              children: _topItems.map((item) => _TopItemRow(
                    name: item['item'] as String? ?? '-',
                    qty:  '${item['terjual']} x',
                  )).toList(),
            ),
    );
  }

  Widget _buildLowStock() {
    return _Panel(
      icon:  '⚠️',
      title: 'Stok Hampir Habis',
      child: _lowStock.isEmpty
          ? _empty('Semua stok aman')
          : Column(
              children: _lowStock.map((item) => _LowStockRow(
                    name:     item['name'] as String? ?? '-',
                    stock:    item['stock'] as int? ?? 0,
                    imageUrl: item['image_url'] as String? ?? '',
                  )).toList(),
            ),
    );
  }

  Widget _buildRecentTransaksi() {
    return _Panel(
      icon:  '🕐',
      title: 'Transaksi Terakhir',
      child: _recentOrders.isEmpty
          ? _empty('Belum ada transaksi')
          : Column(
              children: _recentOrders.map((order) => _RecentOrderRow(
                    orderId: _shortId(order['id'] as String?),
                    time:    '${_formatTime(order['created_at'] as String?)} • ${order['item_count'] ?? 0} item',
                    method:  order['payment_method'] as String? ?? '-',
                    total:   _formatRp(order['total_price']),
                  )).toList(),
            ),
    );
  }

  Widget _empty(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(msg,
              style: const TextStyle(
                  color: PosColors.textMuted, fontSize: 13)),
        ),
      );
}

// ── Data model ────────────────────────────────────────────

class _StatData {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  final Color    bgColor;
  const _StatData(this.label, this.value, this.icon,
      this.color, this.bgColor);
}

// ── Widgets ───────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: posCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        data.bgColor,
              borderRadius: BorderRadius.circular(PosRadius.md),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(data.label,
              style: const TextStyle(
                  fontSize: 12, color: PosColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(data.value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: data.color, letterSpacing: -0.5)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String icon;
  final String title;
  final Widget child;
  const _Panel(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: posCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: PosColors.textPrimary)),
            ]),
          ),
          const Divider(height: 1),
          Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
              child: child),
        ],
      ),
    );
  }
}

class _TopItemRow extends StatelessWidget {
  final String name;
  final String qty;
  const _TopItemRow({required this.name, required this.qty});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color:        PosColors.surfaceAlt,
              borderRadius: BorderRadius.circular(PosRadius.md),
            ),
            child: const Icon(Icons.fastfood_rounded,
                size: 18, color: PosColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500,
                    color: PosColors.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        PosColors.primaryBg,
              borderRadius: BorderRadius.circular(PosRadius.xxl),
            ),
            child: Text(qty,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: PosColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  final String name;
  final int    stock;
  final String imageUrl;
  const _LowStockRow(
      {required this.name, required this.stock, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        PosColors.warningBg,
        borderRadius: BorderRadius.circular(PosRadius.md),
        border:       Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(PosRadius.sm),
            child: imageUrl.isNotEmpty
                ? Image.asset(imageUrl,
                    width: 32, height: 32, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: PosColors.textPrimary)),
          ),
          Text('Sisa $stock',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: PosColors.warning)),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color:        const Color(0xFFFDE68A),
          borderRadius: BorderRadius.circular(PosRadius.sm),
        ),
        child: const Icon(Icons.fastfood_rounded,
            size: 16, color: PosColors.warning),
      );
}

class _RecentOrderRow extends StatelessWidget {
  final String orderId;
  final String time;
  final String method;
  final String total;
  const _RecentOrderRow({
    required this.orderId,
    required this.time,
    required this.method,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(orderId,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: PosColors.primary)),
                const SizedBox(height: 3),
                Text(time,
                    style: const TextStyle(
                        fontSize: 12, color: PosColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(total,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: PosColors.primary)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:        PosColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(PosRadius.xxl),
                ),
                child: Text(method,
                    style: const TextStyle(
                        fontSize: 11, color: PosColors.textSecondary,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _IconBtn(
      {required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(PosRadius.md),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:        PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadius.md),
            border:       Border.all(color: PosColors.border),
          ),
          child: Icon(icon, size: 18, color: PosColors.textSecondary),
        ),
      ),
    );
  }
}