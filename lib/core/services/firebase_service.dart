import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Batas tunggu operasi Firestore. Tanpa ini, saat internet mati
  /// Future dari set()/update() bisa menggantung tanpa pernah selesai.
  static const Duration _timeout = Duration(seconds: 15);

  // ==================== MAIN SYNC METHODS ====================

  /// Sync dua arah per-dokumen, TANPA pernah hapus-semua.
  /// Aman walau internet putus di tengah proses: operasi upsert per dokumen
  /// bersifat idempotent, tidak ada fase "hapus dulu baru tulis".
  static Future<void> syncAll() async {
    final pushOk = await pushToCloud();
    if (pushOk) {
      await pullFromCloud();
    } else {
      debugPrint('⚠️ Push gagal, pull dibatalkan agar data lokal aman');
    }
  }

  // ==================== ANTRIAN SYNC (transaksi belum ter-push) ====================

  /// Kirim ulang semua transaksi yang belum ter-push ke cloud (synced = 0).
  /// Dipanggil berkala oleh SyncService dan saat internet kembali.
  /// Return jumlah transaksi yang berhasil di-push.
  static Future<int> syncPendingTransactions() async {
    try {
      final pending = await DatabaseHelper.instance.getUnsyncedOrders();
      if (pending.isEmpty) return 0;

      debugPrint('🔄 Ada ${pending.length} transaksi belum ter-sync, kirim ulang...');
      int success = 0;
      for (final order in pending) {
        final ok = await pushSingleTransaction(order['id'].toString());
        if (ok) {
          success++;
        } else {
          // Kalau satu gagal (kemungkinan internet mati), stop dulu —
          // sisanya dicoba lagi di siklus berikutnya
          break;
        }
      }
      debugPrint('🔄 Sync antrian selesai: $success/${pending.length} terkirim');
      return success;
    } catch (e) {
      debugPrint('❌ Sync antrian error: $e');
      return 0;
    }
  }

  // ==================== SYNC SATU TRANSAKSI (setelah pembayaran) ====================

  /// Kirim satu transaksi (order + items) ke Firestore.
  /// Dipanggil setiap kali pembayaran selesai di kasir.
  /// Jika berhasil, order ditandai synced = 1 di lokal.
  static Future<bool> pushSingleTransaction(String orderId) async {
    try {
      final orderData = await DatabaseHelper.instance.getOrderById(orderId);
      if (orderData == null) {
        debugPrint('⚠️ Order $orderId tidak ditemukan di lokal');
        return false;
      }
      final items = await DatabaseHelper.instance.getOrderItems(orderId);

      await _firestore.collection('transactions').doc(orderId).set({
        'order': orderData,
        'items': items,
      }).timeout(_timeout);

      await DatabaseHelper.instance.markOrderSynced(orderId);
      debugPrint('✅ Transaksi $orderId tersimpan ke cloud');
      return true;
    } catch (e) {
      debugPrint('❌ Push transaksi $orderId gagal (akan dicoba lagi otomatis): $e');
      return false;
    }
  }

  /// Update stok produk di cloud setelah penjualan (tanpa hapus-tulis semua)
  static Future<void> pushProductStock(String productId, int newStock) async {
    try {
      // set+merge, bukan update(): tetap berhasil walau dokumennya belum ada di cloud
      await _firestore.collection('products').doc(productId).set({
        'stock': newStock,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true)).timeout(_timeout);
      debugPrint('✅ Stok produk $productId di cloud → $newStock');
    } catch (e) {
      debugPrint('❌ Update stok cloud gagal: $e');
    }
  }

  /// Upsert satu produk (kondisi terbaru dari lokal) ke cloud.
  /// Dipanggil setelah tambah/edit produk supaya cloud langsung ter-update
  /// tanpa menunggu sync penuh berikutnya.
  static Future<void> pushSingleProduct(String productId) async {
    try {
      final product = await DatabaseHelper.instance.getProductById(productId);
      if (product == null) return;
      final data = Map<String, dynamic>.from(product);
      data.remove('id');
      await _firestore
          .collection('products')
          .doc(productId)
          .set(data, SetOptions(merge: true))
          .timeout(_timeout);
      debugPrint('✅ Produk $productId ter-update di cloud');
    } catch (e) {
      debugPrint('❌ Push produk $productId gagal (menyusul di sync berikutnya): $e');
    }
  }

  /// Hapus satu produk dari cloud (dipanggil saat produk dihapus di halaman Produk).
  /// Tanpa ini, produk yang dihapus lokal akan muncul lagi saat pull berikutnya.
  static Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete().timeout(_timeout);
      debugPrint('✅ Produk $productId dihapus dari cloud');
    } catch (e) {
      debugPrint('❌ Hapus produk cloud gagal: $e');
    }
  }

  /// Hapus satu transaksi dari cloud (untuk tombol hapus di halaman Transaksi)
  static Future<void> deleteTransaction(String orderId) async {
    try {
      await _firestore.collection('transactions').doc(orderId).delete().timeout(_timeout);
      debugPrint('✅ Transaksi $orderId dihapus dari cloud');
    } catch (e) {
      debugPrint('❌ Hapus transaksi cloud gagal: $e');
    }
  }

  // ==================== PULL FROM CLOUD (per-dokumen, merge) ====================

  static Future<void> pullFromCloud() async {
    try {
      await _pullProducts();
      await _pullTransactions();
    } catch (e) {
      debugPrint('❌ Pull error: $e');
    }
  }

  /// Gabungkan produk cloud ke lokal per-dokumen.
  /// Tidak pernah menghapus semua data lokal; konflik diputuskan lewat updated_at.
  static Future<void> _pullProducts() async {
    final productsSnap =
        await _firestore.collection('products').get().timeout(_timeout);

    if (productsSnap.docs.isEmpty) {
      debugPrint('ℹ️ No products in cloud');
      return;
    }

    int inserted = 0, updated = 0;
    for (final doc in productsSnap.docs) {
      final result = await DatabaseHelper.instance
          .mergeProductFromCloud(doc.id, doc.data());
      if (result == 'inserted') inserted++;
      if (result == 'updated') updated++;
    }

    debugPrint('✅ Pull products: ${productsSnap.docs.length} dicek, '
        '$inserted baru, $updated diperbarui');
  }

  /// Ambil transaksi cloud yang belum ada di lokal (per-dokumen).
  /// Transaksi yang sudah ada di lokal tidak disentuh.
  static Future<void> _pullTransactions() async {
    final transactionsSnap =
        await _firestore.collection('transactions').get().timeout(_timeout);

    if (transactionsSnap.docs.isEmpty) {
      debugPrint('ℹ️ No transactions in cloud');
      return;
    }

    int inserted = 0;
    for (final doc in transactionsSnap.docs) {
      final exists = await DatabaseHelper.instance.orderExists(doc.id);
      if (exists) continue; // transaksi bersifat final, tidak perlu di-update
      await DatabaseHelper.instance.insertTransactionFromCloud(doc.data());
      inserted++;
    }

    debugPrint('✅ Pull transactions: ${transactionsSnap.docs.length} di cloud, '
        '$inserted baru dimasukkan ke lokal');
  }

  // ==================== PUSH TO CLOUD (per-dokumen, upsert) ====================

  static Future<bool> pushToCloud() async {
    try {
      await _pushProducts();
      await _pushTransactions();
      return true;
    } catch (e) {
      debugPrint('❌ Push error: $e');
      return false;
    }
  }

  /// Upsert semua produk lokal ke cloud per-dokumen (set = buat/timpa doc itu saja).
  /// Tidak ada fase hapus — kalau proses terputus, dokumen yang sudah terkirim
  /// tetap utuh dan sisanya menyusul di sync berikutnya.
  static Future<void> _pushProducts() async {
    final localProducts = await DatabaseHelper.instance.getAllProducts();

    if (localProducts.isEmpty) {
      debugPrint('ℹ️ No products to push');
      return;
    }

    final batch = _firestore.batch();
    for (final p in localProducts) {
      final docId = p['id'].toString();
      final docRef = _firestore.collection('products').doc(docId);
      final data = Map<String, dynamic>.from(p);
      data.remove('id');
      data.remove('synced');
      batch.set(docRef, data, SetOptions(merge: true));
    }
    await batch.commit().timeout(_timeout);

    debugPrint('✅ Pushed ${localProducts.length} products to cloud (upsert)');
  }

  /// Kirim hanya transaksi yang belum ter-sync (synced = 0), per-dokumen.
  static Future<void> _pushTransactions() async {
    final pending = await DatabaseHelper.instance.getUnsyncedOrders();
    if (pending.isEmpty) return;

    for (final order in pending) {
      final ok = await pushSingleTransaction(order['id'].toString());
      if (!ok) {
        // Internet bermasalah — sisanya menyusul lewat SyncService
        throw Exception('Push transaksi ${order['id']} gagal');
      }
    }

    debugPrint('✅ Pushed ${pending.length} pending transactions to cloud');
  }

  // ==================== UTILITY ====================
  
  static Future<bool> checkConnection() async {
    try {
      await _firestore.collection('products').limit(1).get();
      return true;
    } catch (e) {
      debugPrint('❌ Firebase connection failed: $e');
      return false;
    }
  }
}