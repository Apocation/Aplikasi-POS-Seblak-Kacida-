import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/data_notifier.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage>
    with DataRefreshMixin {

  String   _range        = 'Harian';
  bool     _loading      = true;
  bool     _chartLoading = false;

  List<Map<String, dynamic>> _orders    = [];
  List<Map<String, dynamic>> _chartData = [];
  List<Map<String, dynamic>> _topItems  = [];

  static const _ranges = ['Harian', 'Mingguan', 'Bulanan'];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // DataRefreshMixin
  @override
  void onDataChanged() => _loadAll();

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _fetchOrders(),
      _fetchChart(_range),
      _fetchTop(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchOrders() async {
    final data = await DatabaseHelper.instance.getOrders();
    if (mounted) setState(() => _orders = data);
  }

  Future<void> _fetchChart(String range) async {
    final data = await DatabaseHelper.instance.getSalesChartData(range);
    if (mounted) setState(() => _chartData = data);
  }

  Future<void> _fetchTop() async {
    final data = await DatabaseHelper.instance
        .getTopSellingProducts(limit: 10);
    if (mounted) setState(() => _topItems = data);
  }

  Future<void> _changeRange(String range) async {
    if (_range == range) return;
    setState(() { _range = range; _chartLoading = true; });
    await _fetchChart(range);
    if (mounted) setState(() => _chartLoading = false);
  }

  String _formatRp(dynamic val) {
    final d = (val as num?)?.toDouble() ?? 0.0;
    return 'Rp ${d.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
  }

  String _formatRpShort(double val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}jt';
    if (val >= 1000)    return '${(val / 1000).toStringAsFixed(0)}k';
    return val.toStringAsFixed(0);
  }

  String _shortLabel(String raw) {
    try {
      if (raw.length == 10 && raw.contains('-')) {
        final p = raw.split('-');
        return '${p[2]}/${p[1]}';
      }
      if (raw.length == 7 && raw.contains('-')) {
        final months = ['','Jan','Feb','Mar','Apr','Mei','Jun',
                        'Jul','Agt','Sep','Okt','Nov','Des'];
        final m = int.tryParse(raw.split('-')[1]) ?? 0;
        return m > 0 && m <= 12 ? months[m] : raw.substring(5);
      }
      return raw.length > 8 ? raw.substring(raw.length - 5) : raw;
    } catch (_) { return raw; }
  }

  double get _totalOmzet => _orders.fold(0.0,
      (s, o) => s + ((o['total_price'] as num?)?.toDouble() ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final pad      = isMobile ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color:     PosColors.primary,
          onRefresh: _loadAll,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: PosColors.primary))
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(pad, 20, pad, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isMobile),
                      const SizedBox(height: 20),
                      _buildSummaryCards(isMobile),
                      const SizedBox(height: 20),
                      _buildRangeTabs(),
                      const SizedBox(height: 16),
                      _buildChart(isMobile),
                      const SizedBox(height: 20),
                      _buildTopItems(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Text('📈 ', style: TextStyle(fontSize: 22)),
                Text('Laporan Penjualan',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: PosColors.textPrimary,
                        letterSpacing: -0.4)),
              ]),
              const SizedBox(height: 4),
              Text(
                'Total: ${_formatRp(_totalOmzet)} dari ${_orders.length} transaksi',
                style: const TextStyle(
                    fontSize: 13, color: PosColors.textSecondary),
              ),
            ],
          ),
        ),
        _IconBtn(icon: Icons.refresh_rounded, onTap: _loadAll),
      ],
    );
  }

  Widget _buildSummaryCards(bool isMobile) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayOrders = _orders.where((o) =>
        (o['created_at'] as String? ?? '').startsWith(today)).toList();
    final todayOmzet  = todayOrders.fold<double>(
        0.0, (s, o) => s + ((o['total_price'] as num?)?.toDouble() ?? 0.0));
    final avg = _orders.isNotEmpty ? _totalOmzet / _orders.length : 0.0;

    final cards = [
      _CardData('Omzet Hari Ini', _formatRp(todayOmzet),
          Icons.today_rounded, PosColors.primary, PosColors.primaryBg),
      _CardData('Total Omzet', _formatRp(_totalOmzet),
          Icons.attach_money_rounded, PosColors.success, PosColors.successBg),
      _CardData('Total Transaksi', '${_orders.length}',
          Icons.receipt_long_rounded, PosColors.info, PosColors.infoBg),
      _CardData('Rata-rata / Trx', _formatRp(avg),
          Icons.trending_up_rounded, PosColors.warning, PosColors.warningBg),
    ];

    if (isMobile) {
      return Column(children: [
        Row(children: [
          Expanded(child: _SmallCard(data: cards[0])),
          const SizedBox(width: 12),
          Expanded(child: _SmallCard(data: cards[1])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _SmallCard(data: cards[2])),
          const SizedBox(width: 12),
          Expanded(child: _SmallCard(data: cards[3])),
        ]),
      ]);
    }

    return Row(
      children: cards.asMap().entries.map((e) {
        final isLast = e.key == cards.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 14),
            child: _SmallCard(data: e.value),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRangeTabs() {
    return Row(
      children: _ranges.map((r) {
        final sel = _range == r;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => _changeRange(r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? PosColors.primary : PosColors.surface,
                borderRadius: BorderRadius.circular(PosRadius.xxl),
                border: Border.all(
                    color: sel ? PosColors.primary : PosColors.border,
                    width: 1.5),
                boxShadow: sel
                    ? [BoxShadow(
                        color: PosColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8, offset: const Offset(0, 3))]
                    : null,
              ),
              child: Text(r,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : PosColors.textSecondary)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChart(bool isMobile) {
    return Container(
      decoration: posCardDecoration(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Grafik Penjualan',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: PosColors.textPrimary)),
          const SizedBox(height: 20),
          SizedBox(
            height: isMobile ? 200 : 260,
            child: _chartLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: PosColors.primary))
                : _chartData.isEmpty
                    ? _emptyChart()
                    : _barChart(isMobile),
          ),
        ],
      ),
    );
  }

  Widget _emptyChart() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Belum ada data penjualan',
                style: TextStyle(fontSize: 13, color: PosColors.textMuted)),
          ],
        ),
      );

  Widget _barChart(bool isMobile) {
    final data   = _chartData.reversed.toList();
    final maxVal = data.fold<double>(0, (m, e) {
      final v = (e['total'] as num?)?.toDouble() ?? 0.0;
      return v > m ? v : m;
    });
    final yMax = maxVal == 0 ? 10000.0 : maxVal * 1.25;

    double yInterval(double max) {
      if (max <= 10000)   return 2500;
      if (max <= 50000)   return 10000;
      if (max <= 200000)  return 50000;
      if (max <= 1000000) return 200000;
      return (max / 5).ceilToDouble();
    }

    final interval = yInterval(yMax);

    return BarChart(
      BarChartData(
        maxY: yMax,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => PosColors.sidebarBg,
            tooltipRoundedRadius: PosRadius.md,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItem: (group, _, rod, __) {
              final label =
                  _shortLabel(data[group.x]['label'] as String? ?? '');
              return BarTooltipItem(
                '$label\n',
                const TextStyle(color: Colors.white60, fontSize: 11),
                children: [
                  TextSpan(
                    text: _formatRp(rod.toY),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles:   true,
              reservedSize: isMobile ? 42 : 52,
              interval:     interval,
              getTitlesWidget: (val, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(_formatRpShort(val),
                    style: const TextStyle(
                        fontSize: 10, color: PosColors.textMuted,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.right),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles:   true,
              reservedSize: 28,
              getTitlesWidget: (val, _) {
                final i = val.toInt();
                if (i < 0 || i >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      _shortLabel(data[i]['label'] as String? ?? ''),
                      style: const TextStyle(
                          fontSize: 10, color: PosColors.textMuted,
                          fontWeight: FontWeight.w500)),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => const FlLine(
              color: PosColors.border, strokeWidth: 1,
              dashArray: [4, 4]),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: PosColors.border, width: 1),
            left:   BorderSide(color: PosColors.border, width: 1),
          ),
        ),
        barGroups: List.generate(data.length, (i) {
          final val   = (data[i]['total'] as num?)?.toDouble() ?? 0.0;
          final width = isMobile
              ? (200 / data.length).clamp(8, 28).toDouble()
              : (320 / data.length).clamp(12, 48).toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY:   val,
                color: PosColors.primary,
                width: width,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                    show:  true,
                    toY:   yMax,
                    color: PosColors.primaryBg),
              ),
            ],
          );
        }),
      ),
      swapAnimationDuration: const Duration(milliseconds: 400),
      swapAnimationCurve:    Curves.easeOut,
    );
  }

  Widget _buildTopItems() {
    return Container(
      decoration: posCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(children: [
              Text('🏆 ', style: TextStyle(fontSize: 18)),
              Text('Item Terlaris (Semua Waktu)',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: PosColors.textPrimary)),
            ]),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 11),
            color: PosColors.surfaceAlt,
            child: const Row(children: [
              SizedBox(width: 32,
                  child: Text('#', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: PosColors.textMuted))),
              Expanded(flex: 3, child: Text('Item', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: PosColors.textMuted))),
              SizedBox(width: 80, child: Text('Terjual',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: PosColors.textMuted))),
              SizedBox(width: 110, child: Text('Pendapatan',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: PosColors.textMuted))),
            ]),
          ),
          const Divider(height: 1),
          _topItems.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('Belum ada data item terlaris',
                        style: TextStyle(
                            fontSize: 13, color: PosColors.textMuted)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _topItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final row = _topItems[i];
                    return _TopItemTableRow(
                      rank:       i + 1,
                      name:       row['item'] as String? ?? '-',
                      terjual:    (row['terjual'] as num?)?.toInt() ?? 0,
                      pendapatan: _formatRp(row['pendapatan']),
                    );
                  },
                ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────

