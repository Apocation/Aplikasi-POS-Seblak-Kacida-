import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/data_notifier.dart';
import '../../core/utils/responsive.dart';

// ============================================================

//  TRANSAKSI PAGE
//  Riwayat transaksi — expandable card + search + struk dialog
// ============================================================

class TransaksiPage extends StatefulWidget {
  const TransaksiPage({super.key});

  @override
  State<TransaksiPage> createState() => _TransaksiPageState();
}

class _TransaksiPageState extends State<TransaksiPage> with DataRefreshMixin {

  List<Map<String, dynamic>> _orders      = [];

  bool                       _loading     = true;
  String                     _search      = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper.instance.getOrders();
    if (!mounted) return;
    setState(() {
      _orders  = data;
      _loading = false;
    });
  }

  // ── Helpers ───────────────────────────────────────────────
  String _formatRp(dynamic val) {
    final d = (val as num?)?.toDouble() ?? 0.0;
    return 'Rp ${d.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        )}';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt     = DateTime.parse(iso).toLocal();
      final months = ['Jan','Feb','Mar','Apr','Mei','Jun',
                      'Jul','Agt','Sep','Okt','Nov','Des'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $h.$m';
    } catch (_) {
      return iso.length > 16 ? iso.substring(0, 16) : iso;
    }
  }

  // Format invoice: ORD-20260411-001
  String _invoiceNo(Map<String, dynamic> order) {
    final id  = order['id'] as String? ?? '';
    final iso = order['created_at'] as String? ?? '';
    String datePart = '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      datePart =
          '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      datePart = '00000000';
    }
    final suffix = id.length >= 4
        ? id.substring(id.length - 4).toUpperCase()
        : id.toUpperCase();
    return 'ORD-$datePart-$suffix';
  }

  // ── Filter ────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    if (_search.trim().isEmpty) return _orders;
    final q = _search.toLowerCase();
    return _orders.where((o) {
      final invoice = _invoiceNo(o).toLowerCase();
      final method  = (o['payment_method'] as String? ?? '').toLowerCase();
      final date    = (o['created_at'] as String? ?? '').toLowerCase();
      return invoice.contains(q) || method.contains(q) || date.contains(q);
    }).toList();
  }

  // ── Summary stats ─────────────────────────────────────────
  double get _totalOmzet =>
      _orders.fold(0.0, (s, o) => s + ((o['total_price'] as num?)?.toDouble() ?? 0.0));

  // ============================================================
  //  BUILD
  // ============================================================
@override
  void onDataChanged() => _load();

  @override
  Widget build(BuildContext context) {

    final isMobile  = Responsive.isMobile(context);

    final pad       = isMobile ? 16.0 : 24.0;
    final filtered  = _filtered;

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: PosColors.primary,
          onRefresh: _load,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: PosColors.primary))
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(isMobile),
                            const SizedBox(height: 16),
                            _buildSummaryRow(isMobile),
                            const SizedBox(height: 16),
                            _buildSearch(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // List transaksi
                    filtered.isEmpty
                        ? SliverFillRemaining(
                            child: _emptyState(),
                          )
                        : SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                                pad, 0, pad, 32),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 12),
                                  child: _TransaksiCard(
                                    order:      filtered[i],
                                    invoiceNo:  _invoiceNo(filtered[i]),
                                    formatRp:   _formatRp,
                                    formatDate: _formatDate,
                                  ),
                                ),
                                childCount: filtered.length,
                              ),
                            ),
                          ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('📋 ', style: TextStyle(fontSize: 22)),
                  Text(
                    'Riwayat Transaksi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: PosColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _IconBtn(
          icon:    Icons.refresh_rounded,
          onTap:   _load,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  // ── Summary Row ───────────────────────────────────────────
  Widget _buildSummaryRow(bool isMobile) {
    final tunai = _orders
        .where((o) => o['payment_method'] == 'Cash')
        .length;
    final qris  = _orders
        .where((o) => o['payment_method'] == 'QRIS')
        .length;

    final cards = [
      _SummaryData(
        label:  'Total Transaksi',
        value:  '${_orders.length}',
        icon:   Icons.receipt_long_rounded,
        color:  PosColors.info,
        bgColor: PosColors.infoBg,
      ),
      _SummaryData(
        label:  'Total Omzet',
        value:  _formatRp(_totalOmzet),
        icon:   Icons.attach_money_rounded,
        color:  PosColors.success,
        bgColor: PosColors.successBg,
      ),
      _SummaryData(
        label:  'Tunai',
        value:  '$tunai transaksi',
        icon:   Icons.payments_rounded,
        color:  PosColors.warning,
        bgColor: PosColors.warningBg,
      ),
      _SummaryData(
        label:  'QRIS',
        value:  '$qris transaksi',
        icon:   Icons.qr_code_rounded,
        color:  PosColors.primary,
        bgColor: PosColors.primaryBg,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          Row(children: [
            Expanded(child: _SummaryCard(data: cards[0])),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(data: cards[1])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _SummaryCard(data: cards[2])),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(data: cards[3])),
          ]),
        ],
      );
    }

    return Row(
      children: cards.asMap().entries.map((e) {
        final isLast = e.key == cards.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 12),
            child: _SummaryCard(data: e.value),
          ),
        );
      }).toList(),
    );
  }

  // ── Search ────────────────────────────────────────────────
  Widget _buildSearch() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _search = v),
      decoration: InputDecoration(
        hintText: 'Cari nama pemesan atau nomor order...',
        prefixIcon: const Icon(Icons.search_rounded,
            size: 20, color: PosColors.textMuted),
        suffixIcon: _search.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: PosColors.textMuted),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _search = '');
                },
              )
            : null,
        fillColor: PosColors.surface,
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadius.md),
          borderSide: const BorderSide(color: PosColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadius.md),
          borderSide: const BorderSide(color: PosColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadius.md),
          borderSide:
              const BorderSide(color: PosColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _search.isNotEmpty
                ? 'Tidak ada transaksi ditemukan'
                : 'Belum ada transaksi',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: PosColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  TRANSAKSI CARD — Expandable
// ============================================================

class _TransaksiCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final String               invoiceNo;
  final String Function(dynamic) formatRp;
  final String Function(String?) formatDate;

  const _TransaksiCard({
    required this.order,
    required this.invoiceNo,
    required this.formatRp,
    required this.formatDate,
  });

  @override
  State<_TransaksiCard> createState() => _TransaksiCardState();
}

