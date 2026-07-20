import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService {
  static bool _connected = false;
  static String? _connectedName;
  static String? _connectedAddress;
  static bool _busy = false; // cegah connect/print bertumpuk

  static const String _keyLastMac = 'last_printer_mac';
  static const String _keyLastName = 'last_printer_name';
  static const Duration _connectTimeout = Duration(seconds: 10);

  // ==================== KONEK DENGAN RETRY & TIMEOUT ====================
  static Future<bool> _connectWithRetry(String mac, {int retries = 2}) async {
    for (int attempt = 1; attempt <= retries + 1; attempt++) {
      try {
        final bool success = await PrintBluetoothThermal.connect(
          macPrinterAddress: mac,
        ).timeout(_connectTimeout, onTimeout: () => false);

        if (success) {
          // Beri waktu koneksi stabil, lalu verifikasi status sesungguhnya
          await Future.delayed(const Duration(milliseconds: 800));
          final verified = await PrintBluetoothThermal.connectionStatus
              .timeout(const Duration(seconds: 3), onTimeout: () => false);
          if (verified) return true;
          debugPrint('[Printer] Konek dilaporkan sukses tapi verifikasi gagal (percobaan $attempt)');
        } else {
          debugPrint('[Printer] Konek gagal (percobaan $attempt)');
        }
      } catch (e) {
        debugPrint('[Printer] Connect error percobaan $attempt: $e');
      }

      if (attempt <= retries) {
        // Pastikan koneksi lama benar-benar tertutup sebelum retry
        try {
          await PrintBluetoothThermal.disconnect;
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return false;
  }

  // ==================== AUTO RECONNECT ====================
  static Future<bool> autoReconnect() async {
    if (_busy) return _connected;
    _busy = true;
    try {
      final btEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!btEnabled) {
        debugPrint('[Printer] Bluetooth tidak aktif, skip auto reconnect');
        _connected = false;
        return false;
      }

      // Kalau sudah terhubung beneran, tidak perlu reconnect
      final already = await PrintBluetoothThermal.connectionStatus
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      if (already) {
        _connected = true;
        return true;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastMac = prefs.getString(_keyLastMac);
      final lastName = prefs.getString(_keyLastName);

      if (lastMac == null || lastMac.isEmpty) {
        debugPrint('[Printer] Tidak ada printer tersimpan');
        _connected = false;
        return false;
      }

      debugPrint('[Printer] Auto reconnect ke: $lastName ($lastMac)');
      _connected = await _connectWithRetry(lastMac);

      if (_connected) {
        _connectedAddress = lastMac;
        _connectedName = lastName;
        debugPrint('[Printer] Auto reconnect BERHASIL: $_connectedName');
      } else {
        debugPrint('[Printer] Auto reconnect GAGAL');
      }

      return _connected;
    } catch (e) {
      debugPrint('[Printer] Auto reconnect error: $e');
      _connected = false;
      return false;
    } finally {
      _busy = false;
    }
  }

  // ==================== AMBIL DAFTAR PRINTER ====================
  static Future<List<Map<String, dynamic>>> getBondedDevices() async {
    try {
      final bool btEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!btEnabled) {
        debugPrint('[Printer] Bluetooth tidak aktif');
        return [];
      }

      final List<BluetoothInfo> devices =
          await PrintBluetoothThermal.pairedBluetooths;

      final List<Map<String, dynamic>> result = [];
      for (var device in devices) {
        result.add({
          'name': device.name,
          'address': device.macAdress,
        });
      }

      debugPrint('[Printer] Ditemukan ${result.length} printer');
      return result;
    } catch (e) {
      debugPrint('[Printer] Get devices error: $e');
      return [];
    }
  }

  // ==================== CEK BLUETOOTH AKTIF ====================
  static Future<bool> isBluetoothEnabled() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      debugPrint('[Printer] Bluetooth check error: $e');
      return false;
    }
  }

  // ==================== KONEK PRINTER ====================
  static Future<bool> connect(String macAddress, String printerName) async {
    if (_busy) {
      debugPrint('[Printer] Sedang ada proses lain, tunggu...');
      return false;
    }
    _busy = true;
    try {
      debugPrint('[Printer] Menghubungkan ke: $printerName ($macAddress)');

      _connected = await _connectWithRetry(macAddress);

      if (_connected) {
        _connectedAddress = macAddress;
        _connectedName = printerName;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyLastMac, macAddress);
        await prefs.setString(_keyLastName, printerName);

        debugPrint('[Printer] Konek BERHASIL: $_connectedName');
      } else {
        debugPrint('[Printer] Konek GAGAL');
      }

      return _connected;
    } catch (e) {
      debugPrint('[Printer] Connect error: $e');
      _connected = false;
      return false;
    } finally {
      _busy = false;
    }
  }

  // ==================== CEK STATUS KONEKSI ====================
  static Future<bool> checkConnection() async {
    try {
      final bool status = await PrintBluetoothThermal.connectionStatus
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      _connected = status;
      debugPrint('[Printer] Status koneksi: $_connected');
      return _connected;
    } catch (e) {
      debugPrint('[Printer] Check connection error: $e');
      _connected = false;
      return false;
    }
  }

  // ==================== DISKONEK ====================
  static Future<void> disconnect() async {
    try {
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}
      _connected = false;
      _connectedName = null;
      _connectedAddress = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastMac);
      await prefs.remove(_keyLastName);

      debugPrint('[Printer] Disconnected & printer terhapus dari memori');
    } catch (e) {
      debugPrint('[Printer] Disconnect error: $e');
    }
  }

  // ==================== LUPAKAN PRINTER ====================
  static Future<void> forgetPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastMac);
      await prefs.remove(_keyLastName);
      debugPrint('[Printer] Printer terlupakan dari SharedPreferences');
    } catch (e) {
      debugPrint('[Printer] Forget printer error: $e');
    }
  }

  // ==================== AMBIL NAMA PRINTER TERSIMPAN ====================
  static Future<String?> getSavedPrinterName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLastName);
    } catch (e) {
      return null;
    }
  }

  // ==================== HELPER: TULIS BYTES PER CHUNK ====================
  // Printer thermal murah sering drop kalau dikirim data besar sekaligus.
  // Kirim per 512 byte dengan jeda kecil supaya buffer printer tidak penuh.
  static Future<bool> _writeChunked(List<int> bytes) async {
    const chunkSize = 512;
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      final ok = await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end));
      if (!ok) return false;
      await Future.delayed(const Duration(milliseconds: 60));
    }
    return true;
  }

  // ==================== HELPER: PASTIKAN SIAP CETAK ====================
  static Future<bool> _ensureReady() async {
    final ok = await checkConnection();
    if (ok) return true;
    debugPrint('[Printer] Tidak terhubung, coba auto reconnect...');
    return await autoReconnect();
  }

  // ==================== CETAK TEKS SEDERHANA ====================
  static Future<bool> printText(String text) async {
    if (!await _ensureReady()) return false;
    try {
      return await _writeChunked(text.codeUnits);
    } catch (e) {
      debugPrint('[Printer] Print text error: $e');
      _connected = false;
      return false;
    }
  }

  // ==================== CETAK STRUK DENGAN KATEGORI ====================
  static Future<bool> printReceipt({
    required String invoiceNo,
    required String pemesan,
    required String metode,
    required double total,
    required double bayar,
    required double kembalian,
    required List<Map<String, dynamic>> items,
    String catatan = '',
  }) async {
    if (!await _ensureReady()) return false;

    try {
      final StringBuffer buffer = StringBuffer();

      // ── HEADER ──────────────────────────────────────────
      buffer.writeln('================================');
      buffer.writeln(_center('SEBLAK KACIDA'));
      buffer.writeln('================================');
      buffer.writeln();
      buffer.writeln('No Order : $invoiceNo');
      buffer.writeln('Pemesan  : ${pemesan.isEmpty ? 'Pelanggan' : pemesan}');
      buffer.writeln('Metode   : ${metode == 'Cash' ? 'TUNAI' : 'QRIS'}');
      buffer.writeln('Waktu    : ${_formatDateTime(DateTime.now())}');
      if (catatan.isNotEmpty) {
        buffer.writeln('Catatan  : $catatan');
      }

      // ── PISAHKAN ITEMS PER KATEGORI ──────────────────────
      buffer.writeln('--------------------------------');
      
      // Kelompokkan items berdasarkan kategori
      final Map<String, List<Map<String, dynamic>>> groupedItems = {};
      
      for (var item in items) {
        String category = item['category'] as String? ?? 'Lainnya';
        
        // Mapping kategori ke tampilan yang lebih rapi
        String displayCategory;
        switch (category) {
          case 'Base':
            displayCategory = 'BASE SEBLAK';
            break;
          case 'Topping':
            displayCategory = 'TOPPING';
            break;
          case 'Sayur':
            displayCategory = 'SAYUR';
            break;
          case 'Pedas':
            displayCategory = 'LEVEL PEDAS';
            break;
          case 'Minuman':
            displayCategory = 'MINUMAN';
            break;
          default:
            displayCategory = '🍽️ $category';
        }
        
        groupedItems.putIfAbsent(displayCategory, () => []);
        groupedItems[displayCategory]!.add(item);
      }
      
      // Cetak per kategori
      for (var entry in groupedItems.entries) {
        buffer.writeln();
        buffer.writeln(entry.key);
        buffer.writeln('-------------------------------');
        
        for (var item in entry.value) {
          final String name = item['name'] as String? ?? '';
          final int qty = item['qty'] as int? ?? 1;
          final double price = (item['price'] as num? ?? 0).toDouble();
          final double subtotal = price * qty;
          
          final String nameDisplay = name.length > 16 ? '${name.substring(0, 14)}..' : name;
          
          // Format: Nama (kiri), Qty (tengah), Harga (kanan)
          final String qtyStr = 'x$qty';
          final String totalStr = _formatPrice(subtotal);
          final int spaceNeeded = qtyStr.length + 1 + totalStr.length;
          final String namePad = nameDisplay.padRight(32 - spaceNeeded);
          
          buffer.writeln('$namePad$qtyStr $totalStr');
        }
      }
      
      // ── TOTAL ────────────────────────────────────────────
      buffer.writeln();
      buffer.writeln('--------------------------------');
      
      final String nilaiTotal = _formatPrice(total);
      buffer.writeln('${'TOTAL'.padRight(32 - nilaiTotal.length)}$nilaiTotal');

      if (metode == 'Cash') {
        final String nilaiBayar = _formatPrice(bayar);
        final String nilaiKembalian = _formatPrice(kembalian);
        buffer.writeln('${'BAYAR'.padRight(32 - nilaiBayar.length)}$nilaiBayar');
        buffer.writeln('${'KEMBALI'.padRight(32 - nilaiKembalian.length)}$nilaiKembalian');
      }

      // ── FOOTER ───────────────────────────────────────────
      buffer.writeln('================================');
      buffer.writeln(_center('Terima kasih sudah memesan!'));
      buffer.writeln(_center('Seblak Kacida'));
      buffer.writeln('================================');
      buffer.writeln();
      buffer.writeln();
      buffer.writeln();

      final bool result = await _writeChunked(buffer.toString().codeUnits);

      debugPrint('[Printer] Print receipt: ${result ? 'BERHASIL' : 'GAGAL'}');
      return result;
    } catch (e) {
      debugPrint('[Printer] Print receipt error: $e');
      _connected = false;
      return false;
    }
  }

  // ==================== TEST PRINT ====================
  static Future<bool> printTest() async {
    if (!await _ensureReady()) return false;

    try {
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('================================');
      buffer.writeln(_center('TEST PRINT'));
      buffer.writeln('================================');
      buffer.writeln('Printer : ${_connectedName ?? '-'}');
      buffer.writeln('MAC     : ${_connectedAddress ?? '-'}');
      buffer.writeln('Waktu   : ${_formatDateTime(DateTime.now())}');
      buffer.writeln('================================');
      buffer.writeln(_center('Printer Siap Digunakan!'));
      buffer.writeln('================================');
      buffer.writeln();
      buffer.writeln();
      buffer.writeln();

      final bool result = await _writeChunked(buffer.toString().codeUnits);

      debugPrint('[Printer] Test print: ${result ? 'BERHASIL' : 'GAGAL'}');
      return result;
    } catch (e) {
      debugPrint('[Printer] Test print error: $e');
      _connected = false;
      return false;
    }
  }

  // ==================== HELPER: CENTER TEXT ====================
  static String _center(String text, {int width = 32}) {
    if (text.length >= width) return text;
    final int padding = (width - text.length) ~/ 2;
    return text.padLeft(text.length + padding).padRight(width);
  }

  // ==================== HELPER: FORMAT HARGA ====================
  static String _formatPrice(double price) {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        )}';
  }

  static String formatRupiah(double price) => _formatPrice(price);

  // ==================== HELPER: FORMAT TANGGAL ====================
  static String _formatDateTime(DateTime dt) {
    final date = '${dt.day.toString().padLeft(2, '0')}'
        '-${dt.month.toString().padLeft(2, '0')}'
        '-${dt.year}';
    final time = '${dt.hour.toString().padLeft(2, '0')}'
        ':${dt.minute.toString().padLeft(2, '0')}'
        ':${dt.second.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  // ==================== GETTER ====================
  static bool get isPrinterConnected => _connected;
  static String? get connectedPrinter => _connectedName;
  static String? get connectedAddress => _connectedAddress;
}