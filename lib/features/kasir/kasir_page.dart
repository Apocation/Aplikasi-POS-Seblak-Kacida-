import 'dart:io';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/data_notifier.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/printer_service.dart';

class KasirPage extends StatefulWidget {
  const KasirPage({super.key});

  @override
  State<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> with DataRefreshMixin {
  String _kategori = 'Base Seblak';
  String _namaPemesan = '';
  String _catatan = '';
  final List<Map<String, dynamic>> _cart = [];
  List<Map<String, dynamic>> _produkList = [];
  bool _loadingProduk = true;

  // Printer related
  bool _isPrinterConnected = false;
  bool _isPrinting = false;

  // Tablet: lebar keranjang
  final double _cartWidth = 280;

  static const List<Map<String, String>> _categories = [
    {'label': 'Base Seblak', 'db': 'Base', 'emoji': '🍜'},
    {'label': 'Topping', 'db': 'Topping', 'emoji': '🥩'},
    {'label': 'Sayur', 'db': 'Sayur', 'emoji': '🥬'},
    {'label': 'Level Pedas', 'db': 'Pedas', 'emoji': '🌶️'},
    {'label': 'Minuman', 'db': 'Minuman', 'emoji': '🥤'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProduk();
    _checkPrinterStatus();
  }

  Future<void> _checkPrinterStatus() async {
    final connected = await PrinterService.autoReconnect();
    if (mounted) {
      setState(() {
        _isPrinterConnected = connected;
      });
    }
  }

  Future<void> _connectToPrinter() async {
    final devices = await PrinterService.getBondedDevices();

    if (devices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada printer yang di-pair. Pair dulu di pengaturan HP.'),
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
              final device = devices[index];
              final name = device['name'] as String? ?? 'Unknown';
              final address = device['address'] as String? ?? '';
              return ListTile(
                leading: const Icon(Icons.print),
                title: Text(name),
                subtitle: Text(address),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(this.context);
                  Navigator.pop(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Menghubungkan ke $name...'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  final success = await PrinterService.connect(address, name);
                  if (mounted) {
                    setState(() {
                      _isPrinterConnected = success;
                    });
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Terhubung ke $name' : 'Gagal terhubung ke printer'),
                        backgroundColor: success ? Colors.green : PosColors.error,
                      ),
                    );
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
    if (!_isPrinterConnected) {
      if (mounted) {
        final shouldConnect = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Printer Belum Terhubung'),
            content: const Text('Hubungkan ke printer Bluetooth terlebih dahulu?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Tidak'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: PosColors.primary),
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
        pemesan: pemesan.isEmpty ? 'Pelanggan' : pemesan,
        metode: metode,
        total: total,
        bayar: bayar,
        kembalian: kembalian,
        items: items,
        catatan: catatan,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Struk berhasil dicetak!' : 'Gagal mencetak struk. Periksa koneksi printer.'),
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

  @override
  void onDataChanged() => _loadProduk();

  Future<void> _loadProduk() async {
    final data = await DatabaseHelper.instance.getProducts();
    if (!mounted) return;
    setState(() {
      _produkList = data;
      _loadingProduk = false;
    });
  }

  List<Map<String, dynamic>> get _filteredProduk {
    final dbCat = _categories
        .firstWhere((c) => c['label'] == _kategori, orElse: () => {'db': _kategori})['db']!;
    return _produkList
        .where((p) => p['category'] == dbCat && (p['stock'] as int? ?? 0) > 0)
        .toList();
  }

  double get _total => _cart.fold(
        0.0,
        (s, e) => s + (e['price'] as num).toDouble() * (e['qty'] as int),
      );

  String _formatRp(double val) =>
      'Rp ${val.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (_) => '.',
          )}';

  String _invoiceNo(String orderId) {
    final now = DateTime.now();
    final d = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final suffix = orderId.length >= 4 ? orderId.substring(orderId.length - 4).toUpperCase() : orderId.toUpperCase();
    return 'ORD-$d-$suffix';
  }

  // ==================== CART METHODS ====================
  
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
  void _clearCart() => setState(() => _cart.clear());

  // ==================== PAYMENT ====================
  
  void _showPaymentDialog() {
    if (_cart.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentDialog(
        total: _total,
        formatRp: _formatRp,
        onPay: _prosesBayar,
      ),
    );
  }

  Future<void> _prosesBayar(String metode, double bayar) async {
    // Tutup dialog payment dulu
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }

    try {
      final totalHarga = _total;
      final tempCart = List<Map<String, dynamic>>.from(_cart);
      final pemesan = _namaPemesan.trim();
      final catatan = _catatan.trim();

      if (tempCart.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keranjang kosong!'), backgroundColor: PosColors.error),
          );
        }
        return;
      }

      // Validasi stok
      for (final item in tempCart) {
        final stok = item['stock'] as int? ?? 0;
        final qty = item['qty'] as int;
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

      // DEKLARASIKAN KEMBALIAN SEBELUM DIGUNAKAN
      final kembalian = metode == 'Cash'
          ? (bayar - totalHarga).clamp(0, double.infinity).toDouble()
          : 0.0;

      // Buat order
      final orderId = await DatabaseHelper.instance.createOrder(
        totalPrice: totalHarga,
        paymentMethod: metode,
        status: 'Paid',
        customerName: pemesan.isEmpty ? 'Pelanggan' : pemesan,
        note: catatan,
        amountPaid: bayar,
        changeAmount: kembalian,
      );

      // Tambah items + kurangi stok
      for (final item in tempCart) {
        await DatabaseHelper.instance.addOrderItem({
          'order_id': orderId,
          'product_id': item['id'],
          'quantity': item['qty'],
          'subtotal': (item['price'] as num).toDouble() * (item['qty'] as int),
        });
        await DatabaseHelper.instance.updateProductStock(
          item['id'],
          (item['stock'] as int) - (item['qty'] as int),
        );
      }

      // Sync ke Firestore (jangan blokir UI kalau internet lambat/mati —
      // kalau gagal, transaksi tetap tersimpan lokal dan akan ikut
      // ter-push saat syncAll() berikutnya)
      await FirebaseService.pushSingleTransaction(orderId);
      for (final item in tempCart) {
        await FirebaseService.pushProductStock(
          item['id'] as String,
          (item['stock'] as int) - (item['qty'] as int),
        );
      }

      DataNotifier.notify();

      if (!mounted) return;
      
      // Clear cart
      setState(() {
        _cart.clear();
        _namaPemesan = '';
        _catatan = '';
      });

      // Tampilkan struk
      _showStruk(orderId, metode, totalHarga, tempCart, bayar, kembalian, pemesan, catatan);
      
    } catch (e) {
      debugPrint('Error proses bayar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}'),
            backgroundColor: PosColors.error,
          ),
        );
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
    
    // Tampilkan dialog tanpa barrierDismissible: false biar bisa ditutup
    showDialog(
      context: context,
      barrierDismissible: true, // Ubah jadi true biar bisa ditutup dengan tap luar
      builder: (_) => _StrukDialog(
        invoiceNo: invoiceNo,
        metode: metode,
        total: total,
        items: items,
        bayar: bayar,
        kembalian: kembalian,
        pemesan: pemesan.isEmpty ? 'Pelanggan' : pemesan,
        catatan: catatan,
        formatRp: _formatRp,
        isPrinting: _isPrinting,
        onPrint: () => _printReceipt(
          orderId: invoiceNo,
          metode: metode,
          total: total,
          bayar: bayar,
          kembalian: kembalian,
          pemesan: pemesan.isEmpty ? 'Pelanggan' : pemesan,
          catatan: catatan,
          items: items.map((item) => {
            'name': item['name'],
            'price': (item['price'] as num).toDouble(),
            'qty': item['qty'] as int,
            'category': item['category'] as String? ?? 'Lainnya',
          }).toList(),
        ),
        onClose: () {
          // Kembali ke halaman kasir setelah tutup dialog
          if (mounted) {
            // Force refresh halaman kasir
            setState(() {});
          }
        },
      ),
    ).then((_) {
      // Setelah dialog ditutup, pastikan navigator tetap aman
      if (mounted) {
        // Refresh data
        _loadProduk();
      }
    });
  }

  // ==================== BUILD ====================
  
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: PosColors.background,
      body: isMobile 
          ? _mobileLayout() 
          : _tabletLayout(),
      bottomNavigationBar: isMobile ? _mobileBottomBar() : null,
    );
  }

