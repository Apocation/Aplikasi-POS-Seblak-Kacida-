import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/database/database_helper.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _loading = true;
  bool _saving  = false;

  final _storeNameCtrl = TextEditingController();
  final _addressCtrl   = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _taxCtrl       = TextEditingController();
  final _discountCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _taxCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await DatabaseHelper.instance.getSettings();
      if (!mounted) return;
      setState(() {
        _storeNameCtrl.text = data['store_name']    as String? ?? '';
        _addressCtrl.text   = data['store_address'] as String? ?? '';
        _phoneCtrl.text     = data['store_phone']   as String? ?? '';
        _taxCtrl.text       = (data['tax_rate']      ?? 0.0).toString();
        _discountCtrl.text  = (data['discount_rate'] ?? 0.0).toString();
        _loading            = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('Gagal memuat pengaturan: $e', isError: true);
    }
  }

  Future<void> _save() async {
    if (_storeNameCtrl.text.trim().isEmpty) {
      _showSnack('Nama toko tidak boleh kosong', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await DatabaseHelper.instance.updateSettings({
        'store_name':    _storeNameCtrl.text.trim(),
        'store_address': _addressCtrl.text.trim(),
        'store_phone':   _phoneCtrl.text.trim(),
        'tax_rate':      double.tryParse(_taxCtrl.text)     ?? 0.0,
        'discount_rate': double.tryParse(_discountCtrl.text) ?? 0.0,
      });
      if (!mounted) return;
      _showSnack('Pengaturan berhasil disimpan ✓');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal menyimpan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        icon:         Icons.warning_amber_rounded,
        iconBg:       PosColors.warningBg,
        iconColor:    PosColors.warning,
        title:        'Reset Database?',
        message:
            'Semua data transaksi, produk, dan pengaturan akan dihapus permanen. Data tidak dapat dikembalikan.',
        confirmLabel: 'Reset Sekarang',
        confirmColor: PosColors.error,
        onConfirm: () async {
          Navigator.pop(ctx);
          setState(() => _loading = true);
          await DatabaseHelper.instance.resetDatabase();
          await _load();
          if (mounted) _showSnack('Database berhasil direset');
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? PosColors.error : PosColors.success,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadius.md)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final pad      = isMobile ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: PosColors.primary))
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pad, 20, pad, 32),
                child: isMobile
                    ? _mobileLayout()
                    : _tabletLayout(),
              ),
      ),
    );
  }

  Widget _tabletLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(children: [
                _buildStoreSection(),
                const SizedBox(height: 16),
                _buildFinancialSection(),
                const SizedBox(height: 16),
                _buildSheetsSection(),
              ]),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: Column(children: [
                _buildAppInfoSection(),
                const SizedBox(height: 16),
                _buildDangerSection(),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSaveButton(),
      ],
    );
  }

  Widget _mobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        _buildStoreSection(),
        const SizedBox(height: 16),
        _buildFinancialSection(),
        const SizedBox(height: 16),
        _buildSheetsSection(),
        const SizedBox(height: 16),
        _buildAppInfoSection(),
        const SizedBox(height: 16),
        _buildDangerSection(),
        const SizedBox(height: 24),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('⚙️ ', style: TextStyle(fontSize: 22)),
          Text('Pengaturan',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: PosColors.textPrimary, letterSpacing: -0.4)),
        ]),
        SizedBox(height: 4),
        Text('Konfigurasi toko dan sistem',
            style: TextStyle(
                fontSize: 13, color: PosColors.textSecondary)),
      ],
    );
  }

  Widget _buildStoreSection() {
    return _Section(
      title: 'Informasi Toko',
      icon:  Icons.store_rounded,
      children: [
        _FieldRow(label: 'Nama Toko',
            controller: _storeNameCtrl,
            hint: 'Seblak Kacida',
            icon: Icons.storefront_rounded),
        const SizedBox(height: 14),
        _FieldRow(label: 'Alamat',
            controller: _addressCtrl,
            hint: 'Jl. Contoh No. 123',
            icon: Icons.location_on_rounded,
            maxLines: 2),
        const SizedBox(height: 14),
        _FieldRow(label: 'No. Telepon',
            controller: _phoneCtrl,
            hint: '+62 812-3456-7890',
            icon: Icons.phone_rounded,
            type: TextInputType.phone),
      ],
    );
  }

  Widget _buildFinancialSection() {
    return _Section(
      title: 'Pengaturan Keuangan',
      icon:  Icons.calculate_rounded,
      children: [
        Row(children: [
          Expanded(
            child: _FieldRow(
                label: 'Pajak (%)',
                controller: _taxCtrl,
                hint: '0',
                icon: Icons.percent_rounded,
                type: TextInputType.number),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _FieldRow(
                label: 'Diskon Default (%)',
                controller: _discountCtrl,
                hint: '0',
                icon: Icons.discount_rounded,
                type: TextInputType.number),
          ),
        ]),
      ],
    );
  }

  Widget _buildSheetsSection() {
    return _Section(
      title: 'Backup (Lokal)',
      icon: Icons.cloud_off_rounded,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PosColors.infoBg,
            borderRadius: BorderRadius.circular(PosRadius.md),
            border: Border.all(color: const Color(0xFF90CDF4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.cloud_off_rounded, 
                    color: PosColors.info, size: 18),
                const SizedBox(width: 12),
                const Expanded(child: Text(
                  'Backup Lokal Aktif',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                )),
              ]),
              const SizedBox(height: 12),
              const Text(
                'Semua data tersimpan aman di SQLite lokal. Fitur Google Sheets dinonaktifkan.',
                style: TextStyle(fontSize: 12, color: PosColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppInfoSection() {
    return _Section(
      title: 'Informasi Aplikasi',
      icon:  Icons.info_rounded,
      children: [
        _InfoTile(icon: Icons.restaurant_rounded,
            label: 'Aplikasi', value: 'Seblak POS'),
        const Divider(height: 20),
        _InfoTile(icon: Icons.tag_rounded,
            label: 'Versi', value: 'v1.0.0'),
        const Divider(height: 20),
        _InfoTile(icon: Icons.storage_rounded,
            label: 'Database', value: 'SQLite (Lokal)'),
        const Divider(height: 20),
        _InfoTile(icon: Icons.cloud_done_rounded,
            label: 'Backup', value: 'Lokal ✓'),
        const Divider(height: 20),
        _InfoTile(icon: Icons.build_rounded,
            label: 'Framework', value: 'Flutter'),
      ],
    );
  }

  Widget _buildDangerSection() {
    return Container(
      decoration: BoxDecoration(
        color:        PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadius.lg),
        border: Border.all(
            color: const Color(0xFFFEB2B2), width: 1.5),
        boxShadow: const [PosShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color:        PosColors.errorBg,
                  borderRadius: BorderRadius.circular(PosRadius.sm),
                ),
                child: const Icon(Icons.warning_rounded,
                    size: 16, color: PosColors.error),
              ),
              const SizedBox(width: 10),
              const Text('Zona Berbahaya',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: PosColors.error)),
            ]),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reset Database',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: PosColors.textPrimary)),
                const SizedBox(height: 4),
                const Text(
                  'Hapus semua data transaksi dan produk. '
                  'Aksi ini tidak dapat dibatalkan.',
                  style: TextStyle(
                      fontSize: 12, color: PosColors.textSecondary,
                      height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _confirmReset,
                    icon:  const Icon(
                        Icons.delete_forever_rounded, size: 16),
                    label: const Text('Reset Database'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PosColors.error,
                      side: const BorderSide(
                          color: PosColors.error, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_rounded, size: 18),
        label: Text(_saving ? 'Menyimpan...' : 'Simpan Pengaturan'),
        style: ElevatedButton.styleFrom(
          backgroundColor: PosColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 15),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Status Chip ───────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String   label;
  final Color    color;
  final Color    bgColor;
  final Color    border;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.border,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(PosRadius.xxl),
        border:       Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

// ── Section ───────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String       title;
  final IconData     icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: posCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: PosColors.primaryBg,
                  borderRadius: BorderRadius.circular(PosRadius.sm),
                ),
                child: Icon(icon, size: 16, color: PosColors.primary),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: PosColors.textPrimary)),
            ]),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Field Row ─────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final String               label;
  final TextEditingController controller;
  final String?              hint;
  final IconData?            icon;
  final TextInputType        type;
  final int                  maxLines;

  const _FieldRow({
    required this.label,
    required this.controller,
    this.hint, this.icon,
    this.type     = TextInputType.text,
    this.maxLines = 1,
  });

