import 'package:cloud_firestore/cloud_firestore.dart';
import '../database/database_helper.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== MAIN SYNC METHODS ====================
  
  static Future<void> syncAll() async {
    await pushToCloud();
    await pullFromCloud();
  }

  // ==================== PULL FROM CLOUD ====================
  
  static Future<void> pullFromCloud() async {
    try {
      await _pullProducts();
      await _pullTransactions();
    } catch (e) {
      print('❌ Pull error: $e');
    }
  }

  /// Pull products - GANTI TOTAL dengan data cloud (replace, bukan tambah)
  static Future<void> _pullProducts() async {
    final productsSnap = await _firestore.collection('products').get();
    
    if (productsSnap.docs.isEmpty) {
      print('ℹ️ No products in cloud');
      return;
    }
    
    // Ambil data dari cloud
    final cloudProducts = productsSnap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    
    // HAPUS semua produk lokal dulu
    await DatabaseHelper.instance.clearProducts();
    
    // INSERT ulang semua dari cloud
    for (final p in cloudProducts) {
      await DatabaseHelper.instance.insertProduct(p);
    }
    
    print('✅ Pulled ${cloudProducts.length} products from cloud (replaced local)');
  }

  static Future<void> _pullTransactions() async {
    final transactionsSnap = await _firestore.collection('transactions').get();
    
    if (transactionsSnap.docs.isEmpty) {
      print('ℹ️ No transactions in cloud');
      return;
    }
    
    await DatabaseHelper.instance.clearAllTransactions();
    
    for (final doc in transactionsSnap.docs) {
      await DatabaseHelper.instance.insertTransactionFromCloud(doc.data());
    }
    
    print('✅ Pulled ${transactionsSnap.docs.length} transactions from cloud');
  }

  // ==================== PUSH TO CLOUD ====================
  
  static Future<void> pushToCloud() async {
    try {
      await _pushProducts();
      await _pushTransactions();
    } catch (e) {
      print('❌ Push error: $e');
    }
  }

  /// Push products - KIRIM semua data lokal ke cloud (replace)
  static Future<void> _pushProducts() async {
    final localProducts = await DatabaseHelper.instance.getAllProducts();
    
    if (localProducts.isEmpty) {
      print('ℹ️ No products to push');
      return;
    }
    
    // HAPUS semua data di cloud dulu
    final cloudProductsSnap = await _firestore.collection('products').get();
    final batch = _firestore.batch();
    
    for (final doc in cloudProductsSnap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    
    // KIRIM semua data lokal ke cloud
    final newBatch = _firestore.batch();
    for (final p in localProducts) {
      final docId = p['id'].toString();
      final docRef = _firestore.collection('products').doc(docId);
      final data = Map<String, dynamic>.from(p);
      data.remove('id');
      newBatch.set(docRef, data);
    }
    await newBatch.commit();
    
    print('✅ Pushed ${localProducts.length} products to cloud (replaced cloud)');
  }

  static Future<void> _pushTransactions() async {
    final localTransactions = await DatabaseHelper.instance.getAllOrdersWithItems();
    
    if (localTransactions.isEmpty) return;
    
    final cloudTransactionsSnap = await _firestore.collection('transactions').get();
    final batch = _firestore.batch();
    
    for (final doc in cloudTransactionsSnap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    
    final newBatch = _firestore.batch();
    for (final t in localTransactions) {
      final orderId = t['order']['id'].toString();
      final docRef = _firestore.collection('transactions').doc(orderId);
      newBatch.set(docRef, t);
    }
    await newBatch.commit();
    
    print('✅ Pushed ${localTransactions.length} transactions to cloud');
  }

  // ==================== UTILITY ====================
  
  static Future<bool> checkConnection() async {
    try {
      await _firestore.collection('products').limit(1).get();
      return true;
    } catch (e) {
      print('❌ Firebase connection failed: $e');
      return false;
    }
  }
}