  // ==================== TABLET LAYOUT ====================
  Widget _tabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: _menuPanel(),
        ),
        Container(width: 1, color: PosColors.border),
        SizedBox(
          width: _cartWidth,
          child: _cartPanel(),
        ),
      ],
    );
  }

  // ==================== MOBILE LAYOUT ====================
  Widget _mobileLayout() => _menuPanel();

  Widget _mobileBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(top: BorderSide(color: PosColors.border)),
        boxShadow: [PosShadows.md],
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
                    style: const TextStyle(fontSize: 12, color: PosColors.textSecondary),
                  ),
                  Text(
                    _formatRp(_total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: PosColors.primary,
                    ),
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
                          cart: _cart,
                          formatRp: _formatRp,
                          onNameChanged: (v) => setState(() => _namaPemesan = v),
                          onNoteChanged: (v) => setState(() => _catatan = v),
                          onIncrement: _increment,
                          onDecrement: _decrement,
                          onRemove: _removeItem,
                          onClear: _clearCart,
                          onBayar: _showPaymentDialog,
                        ),
                      ),
              icon: const Icon(Icons.shopping_cart_rounded, size: 18),
              label: const Text('Keranjang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PosColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MENU PANEL ====================
  
  Widget _menuPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _menuHeader(),
        _categoryChips(),
        Expanded(
          child: _loadingProduk
              ? const Center(child: CircularProgressIndicator(color: PosColors.primary))
              : _menuGrid(),
        ),
      ],
    );
  }

  Widget _menuHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pesan Seblak',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: PosColors.textPrimary, letterSpacing: -0.4)),
          SizedBox(height: 2),
          Text('Pilih item favoritmu!',
              style: TextStyle(fontSize: 12, color: PosColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _categoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: _categories.map((cat) {
          final sel = _kategori == cat['label'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _kategori = cat['label']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? PosColors.primary : PosColors.surface,
                  borderRadius: BorderRadius.circular(PosRadius.xxl),
                  border: Border.all(color: sel ? PosColors.primary : PosColors.border, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat['emoji']!, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(cat['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : PosColors.textSecondary,
                        )),
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
            Icon(Icons.sentiment_dissatisfied_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Tidak ada produk tersedia',
                style: TextStyle(color: PosColors.textMuted, fontSize: 14)),
          ],
        ),
      );
    }

    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    
    int crossCount;
    double childAspectRatio;
    
    if (isTablet) {
      crossCount = 4;
      childAspectRatio = 0.75;
    } else if (isMobile) {
      crossCount = 2;
      childAspectRatio = 0.80;
    } else {
      crossCount = 5;
      childAspectRatio = 0.85;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _MenuCard(
        item: items[i],
        formatRp: _formatRp,
        onTap: () => _addToCart(items[i]),
      ),
    );
  }

  // ==================== CART PANEL ====================
  Widget _cartPanel() {
    return Container(
      width: _cartWidth,
      color: PosColors.background,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            color: PosColors.surface,
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_rounded, color: PosColors.textSecondary, size: 16),
                const SizedBox(width: 6),
                const Text('Keranjang',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: PosColors.textPrimary)),
                const Spacer(),
                if (_cart.isNotEmpty)
                  TextButton(
                    onPressed: _clearCart,
                    style: TextButton.styleFrom(foregroundColor: PosColors.error, padding: const EdgeInsets.symmetric(horizontal: 6)),
                    child: const Text('Hapus Semua', style: TextStyle(fontSize: 10)),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: PosColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: _inputField(
              hint: 'Nama pemesan...',
              icon: Icons.person_outline_rounded,
              onChange: (v) => setState(() => _namaPemesan = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
            child: _inputField(
              hint: 'Catatan (opsional)...',
              onChange: (v) => setState(() => _catatan = v),
              maxLines: 2,
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? _emptyCart()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    itemCount: _cart.length,
                    itemBuilder: (_, i) => _CartItem(
                      item: _cart[i],
                      formatRp: _formatRp,
                      onIncrement: () => _increment(i),
                      onDecrement: () => _decrement(i),
                      onRemove: () => _removeItem(i),
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
      maxLines: maxLines,
      style: const TextStyle(fontSize: 11, color: PosColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11),
        prefixIcon: icon != null ? Icon(icon, size: 14) : null,
        fillColor: PosColors.surface,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.primary, width: 2)),
      ),
    );
  }

  Widget _emptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dinner_dining_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('Belum ada item dipilih',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PosColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('Tap item dari menu untuk menambahkan',
              style: TextStyle(fontSize: 10, color: PosColors.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _cartSummary() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(top: BorderSide(color: PosColors.border)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: PosColors.textPrimary)),
              Text(_formatRp(_total),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: PosColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _cart.isEmpty ? null : _showPaymentDialog,
              icon: const Icon(Icons.payment_rounded, size: 14),
              label: const Text('Bayar', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: PosColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MENU CARD
// ============================================================

class _MenuCard extends StatefulWidget {
  final Map<String, dynamic> item;
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

class _MenuCardState extends State<_MenuCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.94).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final stock = item['stock'] as int? ?? 0;
    final imageUrl = item['image_url'] as String? ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final isLow = stock > 0 && stock <= 5;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: posCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(PosRadius.lg),
                  topRight: Radius.circular(PosRadius.lg),
                ),
                child: AspectRatio(
                  aspectRatio: 1.2,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _produkImage(imageUrl),
                      if (isLow)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: PosColors.warningBg,
                              borderRadius: BorderRadius.circular(PosRadius.xxl),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Text('Sisa $stock',
                                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: PosColors.warning)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Text(
                  item['name'] as String? ?? '-',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PosColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  widget.formatRp(price),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PosColors.primary),
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
        child: const Center(child: Icon(Icons.fastfood_rounded, size: 24, color: PosColors.textMuted)),
      );
    }
    if (!imageUrl.startsWith('assets/')) {
      return Image.file(File(imageUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
                color: PosColors.surfaceAlt,
                child: const Center(child: Icon(Icons.fastfood_rounded, size: 24, color: PosColors.textMuted)),
              ));
    }
    return Image.asset(imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
              color: PosColors.surfaceAlt,
              child: const Center(child: Icon(Icons.fastfood_rounded, size: 24, color: PosColors.textMuted)),
            ));
  }
}

