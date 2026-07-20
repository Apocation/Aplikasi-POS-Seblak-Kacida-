import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/data_notifier.dart';
import '../../theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/image_service.dart';


// ============================================================
//  PRODUK PAGE
//  Tabel produk + filter kategori + CRUD + image picker
// ============================================================

class ProdukPage extends StatefulWidget {
  const ProdukPage({super.key});

  @override
State<ProdukPage> createState() => _ProdukPageState();
}

class _ProdukPageState extends State<ProdukPage> with DataRefreshMixin {
  @override
  void onDataChanged() => _load();
  List<Map<String, dynamic>> _produk = [];
  bool _loading = true;
  String _kategori = 'Semua';

  static const List<Map<String, String>> _categories = [
    {'label': 'Semua',      'db': '',       'emoji': ''},
    {'label': 'Base Seblak','db': 'Base',   'emoji': '🍜'},
    {'label': 'Topping',    'db': 'Topping','emoji': '🥩'},
    {'label': 'Sayur',      'db': 'Sayur',  'emoji': '🥬'},
    {'label': 'Level Pedas','db': 'Pedas',  'emoji': '🌶️'},
    {'label': 'Minuman', 'db': 'Minuman', 'emoji': '🥤'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper.instance.getProducts();
    if (!mounted) return;
    setState(() {
      _produk  = data;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_kategori == 'Semua') return _produk;
    final dbCat = _categories
        .firstWhere((c) => c['label'] == _kategori,
            orElse: () => {'db': _kategori})['db']!;
    return _produk.where((p) => p['category'] == dbCat).toList();
  }

  String _formatRp(num val) => 'Rp ${val
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';

  String _categoryLabel(String dbCat) {
    switch (dbCat) {
      case 'Base':    return 'Base Seblak';
      case 'Topping': return 'Topping';
      case 'Sayur':   return 'Sayur';
      case 'Pedas':   return 'Level Pedas';
      case 'Minuman': return 'Minuman';
      default:        return dbCat;
    }
  }

  String _categoryEmoji(String dbCat) {
    switch (dbCat) {
      case 'Base':    return '🍜';
      case 'Topping': return '🥩';
      case 'Sayur':   return '🥬';
      case 'Pedas':   return '🌶️';
      case 'Minuman': return '🥤';  
      default:        return '🍽️';
    }
  }

  void _tambah() {
    showDialog(
      context: context,
      builder: (_) => _ProdukFormDialog(
        onSave: (data) async {
          final newId = await DatabaseHelper.instance.insertProduct(data);
          FirebaseService.pushSingleProduct(newId);
          DataNotifier.notify();
          _load();
        },
      ),
    );
  }

  void _edit(Map<String, dynamic> produk) {
    showDialog(
      context: context,
      builder: (_) => _ProdukFormDialog(
        existing: produk,
        onSave: (data) async {
          await DatabaseHelper.instance.updateProduct(produk['id'] as String, data);
          FirebaseService.pushSingleProduct(produk['id'] as String);
          DataNotifier.notify();
          _load();
        },
      ),
    );
  }

  Future<void> _toggleStatus(Map<String, dynamic> produk) async {
    final stock = produk['stock'] as int? ?? 0;
    await DatabaseHelper.instance.updateProduct(
      produk['id'] as String,
      {'stock': stock > 0 ? 0 : 10},
    );
    FirebaseService.pushSingleProduct(produk['id'] as String);
    DataNotifier.notify();
    _load();
  }

  void _hapus(Map<String, dynamic> produk) {
    showDialog(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title:   'Hapus Produk?',
        message: 'Produk "${produk['name']}" akan dihapus permanen.',
        onConfirm: () async {
          Navigator.pop(ctx);
          await ImageService.instance
              .deleteIfLocal(produk['image_url'] as String?);
          await DatabaseHelper.instance
              .deleteProduct(produk['id'] as String);
          // Hapus juga di cloud supaya tidak muncul lagi saat pull
          FirebaseService.deleteProduct(produk['id'] as String);
          DataNotifier.notify();
          _load();
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile  = Responsive.isMobile(context);
    final displayed = _filtered;

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: PosColors.primary))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isMobile, displayed.length),
                  _buildCategoryFilter(),
                  const SizedBox(height: 4),
                  Expanded(
                    child: isMobile
                        ? _buildMobileList(displayed)
                        : _buildTable(displayed),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile, int count) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24, 20, isMobile ? 16 : 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Text('📦 ', style: TextStyle(fontSize: 22)),
                  Text('Produk',
                      style: TextStyle(
                        fontSize:   22,
                        fontWeight: FontWeight.w800,
                        color:      PosColors.textPrimary,
                        letterSpacing: -0.4,
                      )),
                ]),
                const SizedBox(height: 4),
                Text('$count produk ditampilkan',
                    style: const TextStyle(
                        fontSize: 13, color: PosColors.textSecondary)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _tambah,
            icon:  const Icon(Icons.add_rounded, size: 18),
            label: const Text('Tambah'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PosColors.primary,
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: _categories.map((cat) {
          final selected = _kategori == cat['label'];
          final hasEmoji = cat['emoji']!.isNotEmpty;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _kategori = cat['label']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? PosColors.primary : PosColors.surface,
                  borderRadius: BorderRadius.circular(PosRadius.xxl),
                  border: Border.all(
                    color: selected ? PosColors.primary : PosColors.border,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasEmoji) ...[
                      Text(cat['emoji']!,
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      cat['label']!,
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color: selected
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

  Widget _buildTable(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _emptyState();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        decoration: posCardDecoration(),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: PosColors.surfaceAlt,
                borderRadius: BorderRadius.only(
                  topLeft:  Radius.circular(PosRadius.lg),
                  topRight: Radius.circular(PosRadius.lg),
                ),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 40),
                  SizedBox(width: 12),
                  Expanded(flex: 3, child: _HeaderCell('Item')),
                  Expanded(flex: 2, child: _HeaderCell('Kategori')),
                  SizedBox(width: 110, child: _HeaderCell('Harga', right: true)),
                  SizedBox(width: 70,  child: _HeaderCell('Stok',  right: true)),
                  SizedBox(width: 90,  child: _HeaderCell('Status')),
                  SizedBox(width: 110, child: _HeaderCell('Aksi',  right: true)),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _TableRow(
                produk:   items[i],
                formatRp: _formatRp,
                catLabel: _categoryLabel,
                catEmoji: _categoryEmoji,
                onEdit:   () => _edit(items[i]),
                onToggle: () => _toggleStatus(items[i]),
                onHapus:  () => _hapus(items[i]),
                isLast:   i == items.length - 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _emptyState();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _MobileCard(
        produk:   items[i],
        formatRp: _formatRp,
        catLabel: _categoryLabel,
        catEmoji: _categoryEmoji,
        onEdit:   () => _edit(items[i]),
        onToggle: () => _toggleStatus(items[i]),
        onHapus:  () => _hapus(items[i]),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Tidak ada produk',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: PosColors.textSecondary)),
          const SizedBox(height: 6),
          const Text('Tambah produk baru dengan tombol di atas',
              style: TextStyle(
                  fontSize: 13, color: PosColors.textMuted)),
        ],
      ),
    );
  }
}

// ============================================================
//  PRODUK IMAGE — handle asset & file lokal
// ============================================================

class ProdukImage extends StatelessWidget {
  final String?       imageUrl;
  final double        width;
  final double        height;
  final BorderRadius? borderRadius;

  const ProdukImage({
    super.key,
    required this.imageUrl,
    this.width        = 40,
    this.height       = 40,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(PosRadius.sm);

    if (imageUrl == null || imageUrl!.isEmpty) {
      return _placeholder(br);
    }

    final Widget img = ImageService.isLocalFile(imageUrl)
        ? Image.file(File(imageUrl!),
            width: width, height: height, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(br))
        : Image.asset(imageUrl!,
            width: width, height: height, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(br));

    return ClipRRect(borderRadius: br, child: img);
  }

  Widget _placeholder(BorderRadius br) {
    return ClipRRect(
      borderRadius: br,
      child: Container(
        width: width, height: height,
        color: PosColors.surfaceAlt,
        child: const Center(
          child: Icon(Icons.fastfood_rounded,
              color: PosColors.textMuted),
        ),
      ),
    );
  }
}

// ============================================================
//  TABLE ROW
// ============================================================

class _TableRow extends StatelessWidget {
  final Map<String, dynamic> produk;
  final String Function(num)    formatRp;
  final String Function(String) catLabel;
  final String Function(String) catEmoji;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onHapus;
  final bool isLast;

  const _TableRow({
    required this.produk,
    required this.formatRp,
    required this.catLabel,
    required this.catEmoji,
    required this.onEdit,
    required this.onToggle,
    required this.onHapus,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final stock    = produk['stock'] as int? ?? 0;
    final isActive = stock > 0;
    final isLow    = stock > 0 && stock < 10;
    final cat      = produk['category'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft:  Radius.circular(PosRadius.lg),
                bottomRight: Radius.circular(PosRadius.lg),
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 14),
      child: Row(
        children: [
          ProdukImage(
            imageUrl:     produk['image_url'] as String?,
            width:        40, height: 40,
            borderRadius: BorderRadius.circular(PosRadius.sm),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 3,
            child: Text(produk['name'] as String? ?? '-',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: PosColors.textPrimary))),
          Expanded(flex: 2,
            child: Row(children: [
              Text(catEmoji(cat),
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(catLabel(cat),
                  style: const TextStyle(
                      fontSize: 13, color: PosColors.textSecondary)),
            ])),
          SizedBox(width: 110,
            child: Text(formatRp(produk['price'] as num? ?? 0),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, color: PosColors.textPrimary))),
          SizedBox(width: 70,
            child: Text('$stock',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: isLow
                        ? PosColors.warning
                        : PosColors.textPrimary))),
          SizedBox(width: 90, child: _StatusBadge(isActive: isActive)),
          SizedBox(width: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionBtn(icon: Icons.edit_rounded,
                    color: PosColors.info, bgColor: PosColors.infoBg,
                    onTap: onEdit, tooltip: 'Edit'),
                const SizedBox(width: 6),
                _ActionBtn(
                    icon: isActive
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                    color: isActive ? PosColors.success : PosColors.textMuted,
                    bgColor: isActive
                        ? PosColors.successBg
                        : PosColors.surfaceAlt,
                    onTap: onToggle,
                    tooltip: isActive ? 'Nonaktifkan' : 'Aktifkan'),
                const SizedBox(width: 6),
                _ActionBtn(icon: Icons.delete_rounded,
                    color: PosColors.error, bgColor: PosColors.errorBg,
                    onTap: onHapus, tooltip: 'Hapus'),
              ],
            )),
        ],
      ),
    );
  }
}

// ============================================================
//  MOBILE CARD
// ============================================================

class _MobileCard extends StatelessWidget {
  final Map<String, dynamic> produk;
  final String Function(num)    formatRp;
  final String Function(String) catLabel;
  final String Function(String) catEmoji;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onHapus;

