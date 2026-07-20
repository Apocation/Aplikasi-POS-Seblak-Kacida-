import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class ExportService {
  static Future<File?> exportOrdersToCSV(DateTime? startDate, DateTime? endDate) async {
    try {
      final db = DatabaseHelper.instance;
      List<Map<String, dynamic>> orders;
      
      if (startDate != null && endDate != null) {
        orders = await db.getOrdersByDateRange(startDate, endDate);
      } else {
        orders = await db.getOrders();
      }
      
      if (orders.isEmpty) {
        return null;
      }
      
      final buffer = StringBuffer();
      buffer.writeln('No Order,Tanggal,Total,Pembayaran,Status,Pelanggan,Catatan');
      
      for (final order in orders) {
        final id = order['id'] as String? ?? '';
        final date = order['created_at'] as String? ?? '';
        final total = order['total_price'] as num? ?? 0;
        final method = order['payment_method'] as String? ?? '';
        final status = order['status'] as String? ?? '';
        final customer = order['customer_name'] as String? ?? 'Pelanggan';
        final note = order['note'] as String? ?? '';
        
        buffer.writeln('"$id","$date",$total,"$method","$status","$customer","$note"');
      }
      
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'laporan_${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}.csv';
      final file = File('${appDir.path}/$fileName');
      await file.writeAsString(buffer.toString());
      
      return file;
    } catch (e) {
      debugPrint('Export error: $e');
      return null;
    }
  }
  
  static Future<File?> exportProductsToCSV() async {
    try {
      final products = await DatabaseHelper.instance.getProducts();
      
      if (products.isEmpty) return null;
      
      final buffer = StringBuffer();
      buffer.writeln('Nama Produk,Kategori,Harga,Stok');
      
      for (final product in products) {
        final name = product['name'] as String? ?? '';
        final category = product['category'] as String? ?? '';
        final price = product['price'] as num? ?? 0;
        final stock = product['stock'] as int? ?? 0;
        
        buffer.writeln('"$name","$category",$price,$stock');
      }
      
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'produk_${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}.csv';
      final file = File('${appDir.path}/$fileName');
      await file.writeAsString(buffer.toString());
      
      return file;
    } catch (e) {
      debugPrint('Export products error: $e');
      return null;
    }
  }
  
  static Future<void> shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Laporan Seblak Kacida',
    );
  }
}