// ============================================================
// CART ITEM
// ============================================================

class _CartItem extends StatelessWidget {
  final Map<String, dynamic> item;
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
    final price = (item['price'] as num).toDouble();
    final qty = item['qty'] as int;
    final subtotal = price * qty;
    final imageUrl = item['image_url'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: posCardDecoration(withShadow: false),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(PosRadius.sm),
            child: imageUrl.isNotEmpty
                ? (!imageUrl.startsWith('assets/')
                    ? Image.file(File(imageUrl), width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgPlaceholder())
                    : Image.asset(imageUrl, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgPlaceholder()))
                : _imgPlaceholder(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] as String? ?? '-',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PosColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(formatRp(subtotal),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: PosColors.primary)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyBtn(
                icon: qty == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                onTap: onDecrement,
                isRemove: qty == 1,
              ),
              SizedBox(
                width: 28,
                child: Center(
                  child: Text('$qty',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: PosColors.textPrimary)),
                ),
              ),
              _QtyBtn(
                icon: Icons.add_rounded,
                onTap: onIncrement,
                isRemove: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: PosColors.surfaceAlt,
          borderRadius: BorderRadius.circular(PosRadius.sm),
        ),
        child: const Icon(Icons.fastfood_rounded, size: 16, color: PosColors.textMuted),
      );
}

