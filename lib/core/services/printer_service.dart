import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class PrinterService {
  static bool _connected = false;
  static String? _connectedName;
  static String? _connectedAddress;

  // ==================== AMBIL DAFTAR PRINTER ====================
  static Future<List<Map<String, dynamic>>> getBondedDevices() async {
    try {
      final List<BluetoothInfo> devices =
          await PrintBluetoothThermal.pairedBluetooths;

      List<Map<String, dynamic>> result = [];
      for (var device in devices) {
        result.add({
          'name': device.name,
          'address': device.macAdress, // typo dari package-nya, memang 'macAdress'
        });
      }
      return result;
    } catch (e) {
      debugPrint('Get devices error: $e');
      return [];
    }
  }

  // ==================== KONEK PRINTER ====================
  static Future<bool> connect(String macAddress, String printerName) async {
    try {
      final bool success =
          await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      _connected = success;
      if (_connected) {
        _connectedAddress = macAddress;
        _connectedName = printerName;
        await Future.delayed(const Duration(milliseconds: 500));
      }
      return _connected;
    } catch (e) {
      debugPrint('Connect error: $e');
      return false;
    }
  }

  // ==================== CEK KONEKSI ====================
  static Future<bool> checkConnection() async {
    try {
      final bool status = await PrintBluetoothThermal.connectionStatus;
      _connected = status;
      return _connected;
    } catch (e) {
      return false;
    }
  }

  // ==================== DISKONEK ====================
  static Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
      _connected = false;
      _connectedName = null;
      _connectedAddress = null;
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }

  // ==================== FUNGSI CETAK (SEDERHANA) ====================
  static Future<bool> printText(String text) async {
    if (!_connected) return false;
    try {
      final bool result =
          await PrintBluetoothThermal.writeBytes(text.codeUnits);
      return result;
    } catch (e) {
      debugPrint('Print text error: $e');
      return false;
    }
  }

  // ==================== CETAK STRUK ====================
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
    if (!_connected) {
      await checkConnection();
      if (!_connected) return false;
    }

    try {
      StringBuffer buffer = StringBuffer();

      buffer.writeln('===============================');
      buffer.writeln('        SEBLAK KACIDA         ');
      buffer.writeln('===============================');
      buffer.writeln();
      buffer.writeln('No Order : $invoiceNo');
      buffer.writeln('Pemesan  : ${pemesan.isEmpty ? 'Pelanggan' : pemesan}');
      buffer.writeln('Metode   : ${metode == 'Cash' ? 'TUNAI' : 'QRIS'}');
      buffer.writeln('Waktu    : ${DateTime.now().toString().substring(0, 19)}');
      if (catatan.isNotEmpty) {
        buffer.writeln('Catatan  : $catatan');
      }
      buffer.writeln('-------------------------------');
      buffer.writeln('Item           Qty   Harga');
      buffer.writeln('-------------------------------');

      for (var item in items) {
        String name = item['name'] ?? '';
        int qty = item['qty'] ?? 1;
        double price = (item['price'] ?? 0).toDouble();
        double subtotal = price * qty;

        String nameDisplay = name;
        if (nameDisplay.length > 15) {
          nameDisplay = nameDisplay.substring(0, 12) + '...';
        }

        buffer.writeln(
            '${nameDisplay.padRight(15)} ${qty.toString().padLeft(3)}   ${_formatPrice(price)}');
        buffer.writeln('     Subtotal: ${_formatPrice(subtotal)}');
      }

      buffer.writeln('-------------------------------');
      buffer.writeln('TOTAL: ${_formatPrice(total)}');

      if (metode == 'Cash') {
        buffer.writeln('BAYAR: ${_formatPrice(bayar)}');
        buffer.writeln('KEMBALI: ${_formatPrice(kembalian)}');
      }

      buffer.writeln();
      buffer.writeln('   Terima kasih!');
      buffer.writeln('     Seblak Kacida');
      buffer.writeln('===============================');
      buffer.writeln();
      buffer.writeln();

      final bool result =
          await PrintBluetoothThermal.writeBytes(buffer.toString().codeUnits);
      return result;
    } catch (e) {
      debugPrint('Print receipt error: $e');
      return false;
    }
  }

  // ==================== TEST PRINT ====================
  static Future<bool> printTest() async {
    if (!_connected) return false;

    try {
      StringBuffer buffer = StringBuffer();
      buffer.writeln('===============================');
      buffer.writeln('          TEST PRINT           ');
      buffer.writeln('===============================');
      buffer.writeln('Printer: $_connectedName');
      buffer.writeln('Waktu: ${DateTime.now()}');
      buffer.writeln('===============================');
      buffer.writeln('   Printer Eco 58D Ready!');
      buffer.writeln('===============================');
      buffer.writeln();
      buffer.writeln();

      final bool result =
          await PrintBluetoothThermal.writeBytes(buffer.toString().codeUnits);
      return result;
    } catch (e) {
      debugPrint('Test print error: $e');
      return false;
    }
  }

  static String _formatPrice(double price) {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        )}';
  }

  static String formatRupiah(double price) {
    return _formatPrice(price);
  }

  // ==================== GETTER ====================
  static bool get isPrinterConnected => _connected;
  static String? get connectedPrinter => _connectedName;
}