class _CardData {
  final String label, value;
  final IconData icon;
  final Color color, bgColor;
  const _CardData(this.label, this.value, this.icon,
      this.color, this.bgColor);
}

class _SmallCard extends StatelessWidget {
  final _CardData data;
  const _SmallCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: posCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color:        data.bgColor,
              borderRadius: BorderRadius.circular(PosRadius.md),
            ),
            child: Icon(data.icon, color: data.color, size: 17),
          ),
          const SizedBox(height: 12),
          Text(data.label,
              style: const TextStyle(
                  fontSize: 11, color: PosColors.textMuted,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(data.value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: data.color, letterSpacing: -0.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _TopItemTableRow extends StatelessWidget {
  final int    rank;
  final String name;
  final int    terjual;
  final String pendapatan;
  const _TopItemTableRow({
    required this.rank,
    required this.name,
    required this.terjual,
    required this.pendapatan,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3   = rank <= 3;
    final rankColor = rank == 1
        ? const Color(0xFFD69E2E)
        : rank == 2
            ? const Color(0xFF718096)
            : rank == 3
                ? const Color(0xFFB7791F)
                : PosColors.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 13),
      child: Row(
        children: [
          SizedBox(width: 32,
            child: Text('$rank',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: isTop3 ? rankColor : PosColors.textMuted))),
          Expanded(flex: 3,
            child: Text(name,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: PosColors.textPrimary))),
          SizedBox(width: 80,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        PosColors.primaryBg,
                  borderRadius: BorderRadius.circular(PosRadius.xxl),
                ),
                child: Text('${terjual}x',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: PosColors.primary)),
              ),
            )),
          SizedBox(width: 110,
            child: Text(pendapatan,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: PosColors.textPrimary))),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
    );
  }
}