// ============================================================
// QTY BUTTON
// ============================================================

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isRemove;

  const _QtyBtn({
    required this.icon,
    required this.onTap,
    required this.isRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isRemove ? PosColors.errorBg : PosColors.surfaceAlt,
      borderRadius: BorderRadius.circular(PosRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosRadius.sm),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadius.sm),
            border: Border.all(color: isRemove ? PosColors.primaryLight : PosColors.border),
          ),
          child: Icon(icon, size: 14, color: isRemove ? PosColors.primary : PosColors.textSecondary),
        ),
      ),
    );
  }
}

// ============================================================
// CART BOTTOM SHEET (mobile)
// ============================================================

class _CartBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
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
    final total = cart.fold(0.0, (s, e) => s + (e['price'] as num).toDouble() * (e['qty'] as int));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadius.xl)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: PosColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Keranjang',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: PosColors.textPrimary)),
                const Spacer(),
                if (cart.isNotEmpty)
                  TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(foregroundColor: PosColors.error),
                    child: const Text('Hapus Semua', style: TextStyle(fontSize: 12)),
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
                    hint: 'Nama pemesan...',
                    icon: Icons.person_outline_rounded,
                    onChanged: onNameChanged,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    hint: 'Catatan (opsional)...',
                    onChanged: onNoteChanged,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                    cart.length,
                    (i) => _CartItem(
                      item: cart[i],
                      formatRp: formatRp,
                      onIncrement: () => onIncrement(i),
                      onDecrement: () => onDecrement(i),
                      onRemove: () => onRemove(i),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: PosColors.surface,
              border: Border(top: BorderSide(color: PosColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(formatRp(total),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: PosColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: cart.isEmpty ? null : onBayar,
                      icon: const Icon(Icons.payment_rounded, size: 18),
                      label: const Text('Bayar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PosColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
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
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        fillColor: PosColors.surface,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.primary, width: 2)),
      ),
    );
  }
}