@override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: PosColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller:   controller,
          keyboardType: type,
          maxLines:     maxLines,
          style: const TextStyle(
              fontSize: 14, color: PosColors.textPrimary),
          decoration: InputDecoration(
            hintText:   hint,
            prefixIcon: icon != null
                ? Icon(icon, size: 18, color: PosColors.textMuted)
                : null,
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
        ),
      ],
    );
  }
}

// ── Info Tile ─────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

@override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color:        PosColors.surfaceAlt,
          borderRadius: BorderRadius.circular(PosRadius.sm),
        ),
        child: Icon(icon, size: 16, color: PosColors.textSecondary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(label,
            style: const TextStyle(
                fontSize: 13, color: PosColors.textSecondary)),
      ),
      Text(value,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: PosColors.textPrimary)),
    ]);
  }
}

// ── Confirm Dialog ────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final IconData     icon;
  final Color        iconBg;
  final Color        iconColor;
  final String       title;
  final String       message;
  final String       confirmLabel;
  final Color        confirmColor;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmDialog({
    required this.icon,     required this.iconBg,
    required this.iconColor,required this.title,
    required this.message,  required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,required this.onCancel,
  });

@override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PosColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadius.xl)),
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 32, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(PosRadius.xl)),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    color: PosColors.textPrimary,
                    letterSpacing: -0.3),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(
                    fontSize: 13, color: PosColors.textSecondary,
                    height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Batal')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor),
                  child: Text(confirmLabel),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