  const _MobileCard({
    required this.produk,
    required this.formatRp,
    required this.catLabel,
    required this.catEmoji,
    required this.onEdit,
    required this.onToggle,
    required this.onHapus,
  });

  @override
  Widget build(BuildContext context) {
    final stock    = produk['stock'] as int? ?? 0;
    final isActive = stock > 0;
    final isLow    = stock > 0 && stock < 10;
    final cat      = produk['category'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: posCardDecoration(),
      child: Row(
        children: [
          ProdukImage(
            imageUrl:     produk['image_url'] as String?,
            width: 56, height: 56,
            borderRadius: BorderRadius.circular(PosRadius.md),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(produk['name'] as String? ?? '-',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: PosColors.textPrimary)),
                const SizedBox(height: 4),
                Row(children: [
                  Text(catEmoji(cat),
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(catLabel(cat),
                      style: const TextStyle(
                          fontSize: 12, color: PosColors.textSecondary)),
                  const SizedBox(width: 10),
                  Text(formatRp(produk['price'] as num? ?? 0),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: PosColors.primary)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  _StatusBadge(isActive: isActive),
                  const SizedBox(width: 8),
                  Text('Stok: $stock',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: isLow
                              ? PosColors.warning
                              : PosColors.textMuted)),
                ]),
              ],
            ),
          ),
          Column(
            children: [
              _ActionBtn(icon: Icons.edit_rounded,
                  color: PosColors.info, bgColor: PosColors.infoBg,
                  onTap: onEdit, tooltip: 'Edit'),
              const SizedBox(height: 6),
              _ActionBtn(
                  icon: isActive
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  color: isActive ? PosColors.success : PosColors.textMuted,
                  bgColor: isActive
                      ? PosColors.successBg
                      : PosColors.surfaceAlt,
                  onTap: onToggle,
                  tooltip: isActive ? 'Nonaktifkan' : 'Aktifkan'),
              const SizedBox(height: 6),
              _ActionBtn(icon: Icons.delete_rounded,
                  color: PosColors.error, bgColor: PosColors.errorBg,
                  onTap: onHapus, tooltip: 'Hapus'),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  FORM DIALOG — dengan Image Picker
// ============================================================

class _ProdukFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _ProdukFormDialog({
    required this.onSave,
    this.existing,
  });

  @override
  State<_ProdukFormDialog> createState() => _ProdukFormDialogState();
}

class _ProdukFormDialogState extends State<_ProdukFormDialog> {
  final _namaCtrl  = TextEditingController();
  final _hargaCtrl = TextEditingController();
  final _stokCtrl  = TextEditingController();
  String _kategori     = 'Base';
  String _imageUrl     = '';
  bool   _saving       = false;
  bool   _pickingImage = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.existing!;
      _namaCtrl.text  = e['name']  as String? ?? '';
      _hargaCtrl.text = (e['price'] as num?)?.toString() ?? '';
      _stokCtrl.text  = (e['stock'] as int?)?.toString() ?? '';
      _kategori       = e['category'] as String? ?? 'Base';
      _imageUrl       = e['image_url'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _hargaCtrl.dispose();
    _stokCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _pickingImage = true);
    try {
      final path = source == ImageSource.gallery
          ? await ImageService.instance.pickFromGallery()
          : await ImageService.instance.pickFromCamera();

      if (path != null && mounted) {
        // Hapus foto lama kalau file lokal
        if (_isEdit) {
          await ImageService.instance
              .deleteIfLocal(widget.existing!['image_url'] as String?);
        }
        setState(() => _imageUrl = path);
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: PosColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(PosRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: PosColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Pilih Sumber Foto',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: PosColors.textPrimary)),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: PosColors.infoBg,
                  borderRadius: BorderRadius.circular(PosRadius.md),
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: PosColors.info, size: 20),
              ),
              title: const Text('Pilih dari Galeri',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Buka foto dari galeri HP',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: PosColors.successBg,
                  borderRadius: BorderRadius.circular(PosRadius.md),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: PosColors.success, size: 20),
              ),
              title: const Text('Ambil Foto',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Langsung foto pakai kamera',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_imageUrl.isNotEmpty)
              ListTile(
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: PosColors.errorBg,
                    borderRadius: BorderRadius.circular(PosRadius.md),
                  ),
                  child: const Icon(Icons.delete_rounded,
                      color: PosColors.error, size: 20),
                ),
                title: const Text('Hapus Foto',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: PosColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _imageUrl = '');
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Di _ProdukFormDialogState, ubah _save method:
  Future<void> _save() async {
    if (_namaCtrl.text.trim().isEmpty || _hargaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan harga wajib diisi'), backgroundColor: PosColors.error),
      );
      return;
    }
    setState(() => _saving = true);
    
    // Jika kategori Pedas, set stok besar dan hapus foto
    final isPedas = _kategori == 'Pedas';
    
    await widget.onSave({
      'name': _namaCtrl.text.trim(),
      'category': _kategori,
      'price': double.tryParse(_hargaCtrl.text) ?? 0.0,
      'stock': isPedas ? 999999 : (int.tryParse(_stokCtrl.text) ?? 0), // Unlimited untuk pedas
      'image_url': isPedas ? '' : _imageUrl, // No foto untuk pedas
    });
    
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isPedas = _kategori == 'Pedas';

    return Dialog(
      backgroundColor: PosColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadius.xl)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? 'Edit Produk' : 'Tambah Produk',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: PosColors.textPrimary,
                    letterSpacing: -0.3),
              ),
              const SizedBox(height: 20),

              // ── Foto ───────────────────────────────────────
              if (!isPedas) ...[
                _label('Foto Produk'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickingImage ? null : _showImageSourceSheet,
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: PosColors.surfaceAlt,
                      borderRadius:
                          BorderRadius.circular(PosRadius.lg),
                      border: Border.all(
                        color: _imageUrl.isNotEmpty
                            ? PosColors.primary
                            : PosColors.border,
                        width: _imageUrl.isNotEmpty ? 2 : 1.5,
                      ),
                    ),
                    child: _pickingImage
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: PosColors.primary))
                        : _imageUrl.isNotEmpty
                            ? _imagePreview()
                            : _imagePlaceholder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Nama ───────────────────────────────────────
              _label('Nama Produk'),
              const SizedBox(height: 6),
              _field(controller: _namaCtrl,
                  hint: 'Contoh: Mie Kuning'),
              const SizedBox(height: 16),