class _TransaksiCardState extends State<_TransaksiCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  List<Map<String, dynamic>> _items = [];
  bool _loadingItems = false;
  late AnimationController _animCtrl;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200));
    _rotateAnim = Tween<double>(begin: 0, end: 0.5)
        .animate(CurvedAnimation(
            parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!_expanded) {
      // Load items saat pertama expand
      if (_items.isEmpty) {
        setState(() => _loadingItems = true);
        final orderId = widget.order['id'] as String;
        final rawItems =
            await DatabaseHelper.instance.getOrderItems(orderId);
        // Ambil nama produk
        final enriched = <Map<String, dynamic>>[];
        for (final item in rawItems) {
          final prodId  = item['product_id'] as String?;
          final produk  = prodId != null
              ? await DatabaseHelper.instance.getProductById(prodId)
              : null;
          enriched.add({
            ...item,
            'name':      produk?['name']      ?? 'Produk Dihapus',
            'image_url': produk?['image_url'] ?? '',
          });
        }
        if (!mounted) return;
        setState(() {
          _items        = enriched;
          _loadingItems = false;
        });
      }
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
    setState(() => _expanded = !_expanded);
  }

  void _lihatStruk() {
    showDialog(
      context: context,
      builder: (_) => _StrukDialog(
        invoiceNo: widget.invoiceNo,
        order:     widget.order,
        items:     _items,
        formatRp:  widget.formatRp,
        formatDate: widget.formatDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order   = widget.order;
    final method  = order['payment_method'] as String? ?? '-';
    final total   = (order['total_price'] as num?)?.toDouble() ?? 0.0;
    final dateStr = widget.formatDate(order['created_at'] as String?);

    // Label metode
    final methodLabel = method == 'Cash' ? 'Tunai' : method;

    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadius.lg),
        border: Border.all(color: PosColors.border, width: 1),
        boxShadow: const [PosShadows.card],
      ),
      child: Column(

        children: [
          // ── Header row (selalu tampil) ──────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(PosRadius.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kiri: invoice + pemesan + tanggal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.invoiceNo,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: PosColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _MethodBadge(method: methodLabel),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pelanggan',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: PosColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: PosColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Kanan: total + chevron
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.formatRp(total),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: PosColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RotationTransition(
                        turns: _rotateAnim,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: PosColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded content ────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _expandedContent(total, methodLabel),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }

  Widget _expandedContent(double total, String methodLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: const Text(
            'ITEM PESANAN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: PosColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Items
        if (_loadingItems)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: PosColors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
          )
        else
          ..._items.map((item) => _ItemRow(
                item:    item,
                formatRp: widget.formatRp,
              )),

        const Divider(height: 1),

        // Summary
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              _SummaryRow(
                  label: 'Subtotal',
                  value: widget.formatRp(total)),
              const SizedBox(height: 6),
              _SummaryRow(
                label: 'Total',
                value: widget.formatRp(total),
                bold:  true,
              ),
              const SizedBox(height: 6),
              _SummaryRow(
                  label: 'Bayar',
                  value: widget.formatRp(total),
                  muted: true),
            ],
          ),
        ),

        const Divider(height: 1),

        // Buttons
        Padding(
          padding:
              const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _lihatStruk,
                icon:  const Icon(Icons.print_rounded, size: 16),
                label: const Text('Print Struk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PosColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 11),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _lihatStruk,
                icon:  const Icon(Icons.visibility_rounded, size: 16),
                label: const Text('Lihat Struk'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PosColors.textSecondary,
                  side: const BorderSide(color: PosColors.border),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 11),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
//  ITEM ROW (dalam expanded)
// ============================================================

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(dynamic) formatRp;

  const _ItemRow({required this.item, required this.formatRp});

  @override
  Widget build(BuildContext context) {
    final name     = item['name'] as String? ?? 'Produk';
    final qty      = item['quantity'] as int? ?? 0;
    final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = item['image_url'] as String? ?? '';

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          // Gambar kecil
          ClipRRect(
            borderRadius: BorderRadius.circular(PosRadius.sm),
            child: imageUrl.isNotEmpty
                ? Image.asset(
                    imageUrl,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$name x$qty',
              style: const TextStyle(
                fontSize: 13,
                color: PosColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            formatRp(subtotal),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PosColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: PosColors.surfaceAlt,
        borderRadius: BorderRadius.circular(PosRadius.sm),
      ),
      child: const Icon(Icons.fastfood_rounded,
          size: 14, color: PosColors.textMuted),
    );
  }
}

// ============================================================
//  STRUK DIALOG
// ============================================================

class _StrukDialog extends StatelessWidget {
  final String                   invoiceNo;
  final Map<String, dynamic>     order;
  final List<Map<String, dynamic>> items;
  final String Function(dynamic) formatRp;
  final String Function(String?) formatDate;

  const _StrukDialog({
    required this.invoiceNo,
    required this.order,
    required this.items,
    required this.formatRp,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final total  = (order['total_price'] as num?)?.toDouble() ?? 0.0;
    final method = order['payment_method'] as String? ?? '-';
    final methodLabel = method == 'Cash' ? 'Tunai' : method;
    final date   = formatDate(order['created_at'] as String?);

    return Dialog(
      backgroundColor: PosColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadius.xl)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              const Text(
                'SEBLAK KACIDA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: PosColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: const TextStyle(
                    fontSize: 12, color: PosColors.textMuted),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Invoice info
              _InfoRow('No. Order', invoiceNo, bold: true),
              const SizedBox(height: 6),
              _InfoRow('Metode', methodLabel),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Items
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Tidak ada data item',
                      style: TextStyle(color: PosColors.textMuted)),
                )
              else
                ...items.map((item) {
                  final name     = item['name'] as String? ?? 'Produk';
                  final qty      = item['quantity'] as int? ?? 0;
                  final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
                  final price    = qty > 0 ? subtotal / qty : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$name x$qty',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: PosColors.textPrimary,
                                ),
                              ),
                              Text(
                                formatRp(price),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: PosColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatRp(subtotal),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: PosColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),

              // Total
              _InfoRow('Subtotal', formatRp(total)),
              const SizedBox(height: 6),
              _InfoRow('Total', formatRp(total),
                  bold: true, valueColor: PosColors.primary),
              const SizedBox(height: 6),
              _InfoRow('Bayar ($methodLabel)', formatRp(total)),

              const SizedBox(height: 20),
              const Text(
                'Terima kasih sudah mampir! 🌶️',
                style: TextStyle(
                    fontSize: 13, color: PosColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _InfoRow(this.label, this.value,
      {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: PosColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? PosColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ============================================================
//  SMALL WIDGETS
// ============================================================

class _MethodBadge extends StatelessWidget {
  final String method;
  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final isQris = method == 'QRIS';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isQris ? PosColors.infoBg : PosColors.successBg,
        borderRadius: BorderRadius.circular(PosRadius.xxl),
        border: Border.all(
          color: isQris
              ? const Color(0xFF90CDF4)
              : const Color(0xFF9AE6B4),
        ),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isQris ? PosColors.info : PosColors.success,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   bold;
  final bool   muted;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold  = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: muted
                ? PosColors.textMuted
                : bold
                    ? PosColors.textPrimary
                    : PosColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: muted
                ? PosColors.textMuted
                : bold
                    ? PosColors.textPrimary
                    : PosColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Summary Card ───────────────────────────────────────────
class _SummaryData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _SummaryData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

class _SummaryCard extends StatelessWidget {
  final _SummaryData data;
  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: posCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.bgColor,
              borderRadius: BorderRadius.circular(PosRadius.md),
            ),
            child: Icon(data.icon, color: data.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: PosColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: data.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Icon button ────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _IconBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosRadius.md),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadius.md),
            border: Border.all(color: PosColors.border),
          ),
          child: Icon(icon, size: 18, color: PosColors.textSecondary),
        ),
      ),
    );
  }
}