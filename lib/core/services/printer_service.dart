
import 'package:flutter/material.dart';
import 'package:bluetooth_print/bluetooth_print.dart';

class PrinterService {
  static BluetoothPrint? _printer;
  static bool _connected = false;
  static String? _connectedName;

  static Future<void> init() async {
    _printer = BluetoothPrint.instance;
  }

  static Stream<List<BluetoothDevice>> get scanStream => _printer!.scanResults;

  static Future<List<BluetoothDevice>> getBondedDevices() async {
    return await _printer!.getBondedDevices();
  }

  static Future<bool> connect(BluetoothDevice device) async {
    try {
      final success = await _printer!.connect(device, model: true);
      _connected = success;
      _connectedName = device.name ?? device.address;
      return success;
    } catch (e) {
      debugPrint('Connect error: $e');
      return false;
    }
  }

  static Future<bool> disconnect() async {
    final success = await _printer!.disconnect();
    _connected = false;
    _connectedName = null;
    return success ?? false;
  }

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
    if (!_connected || _printer == null) return false;

    List<LineText> lines = [
      LineText(type: LineTextType.title, content: 'SEBLAK KACIDA'),
      LineText(type: LineTextType.title, content: '==============='),
      LineText(type: LineTextType.normal, content: 'No. Order: $invoiceNo'),
      LineText(type: LineTextType.normal, content: 'Pemesan: $pemesan'),
      LineText(type: LineTextType.normal, content: 'Metode: $metode'),
      if (catatan.isNotEmpty) LineText(type: LineTextType.normal, content: 'Catatan: $catatan'),
      LineText(type: LineTextType.title, content: '---------------'),
      LineText(type: LineTextType.normal, content: 'Item        Hrg    Qty   Total'),
      LineText(type: LineTextType.title, content: '---------------'),
    ];

    for (var item in items) {
      String name = item['name'] ?? '';
      double price = (item['price'] ?? 0).toDouble();
      int qty = item['qty'] ?? 1;
      double sub = price * qty;
      lines.add(LineText(
        type: LineTextType.normal,
        content: '${name.padRight(12)} Rp${price.toInt()} x$qty  Rp${sub.toInt()}',
      ));
    }

    lines.addAll([
      LineText(type: LineTextType.title, content: '---------------'),
      LineText(type: LineTextType.normal, content: 'TOTAL'.padRight(20) + 'Rp${total.toInt()}'),
      LineText(type: LineTextType.normal, content: 'Bayar'.padRight(20) + 'Rp${bayar.toInt()}'),
      LineText(type: LineTextType.normal, content: 'Kembali'.padRight(20) + 'Rp${kembalian.toInt()}'),
      LineText(type: LineTextType.normal, content: ''),
      LineText(type: LineTextType.normal, content: 'Terima kasih! 🌶️'),
      LineText(type: LineTextType.normal, content: 'Seblak Kacida POS'),
      LineText(type: LineTextType.normal, content: ''),
    ]);

    try {
      final result = await _printer!.printCustom(lines, [80], [1]);
      return result == 1;
    } catch (e) {
      debugPrint('Print error: $e');
      return false;
    }
  }

  static bool get isPrinterConnected => _connected;
  static String? get connectedPrinter => _connectedName;
}