// ============================================================
// PAYMENT DIALOG
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
  String _metode = 'Cash';
  final _amountCtrl = TextEditingController();
  bool _loading = false;

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

  double get _bayar => double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  double get _kembalian => (_bayar - widget.total).clamp(0, double.infinity);
  bool get _canPay => _metode == 'QRIS' || _bayar >= widget.total;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PosColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosRadius.xl)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pembayaran',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: PosColors.textPrimary, letterSpacing: -0.4)),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: posHighlightDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Pembayaran',
                        style: TextStyle(fontSize: 12, color: PosColors.textSecondary)),
                    const SizedBox(height: 6),
                    Text(widget.formatRp(widget.total),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: PosColors.primary, letterSpacing: -0.5)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Metode Pembayaran',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PosColors.textSecondary)),
              const SizedBox(height: 10),
              Row(
                children: ['Cash', 'QRIS'].map((m) {
                  final sel = _metode == m;
                  final label = m == 'Cash' ? 'Tunai' : 'QRIS';
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: m == 'Cash' ? 10 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _metode = m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: sel ? PosColors.primary : PosColors.surface,
                            borderRadius: BorderRadius.circular(PosRadius.md),
                            border: Border.all(color: sel ? PosColors.primary : PosColors.border, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(m == 'Cash' ? Icons.payments_rounded : Icons.qr_code_rounded,
                                  size: 16, color: sel ? Colors.white : PosColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(label,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                      color: sel ? Colors.white : PosColors.textSecondary)),
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PosColors.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14, color: PosColors.textPrimary),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    fillColor: PosColors.surface,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PosRadius.md), borderSide: const BorderSide(color: PosColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...List.generate(5, (i) => [5000, 10000, 20000, 50000, 100000][i]).map((v) => GestureDetector(
                          onTap: () => setState(() => _amountCtrl.text = v.toString()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: PosColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(PosRadius.md),
                              border: Border.all(color: PosColors.border),
                            ),
                            child: Text('Rp ${v ~/ 1000}k',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PosColors.textSecondary)),
                          ),
                        )),
                    GestureDetector(
                      onTap: () => setState(() => _amountCtrl.text = widget.total.toStringAsFixed(0)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: PosColors.primaryBg,
                          borderRadius: BorderRadius.circular(PosRadius.md),
                          border: Border.all(color: PosColors.primaryLight),
                        ),
                        child: const Text('Uang Pas',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PosColors.primary)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _bayar >= widget.total ? PosColors.successBg : PosColors.errorBg,
                    borderRadius: BorderRadius.circular(PosRadius.md),
                    border: Border.all(color: _bayar >= widget.total ? const Color(0xFF9AE6B4) : PosColors.primaryLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_bayar >= widget.total ? 'Kembalian' : 'Kurang',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: _bayar >= widget.total ? PosColors.success : PosColors.error)),
                      Text(_bayar >= widget.total ? widget.formatRp(_kembalian) : widget.formatRp(widget.total - _bayar),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                              color: _bayar >= widget.total ? PosColors.success : PosColors.error)),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PosColors.infoBg,
                    borderRadius: BorderRadius.circular(PosRadius.md),
                    border: Border.all(color: const Color(0xFF90CDF4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.qr_code_rounded, color: PosColors.info, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tunjukkan kode QR kepada pelanggan.\nTekan "Bayar QRIS" setelah pelanggan konfirmasi.',
                          style: TextStyle(fontSize: 12, color: PosColors.info, height: 1.5),
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
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_canPay && !_loading)
                          ? () async {
                              setState(() => _loading = true);
                              await widget.onPay(_metode, _metode == 'Cash' ? _bayar : widget.total);
                            }
                          : null,
                      child: _loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_metode == 'Cash' ? 'Bayar Tunai' : 'Bayar QRIS'),
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
// STRUK DIALOG (DIPERBAIKI)
// ============================================================

