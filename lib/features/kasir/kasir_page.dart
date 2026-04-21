import 'dart:io';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/data_notifier.dart';
import '../../core/services/printer_service.dart';

class KasirPage extends StatefulWidget {
  const KasirPage({super.key});

  @override
  State<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> with DataRefreshMixin {
  String _kategori    = 'Base Seblak';
  String _namaPemesan = '';
  String _catatan     = '';
  final List<Map<String, dynamic>> _cart = [];
  List<Map<String, dynamic>> _produkList = [];
  bool _loadingProduk = true;

  // Printer related
  bool _isPrinterConnected  = false;
  String? _connectedPrinterName;
  bool _isPrinting = false;

  static const List<Map<String, String>> _categories = [
    {'label': 'Base Seblak', 'db': 'Base',   'emoji': '🍜'},
    {'label': 'Topping',     'db': 'Topping', 'emoji': '🥩'},
    {'label': 'Sayur',       'db': 'Sayur',   'emoji': '🥬'},
    {'label': 'Level Pedas', 'db': 'Pedas',   'emoji': '🌶️'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProduk();
    _checkPrinterStatus();
  }

  // Cek status koneksi printer saat halaman dibuka
  Future<void> _checkPrinterStatus() async {
    final connected = await PrinterService.checkConnection();
    if (mounted) {
      setState(() {
        _isPrinterConnected   = connected;
        _connectedPrinterName = PrinterService.connectedPrinter;
      });
    }
  }

  // Tampilkan dialog pilih printer & konek
  Future<void> _connectToPrinter() async {
    // Kalau sudah konek, tawarkan disconnect
    if (_isPrinterConnected) {
      final shouldDisconnect = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Printer Terhubung'),
          content: Text(
              'Sedang terhubung ke ${_connectedPrinterName ?? "Printer"}.\nPutuskan koneksi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tidak'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: PosColors.error),
              child: const Text('Putuskan'),
            ),
          ],
        ),
      );
      if (shouldDisconnect == true) {
        await PrinterService.disconnect();
        if (mounted) {
          setState(() {
            _isPrinterConnected   = false;
            _connectedPrinterName = null;
          });
        }
      }
      return;
    }

    // Ambil daftar printer yang sudah di-pair
    final devices = await PrinterService.getBondedDevices();

    if (devices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Tidak ada printer Bluetooth yang di-pair. Silakan pair dulu di pengaturan HP.'),
            backgroundColor: PosColors.error,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Printer Bluetooth'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              // devices adalah List<Map<String, dynamic>>
              // dengan key 'name' dan 'address'
              final device = devices[index];
              final name    = device['name'] as String? ?? 'Unknown';
              final address = device['address'] as String? ?? '';

              return ListTile(
                leading: const Icon(Icons.print),
                title:    Text(name),
                subtitle: Text(address),
                onTap: () async {
                  Navigator.pop(context);

                  // Tampilkan loading
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Menghubungkan ke $name...'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }

                  // Connect — butuh macAddress dan printerName
                  final success = await PrinterService.connect(
                    address,
                    name,
                  );

                  if (mounted) {
                    if (success) {
                      setState(() {
                        _isPrinterConnected   = true;
                        _connectedPrinterName = name;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Terhubung ke $name'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Gagal terhubung ke printer. Pastikan printer menyala.'),
                          backgroundColor: PosColors.error,
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  // Cetak struk
  Future<void> _printReceipt({
    required String orderId,
    required String metode,
    required double total,
    required double bayar,
    required double kembalian,
    required String pemesan,
    required String catatan,
    required List<Map<String, dynamic>> items,
  }) async {
    // Kalau belum konek, tawarkan konek dulu
    if (!_isPrinterConnected) {
      if (mounted) {
        final shouldConnect = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Printer Belum Terhubung'),
            content:
                const Text('Hubungkan ke printer Bluetooth terlebih dahulu?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Tidak'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: PosColors.primary),
                child: const Text('Ya, Hubungkan'),
              ),
            ],
          ),
        );
        if (shouldConnect == true) {
          await _connectToPrinter();
        }
      }
      return;
    }

    setState(() => _isPrinting = true);

    try {
      final success = await PrinterService.printReceipt(
        invoiceNo: orderId,
        pemesan:   pemesan.isEmpty ? 'Pelanggan' : pemesan,
        metode:    metode,
        total:     total,
        bayar:     bayar,
        kembalian: kembalian,
        items:     items,
        catatan:   catatan,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                success ? 'Struk berhasil dicetak!' : 'Gagal mencetak struk.'),
            backgroundColor: success ? Colors.green : PosColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mencetak: $e'),
            backgroundColor: PosColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // DataRefreshMixin
  @override
  void onDataChanged() => _loadProduk();

  Future<void> _loadProduk() async {
    final data = await DatabaseHelper.instance.getProducts();
    if (!mounted) return;
    setState(() {
      _produkList    = data;
      _loadingProduk = false;
    });
  }

  List<Map<String, dynamic>> get _filteredProduk {
    final dbCat = _categories.firstWhere(
      (c) => c['label'] == _kategori,
      orElse: () => {'db': _kategori},
    )['db']!;
    return _produkList
        .where((p) =>
            p['category'] == dbCat && (p['stock'] as int? ?? 0) > 0)
        .toList();
  }

  double get _total => _cart.fold(
        0.0,
        (s, e) => s + (e['price'] as num).toDouble() * (e['qty'] as int),
      );

  String _formatRp(double val) => 'Rp ${val.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '.',
      )}';

  String _invoiceNo(String orderId) {
    final now    = DateTime.now();
    final d      = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final suffix = orderId.length >= 4
        ? orderId.substring(orderId.length - 4).toUpperCase()
        : orderId.toUpperCase();
    return 'ORD-$d-$suffix';
  }

  // ── Cart ──────────────────────────────────────────────────
  void _addToCart(Map<String, dynamic> item) {
    setState(() {
      final i = _cart.indexWhere((e) => e['id'] == item['id']);
      if (i != -1) {
        _cart[i]['qty']++;
      } else {
        _cart.add({...item, 'qty': 1});
      }
    });
  }

  void _increment(int i) => setState(() => _cart[i]['qty']++);
  void _decrement(int i) {
    setState(() {
      if (_cart[i]['qty'] > 1) {
        _cart[i]['qty']--;
      } else {
        _cart.removeAt(i);
      }
    });
  }

  void _removeItem(int i) => setState(() => _cart.removeAt(i));
  void _clearCart()       => setState(() => _cart.clear());

  // ── Payment ───────────────────────────────────────────────
  void _showPaymentDialog() {
    if (_cart.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentDialog(
        total:    _total,
        formatRp: _formatRp,
        onPay:    _prosesBayar,
      ),
    );
  }

  Future<void> _prosesBayar(String metode, double bayar) async {
    try {
      final totalHarga = _total;
      final tempCart   = List<Map<String, dynamic>>.from(_cart);
      final pemesan    = _namaPemesan.trim();
      final catatan    = _catatan.trim();

      // Validasi stok
      for (final item in tempCart) {
        final stok = item['stock'] as int? ?? 0;
        final qty  = item['qty']   as int;
        if (qty > stok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Stok ${item['name']} tidak cukup! Sisa: $stok'),
              backgroundColor: PosColors.error,
            ));
          }
          return;
        }
      }

      // Buat order
      final orderId = await DatabaseHelper.instance.createOrder({
        'total_price':    totalHarga,
        'payment_method': metode,
        'status':         'Paid',
      });

      // Tambah items + kurangi stok
      for (final item in tempCart) {
        await DatabaseHelper.instance.addOrderItem({
          'order_id':   orderId,
          'product_id': item['id'],
          'quantity':   item['qty'],
          'subtotal':
              (item['price'] as num).toDouble() * (item['qty'] as int),
        });
        await DatabaseHelper.instance.updateProductStock(
          item['id'],
          (item['stock'] as int) - (item['qty'] as int),
        );
      }

      DataNotifier.notify();

      final kembalian = metode == 'Cash'
          ? (bayar - totalHarga).clamp(0, double.infinity).toDouble()
          : 0.0;

      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _cart.clear());

      _showStruk(
        orderId,
        metode,
        totalHarga,
        tempCart,
        bayar,
        kembalian,
        pemesan,
        catatan,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: PosColors.error,
        ));
      }
    }
  }

  void _showStruk(
    String orderId,
    String metode,
    double total,
    List<Map<String, dynamic>> items,
    double bayar,
    double kembalian,
    String pemesan,
    String catatan,
  ) {
    final invoiceNo = _invoiceNo(orderId);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StrukDialog(
        invoiceNo: invoiceNo,
        metode:    metode,
        total:     total,
        items:     items,
        bayar:     bayar,
        kembalian: kembalian,
        pemesan:   pemesan.isEmpty ? 'Pelanggan' : pemesan,
        catatan:   catatan,
        formatRp:  _formatRp,
        isPrinting: _isPrinting,
        onPrint: () => _printReceipt(
          orderId:   invoiceNo,
          metode:    metode,
          total:     total,
          bayar:     bayar,
          kembalian: kembalian,
          pemesan:   pemesan.isEmpty ? 'Pelanggan' : pemesan,
          catatan:   catatan,
          items: items
              .map((item) => {
                    'name':  item['name'],
                    'price': (item['price'] as num).toDouble(),
                    'qty':   item['qty'] as int,
                  })
              .toList(),
        ),
      ),
    );
  }

  // ============================================================
  //  BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        title: const Text('Kasir Seblak Kacida'),
        backgroundColor: PosColors.primary,
        actions: [
          // Tombol status & koneksi printer
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                _isPrinterConnected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: Colors.white,
              ),
              onPressed: _connectToPrinter,
              tooltip: _isPrinterConnected
                  ? 'Terhubung: ${_connectedPrinterName ?? "Printer"}'
                  : 'Hubungkan Printer',
            ),
          ),
        ],
      ),
      body:               isMobile ? _mobileLayout() : _tabletLayout(),
      bottomNavigationBar: isMobile ? _mobileBottomBar() : null,
    );
  }

  Widget _tabletLayout() {
    return Row(
      children: [
        Expanded(flex: 3, child: _menuPanel()),
        Container(width: 1, color: PosColors.border),
        SizedBox(width: 320, child: _cartPanel()),
      ],
    );
  }

  Widget _mobileLayout() => _menuPanel();

  Widget _mobileBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:  PosColors.surface,
        border: Border(top: BorderSide(color: PosColors.border)),
        boxShadow: const [PosShadows.md],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_cart.fold(0, (s, e) => s + (e['qty'] as int))} item',
                    style: const TextStyle(
                        fontSize: 12, color: PosColors.textSecondary),
                  ),
                  Text(
                    _formatRp(_total),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: PosColors.primary),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _cart.isEmpty
                  ? null
                  : () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _CartBottomSheet(
                          cart:          _cart,
                          total:         _total,
                          formatRp:      _formatRp,
                          onNameChanged: (v) =>
                              setState(() => _namaPemesan = v),
                          onNoteChanged: (v) =>
                              setState(() => _catatan = v),
                          onIncrement:   _increment,
                          onDecrement:   _decrement,
                          onRemove:      _removeItem,
                          onClear:       _clearCart,
                          onBayar:       _showPaymentDialog,
                        ),
                      ),
              icon:  const Icon(Icons.shopping_cart_rounded, size: 18),
              label: const Text('Keranjang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PosColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Menu Panel ────────────────────────────────────────────
  Widget _menuPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _menuHeader(),
        _categoryChips(),
        Expanded(
          child: _loadingProduk
              ? const Center(
                  child: CircularProgressIndicator(color: PosColors.primary))
              : _menuGrid(),
        ),
      ],
    );
  }

  Widget _menuHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Pesan Seblak',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: PosColors.textPrimary,
                  letterSpacing: -0.4)),
          SizedBox(height: 4),
          Text('Pilih item favoritmu!',
              style:
                  TextStyle(fontSize: 13, color: PosColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _categoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: _categories.map((cat) {
          final sel = _kategori == cat['label'];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _kategori = cat['label']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? PosColors.primary : PosColors.surface,
                  borderRadius:
                      BorderRadius.circular(PosRadius.xxl),
                  border: Border.all(
                    color: sel ? PosColors.primary : PosColors.border,
                    width: 1.5,
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: PosColors.primary
                                .withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat['emoji']!,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      cat['label']!,
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color: sel
                            ? Colors.white
                            : PosColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _menuGrid() {
    final items = _filteredProduk;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_dissatisfied_rounded,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Tidak ada produk tersedia',
                style: TextStyle(
                    color: PosColors.textMuted, fontSize: 14)),
          ],
        ),
      );
    }

    final isMobile   = Responsive.isMobile(context);
    final crossCount = isMobile ? 2 : 4;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   crossCount,
        mainAxisSpacing:  12,
        crossAxisSpacing: 12,
        childAspectRatio: isMobile ? 0.85 : 0.9,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _MenuCard(
        item:     items[i],
        formatRp: _formatRp,
        onTap:    () => _addToCart(items[i]),
      ),
    );
  }

  // ── Cart Panel (tablet) ───────────────────────────────────
  Widget _cartPanel() {
    return Container(
      color: PosColors.background,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            color: PosColors.surface,
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_rounded,
                    color: PosColors.textSecondary, size: 20),
                const SizedBox(width: 10),
                const Text('Keranjang',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: PosColors.textPrimary)),
                const Spacer(),
                if (_cart.isNotEmpty)
                  TextButton(
                    onPressed: _clearCart,
                    style: TextButton.styleFrom(
                        foregroundColor: PosColors.error,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8)),
                    child: const Text('Hapus Semua',
                        style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: PosColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: _inputField(
              hint:     'Nama pemesan...',
              icon:     Icons.person_outline_rounded,
              onChange: (v) => setState(() => _namaPemesan = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _inputField(
              hint:     'Catatan (opsional)...',
              onChange: (v) => setState(() => _catatan = v),
              maxLines: 2,
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? _emptyCart()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    itemCount: _cart.length,
                    itemBuilder: (_, i) => _CartItem(
                      item:        _cart[i],
                      formatRp:    _formatRp,
                      onIncrement: () => _increment(i),
                      onDecrement: () => _decrement(i),
                      onRemove:    () => _removeItem(i),
                    ),
                  ),
          ),
          _cartSummary(),
        ],
      ),
    );
  }

  Widget _inputField({
    required String hint,
    IconData? icon,
    required Function(String) onChange,
    int maxLines = 1,
  }) {
    return TextField(
      onChanged: onChange,
      maxLines:  maxLines,
      decoration: InputDecoration(
        hintText:   hint,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        fillColor:  PosColors.surface,
        filled:     true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
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
          borderSide: const BorderSide(
              color: PosColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _emptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dinner_dining_rounded,
              size: 52, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          const Text('Belum ada item dipilih',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PosColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('Tap item dari menu untuk menambahkan',
              style: TextStyle(
                  fontSize: 12, color: PosColors.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _cartSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:  PosColors.surface,
        border: Border(top: BorderSide(color: PosColors.border)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: PosColors.textPrimary)),
              Text(_formatRp(_total),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: PosColors.primary)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _cart.isEmpty ? null : _showPaymentDialog,
              icon:  const Icon(Icons.payment_rounded, size: 18),
              label: const Text('Bayar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PosColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  MENU CARD
// ============================================================

class _MenuCard extends StatefulWidget {
  final Map<String, dynamic>    item;
  final String Function(double) formatRp;
  final VoidCallback onTap;
  const _MenuCard({
    required this.item,
    required this.formatRp,
    required this.onTap,
  });

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.94).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item     = widget.item;
    final stock    = item['stock'] as int? ?? 0;
    final imageUrl = item['image_url'] as String? ?? '';
    final price    = (item['price'] as num?)?.toDouble() ?? 0.0;
    final isLow    = stock > 0 && stock <= 5;

    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: posCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft:  Radius.circular(PosRadius.lg),
                    topRight: Radius.circular(PosRadius.lg),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _produkImage(imageUrl),
                      if (isLow)
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: PosColors.warningBg,
                              borderRadius: BorderRadius.circular(
                                  PosRadius.xxl),
                              border: Border.all(
                                  color: const Color(0xFFFDE68A)),
                            ),
                            child: Text('Sisa $stock',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: PosColors.warning)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item['name'] as String? ?? '-',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PosColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      Text(widget.formatRp(price),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: PosColors.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _produkImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        color: PosColors.surfaceAlt,
        child: const Center(
            child: Icon(Icons.fastfood_rounded,
                size: 32, color: PosColors.textMuted)),
      );
    }
    if (!imageUrl.startsWith('assets/')) {
      return Image.file(File(imageUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
                color: PosColors.surfaceAlt,
                child: const Center(
                    child: Icon(Icons.fastfood_rounded,
                        size: 32, color: PosColors.textMuted)),
              ));
    }
    return Image.asset(imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
              color: PosColors.surfaceAlt,
              child: const Center(
                  child: Icon(Icons.fastfood_rounded,
                      size: 32, color: PosColors.textMuted)),
            ));
  }
}

// ============================================================
//  CART ITEM
// ============================================================

class _CartItem extends StatelessWidget {
  final Map<String, dynamic>    item;
  final String Function(double) formatRp;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartItem({
    required this.item,
    required this.formatRp,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final price    = (item['price'] as num).toDouble();
    final qty      = item['qty'] as int;
    final subtotal = price * qty;
    final imageUrl = item['image_url'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: posCardDecoration(withShadow: false),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(PosRadius.sm),
            child: imageUrl.isNotEmpty
                ? (!imageUrl.startsWith('assets/')
                    ? Image.file(File(imageUrl),
                        width: 40, height: 40, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imgPlaceholder())
                    : Image.asset(imageUrl,
                        width: 40, height: 40, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imgPlaceholder()))
                : _imgPlaceholder(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] as String? ?? '-',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PosColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(formatRp(subtotal),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PosColors.primary)),
              ],
            ),
          ),
          Row(
            children: [
              _QtyBtn(
                  icon: Icons.remove_rounded,
                  onTap: onDecrement,
                  isRemove: qty == 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('$qty',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PosColors.textPrimary)),
              ),
              _QtyBtn(
                  icon: Icons.add_rounded,
                  onTap: onIncrement,
                  isRemove: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: PosColors.surfaceAlt,
          borderRadius: BorderRadius.circular(PosRadius.sm),
        ),
        child: const Icon(Icons.fastfood_rounded,
            size: 18, color: PosColors.textMuted),
      );
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isRemove;
  const _QtyBtn(
      {required this.icon, required this.onTap, required this.isRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: isRemove ? PosColors.errorBg : PosColors.surfaceAlt,
          borderRadius: BorderRadius.circular(PosRadius.sm),
          border: Border.all(
            color: isRemove ? PosColors.primaryLight : PosColors.border,
          ),
        ),
        child: Icon(icon,
            size: 14,
            color: isRemove
                ? PosColors.primary
                : PosColors.textSecondary),
      ),
    );
  }
}