              // ── Kategori ───────────────────────────────────
              _label('Kategori'),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: PosColors.surface,
                  borderRadius: BorderRadius.circular(PosRadius.md),
                  border: Border.all(color: PosColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value:      _kategori,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14),
                    borderRadius:
                        BorderRadius.circular(PosRadius.md),
                    items: ['Base', 'Topping', 'Sayur', 'Pedas', 'Minuman']
                        .map((k) => DropdownMenuItem(
                              value: k,
                              child: Text(k,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: PosColors.textPrimary)),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _kategori = v!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Harga & Stok ───────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Harga (Rp)'),
                        const SizedBox(height: 6),
                        _field(controller: _hargaCtrl,
                            hint: '0',
                            type: TextInputType.number),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Stok'),
                        const SizedBox(height: 6),
                        _field(controller: _stokCtrl,
                            hint: '0',
                            type: TextInputType.number),
                      ],
                    ),
                  ),
                ],
              ),

              if (isPedas) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: PosColors.warningBg,
                    borderRadius: BorderRadius.circular(PosRadius.md),
                    border: Border.all(
                        color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: PosColors.warning),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kategori Level Pedas tidak butuh foto',
                          style: TextStyle(
                              fontSize: 12,
                              color: PosColors.warning),
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
                      onPressed:
                          _saving ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(_isEdit ? 'Simpan' : 'Tambah'),
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

  Widget _imagePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(PosRadius.lg - 2),
          child: ImageService.isLocalFile(_imageUrl)
              ? Image.file(File(_imageUrl), fit: BoxFit.cover)
              : Image.asset(_imageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _imagePlaceholder()),
        ),
        Positioned(
          bottom: 8, right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(PosRadius.md),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded,
                    color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text('Ganti Foto',
                    style: TextStyle(
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_rounded,
            size: 40, color: PosColors.textMuted),
        SizedBox(height: 10),
        Text('Tap untuk tambah foto',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: PosColors.textSecondary)),
        SizedBox(height: 4),
        Text('Galeri atau kamera',
            style: TextStyle(
                fontSize: 11, color: PosColors.textMuted)),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: PosColors.textSecondary));

  Widget _field({
    required TextEditingController controller,
    String? hint,
    TextInputType type = TextInputType.text,
  }) =>
      TextField(
        controller:   controller,
        keyboardType: type,
        style: const TextStyle(
            fontSize: 14, color: PosColors.textPrimary),
        decoration: InputDecoration(
          hintText:  hint,
          fillColor: PosColors.surface,
          filled:    true,
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

// ============================================================
//  CONFIRM DIALOG
// ============================================================

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PosColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: PosColors.errorBg,
                  borderRadius: BorderRadius.circular(PosRadius.xl)),
              child: const Icon(Icons.delete_rounded,
                  color: PosColors.error, size: 26),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: PosColors.textPrimary)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: PosColors.textSecondary)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: onCancel,
                        child: const Text('Batal'))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: PosColors.error),
                    child: const Text('Hapus'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  SMALL WIDGETS
// ============================================================

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? PosColors.successBg : PosColors.surfaceAlt,
        borderRadius: BorderRadius.circular(PosRadius.xxl),
        border: Border.all(
          color: isActive
              ? const Color(0xFF9AE6B4)
              : PosColors.border,
        ),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Nonaktif',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: isActive ? PosColors.success : PosColors.textMuted),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final Color    bgColor;
  final VoidCallback onTap;
  final String   tooltip;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(PosRadius.sm)),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final bool   right;
  const _HeaderCell(this.text, {this.right = false});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: PosColors.textMuted, letterSpacing: 0.3));
  }
}