class _StrukDialog extends StatefulWidget {
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
  final VoidCallback onClose;

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
    required this.onClose,
  });

  @override
  State<_StrukDialog> createState() => _StrukDialogState();
}

class _StrukDialogState extends State<_StrukDialog> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}  ${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}';

    return Dialog(
      backgroundColor: PosColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosRadius.xl)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('SEBLAK KACIDA',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: PosColors.textPrimary, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(dateStr, style: const TextStyle(fontSize: 12, color: PosColors.textMuted)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _row('No. Order', widget.invoiceNo, bold: true),
              const SizedBox(height: 6),
              _row('Pemesan', widget.pemesan),
              if (widget.catatan.isNotEmpty) ...[
                const SizedBox(height: 6),
                _row('Catatan', widget.catatan),
              ],
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              ...widget.items.map((item) {
                final sub = (item['price'] as num).toDouble() * (item['qty'] as int);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item['name']} x${item['qty']}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PosColors.textPrimary)),
                            Text(widget.formatRp((item['price'] as num).toDouble()),
                                style: const TextStyle(fontSize: 11, color: PosColors.textMuted)),
                          ],
                        ),
                      ),
                      Text(widget.formatRp(sub),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: PosColors.textPrimary)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _row('Total', widget.formatRp(widget.total), bold: true, valueColor: PosColors.primary),
              const SizedBox(height: 6),
              if (widget.metode == 'Cash') ...[
                _row('Bayar', widget.formatRp(widget.bayar)),
                const SizedBox(height: 6),
                _row('Kembalian', widget.formatRp(widget.kembalian), bold: true, valueColor: PosColors.success),
              ],
              const SizedBox(height: 20),
              const Text('Terima kasih sudah mampir! 🌶️',
                  style: TextStyle(fontSize: 13, color: PosColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.isPrinting ? null : widget.onPrint,
                  icon: widget.isPrinting
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: PosColors.primary))
                      : const Icon(Icons.print_rounded, size: 18),
                  label: Text(widget.isPrinting ? 'Mencetak...' : 'Cetak Struk'),
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
                  onPressed: () {
                    widget.onClose();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: PosColors.primary, padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Selesai', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: PosColors.textSecondary)),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? PosColors.textPrimary,
            )),
      ],
    );
  }
}