// ============================================================
//  CART BOTTOM SHEET (mobile)
// ============================================================

class _CartBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
  final double total;
  final String Function(double) formatRp;
  final Function(String) onNameChanged;
  final Function(String) onNoteChanged;
  final Function(int) onIncrement;
  final Function(int) onDecrement;
  final Function(int) onRemove;
  final VoidCallback onClear;
  final VoidCallback onBayar;

  const _CartBottomSheet({
    required this.cart,
    required this.total,
    required this.formatRp,
    required this.onNameChanged,
    required this.onNoteChanged,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onClear,
    required this.onBayar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color:        PosColors.background,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(PosRadius.xl)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: PosColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Keranjang',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: PosColors.textPrimary)),
                const Spacer(),
                if (cart.isNotEmpty)
                  TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(
                        foregroundColor: PosColors.error),
                    child: const Text('Hapus Semua',
                        style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTextField(
                      hint:      'Nama pemesan...',
                      icon:      Icons.person_outline_rounded,
                      onChanged: onNameChanged),
                  const SizedBox(height: 10),
                  _buildTextField(
                      hint:      'Catatan (opsional)...',
                      onChanged: onNoteChanged,
                      maxLines:  2),
                  const SizedBox(height: 16),
                  ...List.generate(
                    cart.length,
                    (i) => _CartItem(
                      item:        cart[i],
                      formatRp:    formatRp,
                      onIncrement: () => onIncrement(i),
                      onDecrement: () => onDecrement(i),
                      onRemove:    () => onRemove(i),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:  PosColors.surface,
              border: Border(top: BorderSide(color: PosColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text(formatRp(total),
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: PosColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: cart.isEmpty ? null : onBayar,
                      icon:  const Icon(Icons.payment_rounded, size: 18),
                      label: const Text('Bayar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PosColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    IconData? icon,
    required Function(String) onChanged,
    int maxLines = 1,
  }) {
    return TextField(
      onChanged: onChanged,
      maxLines:  maxLines,
      decoration: InputDecoration(
        hintText:   hint,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        fillColor:  PosColors.surface,
        filled:     true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
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
          borderSide: const BorderSide(
              color: PosColors.primary, width: 2),
        ),
      ),
    );
  }
}

// ============================================================
//  PAYMENT DIALOG
// ============================================================

class _PaymentDialog extends StatefulWidget {
  final double total;
  final String Function(double) formatRp;
  final Future<void> Function(String, double) onPay;

  const _PaymentDialog({
    required this.total,
    required this.formatRp,
    required this.onPay,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String _metode           = 'Cash';
  final _amountCtrl         = TextEditingController();
  bool _loading            = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.total.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _bayar =>
      double.tryParse(
          _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
      0;
  double get _kembalian =>
      (_bayar - widget.total).clamp(0, double.infinity);
  bool get _canPay =>
      _metode == 'QRIS' || _bayar >= widget.total;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PosColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadius.xl)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pembayaran',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: PosColors.textPrimary,
                      letterSpacing: -0.4)),
              const SizedBox(height: 20),
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: posHighlightDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Pembayaran',
                        style: TextStyle(
                            fontSize: 12,
                            color: PosColors.textSecondary)),
                    const SizedBox(height: 6),
                    Text(widget.formatRp(widget.total),
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: PosColors.primary,
                            letterSpacing: -0.5)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Metode Pembayaran',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PosColors.textSecondary)),
              const SizedBox(height: 10),
              Row(
                children: ['Cash', 'QRIS'].map((m) {
                  final sel   = _metode == m;
                  final label = m == 'Cash' ? 'Tunai' : 'QRIS';
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: m == 'Cash' ? 10 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _metode = m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                          decoration: BoxDecoration(
                            color: sel
                                ? PosColors.primary
                                : PosColors.surface,
                            borderRadius: BorderRadius.circular(
                                PosRadius.md),
                            border: Border.all(
                              color: sel
                                  ? PosColors.primary
                                  : PosColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                m == 'Cash'
                                    ? Icons.payments_rounded
                                    : Icons.qr_code_rounded,
                                size:  16,
                                color: sel
                                    ? Colors.white
                                    : PosColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(label,
                                  style: TextStyle(
                                      fontSize:   13,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? Colors.white
                                          : PosColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              if (_metode == 'Cash') ...[
                const Text('Uang Diterima',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PosColors.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller:   _amountCtrl,
                  keyboardType: TextInputType.number,
                  onChanged:    (_) => setState(() {}),
                  style: const TextStyle(
                      fontSize: 14, color: PosColors.textPrimary),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    fillColor:  PosColors.surface,
                    filled:     true,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(PosRadius.md),
                      borderSide:
                          const BorderSide(color: PosColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(PosRadius.md),
                      borderSide:
                          const BorderSide(color: PosColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(PosRadius.md),
                      borderSide: const BorderSide(
                          color: PosColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [5000, 10000, 20000, 50000, 100000]
                      .map((v) => GestureDetector(
                            onTap: () => setState(
                                () => _amountCtrl.text = v.toString()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: PosColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(
                                    PosRadius.md),
                                border: Border.all(
                                    color: PosColors.border),
                              ),
                              child: Text('Rp ${v ~/ 1000}k',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: PosColors.textSecondary)),
                            ),
                          ))
                      .toList()
                    ..add(GestureDetector(
                      onTap: () => setState(() => _amountCtrl.text =
                          widget.total.toStringAsFixed(0)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: PosColors.primaryBg,
                          borderRadius:
                              BorderRadius.circular(PosRadius.md),
                          border: Border.all(
                              color: PosColors.primaryLight),
                        ),
                        child: const Text('Uang Pas',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: PosColors.primary)),
                      ),
                    )),
                ),
                const SizedBox(height: 14),
                Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _bayar >= widget.total
                        ? PosColors.successBg
                        : PosColors.errorBg,
                    borderRadius: BorderRadius.circular(PosRadius.md),
                    border: Border.all(
                      color: _bayar >= widget.total
                          ? const Color(0xFF9AE6B4)
                          : PosColors.primaryLight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _bayar >= widget.total ? 'Kembalian' : 'Kurang',
                        style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w600,
                            color: _bayar >= widget.total
                                ? PosColors.success
                                : PosColors.error),
                      ),
                      Text(
                        _bayar >= widget.total
                            ? widget.formatRp(_kembalian)
                            : widget.formatRp(widget.total - _bayar),
                        style: TextStyle(
                            fontSize:   15,
                            fontWeight: FontWeight.w800,
                            color: _bayar >= widget.total
                                ? PosColors.success
                                : PosColors.error),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PosColors.infoBg,
                    borderRadius: BorderRadius.circular(PosRadius.md),
                    border: Border.all(
                        color: const Color(0xFF90CDF4)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.qr_code_rounded,
                          color: PosColors.info, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tunjukkan kode QR kepada pelanggan.\n'
                          'Tekan "Bayar QRIS" setelah pelanggan konfirmasi.',
                          style: TextStyle(
                              fontSize: 12,
                              color:    PosColors.info,
                              height:   1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_canPay && !_loading)
                          ? () async {
                              setState(() => _loading = true);
                              Navigator.pop(context);
                              await widget.onPay(
                                _metode,
                                _metode == 'Cash'
                                    ? _bayar
                                    : widget.total,
                              );
                            }
                          : null,
                      child: _loading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color:       Colors.white,
                                  strokeWidth: 2))
                          : Text(_metode == 'Cash'
                              ? 'Bayar Tunai'
                              : 'Bayar QRIS'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  STRUK DIALOG
// ============================================================

class _StrukDialog extends StatelessWidget {
  final String invoiceNo;
  final String metode;
  final double total;
  final List<Map<String, dynamic>> items;
  final double bayar;
  final double kembalian;
  final String pemesan;
  final String catatan;
  final String Function(double) formatRp;
  final VoidCallback onPrint;
  final bool isPrinting;

  const _StrukDialog({
    required this.invoiceNo,
    required this.metode,
    required this.total,
    required this.items,
    required this.bayar,
    required this.kembalian,
    required this.pemesan,
    required this.catatan,
    required this.formatRp,
    required this.onPrint,
    this.isPrinting = false,
  });

  @override
  Widget build(BuildContext context) {
    final now        = DateTime.now();
    final months     = [
      'Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agt','Sep','Okt','Nov','Des'
    ];
    final dateStr    =
        '${now.day} ${months[now.month - 1]} ${now.year}  '
        '${now.hour.toString().padLeft(2, '0')}.'
        '${now.minute.toString().padLeft(2, '0')}';
    final methodLabel = metode == 'Cash' ? 'Tunai' : metode;

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
              const Text('SEBLAK KACIDA',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: PosColors.textPrimary,
                      letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 12, color: PosColors.textMuted)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _row('No. Order', invoiceNo, bold: true),
              const SizedBox(height: 6),
              _row('Pemesan', pemesan),
              if (catatan.isNotEmpty) ...[
                const SizedBox(height: 6),
                _row('Catatan', catatan),
              ],
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              ...items.map((item) {
                final sub = (item['price'] as num).toDouble() *
                    (item['qty'] as int);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${item['name']} x${item['qty']}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: PosColors.textPrimary)),
                            Text(
                                formatRp((item['price'] as num)
                                    .toDouble()),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: PosColors.textMuted)),
                          ],
                        ),
                      ),
                      Text(formatRp(sub),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: PosColors.textPrimary)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _row('Total', formatRp(total),
                  bold: true, valueColor: PosColors.primary),
              const SizedBox(height: 6),
              _row('Bayar ($methodLabel)', formatRp(bayar)),
              const SizedBox(height: 6),
              _row('Kembalian', formatRp(kembalian),
                  bold: true, valueColor: PosColors.success),
              const SizedBox(height: 20),
              const Text('Terima kasih sudah mampir!',
                  style: TextStyle(
                      fontSize: 13, color: PosColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              // Tombol Cetak Struk
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isPrinting ? null : onPrint,
                  icon: isPrinting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: PosColors.primary))
                      : const Icon(Icons.print_rounded, size: 18),
                  label: Text(isPrinting ? 'Mencetak...' : 'Cetak Struk'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PosColors.primary,
                    side: const BorderSide(color: PosColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Selesai'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: PosColors.textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize:   13,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? PosColors.textPrimary)),
      ],
    );
  }
}