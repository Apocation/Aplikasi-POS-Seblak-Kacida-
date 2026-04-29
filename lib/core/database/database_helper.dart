import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../services/data_notifier.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const _uuid = Uuid();
  

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('seblak.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Update version karena ada perubahan struktur
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Tambah kolom customer_name jika belum ada
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN customer_name TEXT DEFAULT "Pelanggan"');
      } catch (e) {
        print('Error upgrading database: $e');
      }
    }
  }

  Future _createDB(Database db, int version) async {
    // USERS
    await db.execute('''
    CREATE TABLE users (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE,
      password TEXT,
      role TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
    ''');

    // PRODUCTS
    await db.execute('''
    CREATE TABLE products (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      price REAL NOT NULL,
      stock INTEGER NOT NULL DEFAULT 0,
      image_url TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
    ''');

    // ORDERS (Header Transaksi) - dengan customer_name
    await db.execute('''
    CREATE TABLE orders (
      id TEXT PRIMARY KEY,
      customer_name TEXT DEFAULT 'Pelanggan',
      note TEXT DEFAULT '',
      total_price REAL NOT NULL,
      payment_method TEXT NOT NULL CHECK(payment_method IN ('Cash', 'QRIS')),
      status TEXT NOT NULL DEFAULT 'Pending' CHECK(status IN ('Paid', 'Pending')),
      amount_paid REAL DEFAULT 0,      -- Uang yang dibayar
      change_amount REAL DEFAULT 0,     -- Kembalian
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
    ''');

    // ORDER ITEMS (Detail Transaksi)
    await db.execute('''
    CREATE TABLE order_items (
      id TEXT PRIMARY KEY,
      order_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      subtotal REAL NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
    )
    ''');

    // SETTINGS
    await db.execute('''
    CREATE TABLE settings (
      id TEXT PRIMARY KEY,
      store_name TEXT,
      store_address TEXT,
      store_phone TEXT,
      tax_rate REAL DEFAULT 0.0,
      discount_rate REAL DEFAULT 0.0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
    ''');

    // DEFAULT USERS
    await db.insert('users', {
      'id': _uuid.v4(),
      'username': 'admin',
      'password': 'admin123',
      'role': 'admin'
    });

    await db.insert('users', {
      'id': _uuid.v4(),
      'username': 'kasir',
      'password': 'kasir123',
      'role': 'kasir'
    });

    // DEFAULT SETTINGS
    await db.insert('settings', {
      'id': _uuid.v4(),
      'store_name': 'Seblak Kacida',
      'store_address': 'Jl. Contoh No. 123',
      'store_phone': '+62 812-3456-7890'
    });

    // DEFAULT PRODUCTS
    final products = [
      // ── BASE SEBLAK ──────────────────────────────────────
      {'name': 'Mie Kuning', 'category': 'Base', 'price': 3000.0, 'stock': 100, 'image_url': 'assets/images/base seblak/mie.jpg'},
      // ── TOPPING ──────────────────────────────────────────
      {'name': 'Bakso Besar', 'category': 'Topping', 'price': 5000.0, 'stock': 50, 'image_url': 'assets/images/topping/bakso_besar.jpeg'},
      {'name': 'Bakso Kecil', 'category': 'Topping', 'price': 3000.0, 'stock': 50, 'image_url': 'assets/images/topping/bakso_kecil.jpeg'},
      {'name': 'Crab Stick', 'category': 'Topping', 'price': 5000.0, 'stock': 40, 'image_url': 'assets/images/topping/crab_stick.jpeg'},
      {'name': 'Dumpling Ayam', 'category': 'Topping', 'price': 6000.0, 'stock': 30, 'image_url': 'assets/images/topping/dumpling_ayam.jpeg'},
      {'name': 'Dumpling Keju', 'category': 'Topping', 'price': 6500.0, 'stock': 30, 'image_url': 'assets/images/topping/dumpling_keju.jpeg'},
      {'name': 'Fish Roll', 'category': 'Topping', 'price': 7000.0, 'stock': 30, 'image_url': 'assets/images/topping/fish_roll.jpeg'},
      {'name': 'Otak-otak Ikan', 'category': 'Topping', 'price': 4000.0, 'stock': 40, 'image_url': 'assets/images/topping/otak-otak_ikan.jpeg'},
      {'name': 'Pempek', 'category': 'Topping', 'price': 5000.0, 'stock': 30, 'image_url': 'assets/images/topping/pempek.jpeg'},
      {'name': 'Sosis Ayam', 'category': 'Topping', 'price': 4000.0, 'stock': 50, 'image_url': 'assets/images/topping/sosis_ayam.jpeg'},
      {'name': 'Sosis Sapi', 'category': 'Topping', 'price': 5000.0, 'stock': 50, 'image_url': 'assets/images/topping/sosis_sapi.jpeg'},
      {'name': 'Tahu Bakso', 'category': 'Topping', 'price': 4000.0, 'stock': 40, 'image_url': 'assets/images/topping/tahu_bakso.jpeg'},
      {'name': 'Udang', 'category': 'Topping', 'price': 6000.0, 'stock': 30, 'image_url': 'assets/images/topping/udang.jpeg'},
      // ── SAYUR ────────────────────────────────────────────
      {'name': 'Sayur 1', 'category': 'Sayur', 'price': 2000.0, 'stock': 50, 'image_url': 'assets/images/sayur/name20.jpeg'},
      {'name': 'Sayur 2', 'category': 'Sayur', 'price': 2000.0, 'stock': 50, 'image_url': 'assets/images/sayur/name24.jpeg'},
      {'name': 'Sayur 3', 'category': 'Sayur', 'price': 2000.0, 'stock': 50, 'image_url': 'assets/images/sayur/name25.jpeg'},
      // ── LEVEL PEDAS ──────────────────────────────────────
      {'name': 'Level 1', 'category': 'Pedas', 'price': 0.0, 'stock': 999, 'image_url': ''},
      {'name': 'Level 2', 'category': 'Pedas', 'price': 0.0, 'stock': 999, 'image_url': ''},
      {'name': 'Level 3', 'category': 'Pedas', 'price': 0.0, 'stock': 999, 'image_url': ''},
      {'name': 'Level 4', 'category': 'Pedas', 'price': 0.0, 'stock': 999, 'image_url': ''},
      {'name': 'Level 5', 'category': 'Pedas', 'price': 0.0, 'stock': 999, 'image_url': ''},
      // ── MINUMAN ──────────────────────────────────────────────
      {'name': 'Es Teh', 'category': 'Minuman', 'price': 5000.0, 'stock': 100, 'image_url': ''},
    ];
 
    for (var product in products) {
      await db.insert('products', {
        'id': _uuid.v4(),
        'name': product['name'],
        'category': product['category'],
        'price': product['price'],
        'stock': product['stock'],
        'image_url': product['image_url'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // ==================== LOGIN ====================
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // ==================== PRODUCTS METHODS ====================
  Future<String> insertProduct(Map<String, dynamic> data) async {
    final db = await instance.database;
    final id = _uuid.v4();
    data['id'] = id;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert('products', data);
    return id;
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await instance.database;
    return await db.query('products', orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getProductById(String id) async {
    final db = await instance.database;
    final result = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateProduct(String id, Map<String, dynamic> data) async {
    final db = await instance.database;
    data['updated_at'] = DateTime.now().toIso8601String();
    final result = await db.update('products', data, where: 'id = ?', whereArgs: [id]);
    DataNotifier.notify(); // TAMBAHKAN INI
    return result;
  }

  Future<int> deleteProduct(String id) async {
    final db = await instance.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateProductStock(String productId, int newStock) async {
    final db = await instance.database;
    final result = await db.update(
      'products',
      {'stock': newStock, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );
    DataNotifier.notify();
    return result;
  }

  Future<void> clearProducts() async {
    final db = await instance.database;
    await db.delete('products');
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await instance.database;
    return await db.query('products');
  }

  // ==================== ORDERS METHODS ====================
  
  // CREATE ORDER dengan customer_name
  Future<String> createOrder({
    required double totalPrice,
    required String paymentMethod,
    required String status,
    String customerName = 'Pelanggan',
    String note = '',
    double amountPaid = 0,
    double changeAmount = 0,
  }) async {
    final db = await instance.database;
    final id = _uuid.v4();
    await db.insert('orders', {
      'id': id,
      'customer_name': customerName,
      'note': note,
      'total_price': totalPrice,
      'payment_method': paymentMethod,
      'status': status,
      'amount_paid': amountPaid,
      'change_amount': changeAmount,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  // Untuk kompatibilitas dengan kode lama (parameter Map)
  Future<String> createOrderWithMap(Map<String, dynamic> orderData) async {
    final db = await instance.database;
    final id = _uuid.v4();
    orderData['id'] = id;
    orderData['created_at'] = DateTime.now().toIso8601String();
    
    // Pastikan customer_name ada
    if (!orderData.containsKey('customer_name') || orderData['customer_name'] == null || orderData['customer_name'].toString().isEmpty) {
      orderData['customer_name'] = 'Pelanggan';
    }
    
    // Pastikan note ada
    if (!orderData.containsKey('note')) {
      orderData['note'] = '';
    }
    
    await db.insert('orders', orderData);
    return id;
  }

  Future<int> updateOrderCustomerName(String orderId, String customerName) async {
    final db = await instance.database;
    return await db.update(
      'orders',
      {'customer_name': customerName},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final db = await instance.database;
    return await db.query('orders', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getOrderById(String id) async {
    final db = await instance.database;
    final result = await db.query('orders', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  // Ambil order dengan customer_name
  Future<Map<String, dynamic>> getOrderWithCustomer(String orderId) async {
    final db = await instance.database;
    final result = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
    );
    if (result.isEmpty) return {};
    return result.first;
  }

  Future<int> updateOrderStatus(String id, String status) async {
    final db = await instance.database;
    return await db.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getOrdersByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await instance.database;
    final startStr = startDate.toIso8601String();
    final endStr = endDate.toIso8601String();
    return await db.query(
      'orders',
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getOrdersByPaymentMethod(String method) async {
    final db = await instance.database;
    return await db.query(
      'orders',
      where: 'payment_method = ?',
      whereArgs: [method],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getOrdersByStatus(String status) async {
    final db = await instance.database;
    return await db.query(
      'orders',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getTodayOrders() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await db.rawQuery(
      'SELECT * FROM orders WHERE DATE(created_at) = ? ORDER BY created_at DESC',
      [today],
    );
  }

  Future<int> deleteOrder(String id) async {
    final db = await instance.database;
    return await db.delete('orders', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalRevenue() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT SUM(total_price) as total FROM orders WHERE status = "Paid"');
    return (result.first['total'] ?? 0.0) as double;
  }

  Future<double> getRevenueByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await instance.database;
    final startStr = startDate.toIso8601String();
    final endStr = endDate.toIso8601String();
    final result = await db.rawQuery(
      'SELECT SUM(total_price) as total FROM orders WHERE status = "Paid" AND created_at >= ? AND created_at <= ?',
      [startStr, endStr],
    );
    return (result.first['total'] ?? 0.0) as double;
  }

  Future<int> getOrderCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM orders');
    return (result.first['count'] ?? 0) as int;
  }

  Future<int> getPaidOrderCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM orders WHERE status = "Paid"');
    return (result.first['count'] ?? 0) as int;
  }

  // ==================== ORDER ITEMS METHODS ====================
  Future<String> addOrderItem(Map<String, dynamic> itemData) async {
    final db = await instance.database;
    final id = _uuid.v4();
    itemData['id'] = id;
    itemData['created_at'] = DateTime.now().toIso8601String();
    await db.insert('order_items', itemData);
    await _updateOrderTotal(itemData['order_id']);
    return id;
  }

  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    final db = await instance.database;
    return await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  Future<List<Map<String, dynamic>>> getOrderItemsWithProduct(String orderId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT oi.*, p.name, p.image_url 
      FROM order_items oi
      LEFT JOIN products p ON p.id = oi.product_id
      WHERE oi.order_id = ?
      ORDER BY oi.created_at ASC
    ''', [orderId]);
  }

  Future<int> updateOrderItemQuantity(String itemId, int newQuantity) async {
    final db = await instance.database;
    final item = await db.query(
      'order_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
    if (item.isEmpty) return 0;
    final price = (item.first['subtotal'] as double) / (item.first['quantity'] as int);
    final newSubtotal = price * newQuantity;
    final result = await db.update(
      'order_items',
      {'quantity': newQuantity, 'subtotal': newSubtotal},
      where: 'id = ?',
      whereArgs: [itemId],
    );
    if (result > 0) {
      final orderId = item.first['order_id'] as String;
      await _updateOrderTotal(orderId);
    }
    return result;
  }

  Future<int> removeOrderItem(String itemId) async {
    final db = await instance.database;
    final item = await db.query(
      'order_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
    final result = await db.delete('order_items', where: 'id = ?', whereArgs: [itemId]);
    if (result > 0 && item.isNotEmpty) {
      await _updateOrderTotal(item.first['order_id'] as String);
    }
    return result;
  }

  Future<int> clearOrderItems(String orderId) async {
    final db = await instance.database;
    final result = await db.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
    await db.update('orders', {'total_price': 0.0}, where: 'id = ?', whereArgs: [orderId]);
    return result;
  }

  Future<void> _updateOrderTotal(String orderId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(subtotal) as total FROM order_items WHERE order_id = ?',
      [orderId],
    );
    final total = (result.first['total'] ?? 0.0) as double;
    await db.update('orders', {'total_price': total}, where: 'id = ?', whereArgs: [orderId]);
  }

  Future<bool> completeOrder(String orderId, String paymentMethod) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final items = await txn.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      for (final item in items) {
        final productId = item['product_id'] as String;
        final quantity = item['quantity'] as int;
        final product = await txn.query('products', where: 'id = ?', whereArgs: [productId]);
        if (product.isEmpty) throw Exception('Product not found: $productId');
        final currentStock = product.first['stock'] as int;
        final newStock = currentStock - quantity;
        if (newStock < 0) throw Exception('Insufficient stock for product: ${product.first['name']}');
        await txn.update('products', {'stock': newStock, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [productId]);
      }
      await txn.update('orders', {'status': 'Paid', 'payment_method': paymentMethod}, where: 'id = ?', whereArgs: [orderId]);
      return true;
    });
  }

  Future<Map<String, dynamic>> getOrderSummary(String orderId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT o.*, COUNT(oi.id) as item_count, SUM(oi.quantity) as total_items
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      WHERE o.id = ?
      GROUP BY o.id
    ''', [orderId]);
    return result.isEmpty ? {} : result.first;
  }

  // ==================== SYNC METHODS (untuk Firebase) ====================
  Future<List<Map<String, dynamic>>> getAllOrdersWithItems() async {
    final db = await instance.database;
    final orders = await db.query('orders', orderBy: 'created_at DESC');
    final List<Map<String, dynamic>> result = [];
    for (final order in orders) {
      final items = await db.query('order_items', where: 'order_id = ?', whereArgs: [order['id']]);
      result.add({'order': order, 'items': items});
    }
    return result;
  }

  Future<void> clearAllTransactions() async {
    final db = await instance.database;
    await db.delete('order_items');
    await db.delete('orders');
  }

  Future<void> insertTransactionFromCloud(Map<String, dynamic> transactionData) async {
    final db = await instance.database;
    final order = Map<String, dynamic>.from(transactionData['order']);
    await db.insert('orders', order, conflictAlgorithm: ConflictAlgorithm.replace);
    final items = transactionData['items'] as List;
    for (final item in items) {
      await db.insert('order_items', item, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ==================== DASHBOARD METHODS ====================
  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await instance.database;
    final totalProducts = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products')) ?? 0;
    final lowStockProducts = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products WHERE stock < 10')) ?? 0;
    final totalOrders = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM orders')) ?? 0;
    final totalRevenue = (await db.rawQuery('SELECT SUM(total_price) FROM orders WHERE status = "Paid"')).first['SUM(total_price)'] ?? 0.0;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayRevenue = (await db.rawQuery('SELECT SUM(total_price) FROM orders WHERE status = "Paid" AND DATE(created_at) = ?', [today])).first['SUM(total_price)'] ?? 0.0;
    final todayOrders = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM orders WHERE status = "Paid" AND DATE(created_at) = ?', [today])) ?? 0;
    return {
      'totalProducts': totalProducts,
      'lowStockProducts': lowStockProducts,
      'totalOrders': totalOrders,
      'totalRevenue': totalRevenue,
      'todayRevenue': todayRevenue,
      'todayOrders': todayOrders,
    };
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts({int limit = 10}) async {
    final db = await instance.database;
    
    final result = await db.rawQuery('''
      SELECT 
        p.name AS item, 
        SUM(oi.quantity) AS terjual,
        SUM(oi.subtotal) AS pendapatan
      FROM order_items oi
      INNER JOIN products p ON p.id = oi.product_id
      INNER JOIN orders o ON o.id = oi.order_id
      WHERE o.status = 'Paid'
      GROUP BY oi.product_id
      ORDER BY terjual DESC
      LIMIT ?
    ''', [limit]);
    
    print('Top products all time: $result'); // Debug
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getTopSellingProductsToday({int limit = 5}) async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    final result = await db.rawQuery('''
      SELECT 
        p.name AS item, 
        SUM(oi.quantity) AS terjual,
        SUM(oi.subtotal) AS pendapatan
      FROM order_items oi
      INNER JOIN products p ON p.id = oi.product_id
      INNER JOIN orders o ON o.id = oi.order_id
      WHERE o.status = 'Paid' 
        AND DATE(o.created_at) = DATE(?)
      GROUP BY oi.product_id
      ORDER BY terjual DESC
      LIMIT ?
    ''', [today, limit]);
    
    print('Top products today: $result'); // Debug
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getLowStockProducts({int threshold = 10}) async {
    final db = await instance.database;
    return await db.query('products', where: 'stock < ? AND stock > 0', whereArgs: [threshold], orderBy: 'stock ASC', limit: 5);
  }

  Future<List<Map<String, dynamic>>> getRecentOrders({int limit = 5}) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT o.*, COUNT(oi.id) AS item_count
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      WHERE o.status = "Paid"
      GROUP BY o.id
      ORDER BY o.created_at DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<List<Map<String, dynamic>>> getSalesChartData(String range) async {
    final db = await instance.database;
    if (range == 'Harian') {
      return await db.rawQuery('''
        SELECT DATE(created_at) AS label, SUM(total_price) AS total
        FROM orders WHERE status = "Paid"
        GROUP BY DATE(created_at)
        ORDER BY DATE(created_at) DESC LIMIT 12
      ''');
    }
    if (range == 'Mingguan') {
      return await db.rawQuery('''
        SELECT strftime('%Y-%W', created_at) AS label, SUM(total_price) AS total
        FROM orders WHERE status = "Paid"
        GROUP BY strftime('%Y-%W', created_at)
        ORDER BY strftime('%Y-%W', created_at) DESC LIMIT 12
      ''');
    }
    return await db.rawQuery('''
      SELECT strftime('%Y-%m', created_at) AS label, SUM(total_price) AS total
      FROM orders WHERE status = "Paid"
      GROUP BY strftime('%Y-%m', created_at)
      ORDER BY strftime('%Y-%m', created_at) DESC LIMIT 12
    ''');
  }

  // ==================== SETTINGS METHODS ====================
  Future<Map<String, dynamic>> getSettings() async {
    final db = await instance.database;
    final result = await db.query('settings', limit: 1);
    if (result.isEmpty) {
      final defaultSettings = {
        'id': _uuid.v4(),
        'store_name': 'Seblak Kacida',
        'store_address': '',
        'store_phone': '',
        'tax_rate': 0.0,
        'discount_rate': 0.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await db.insert('settings', defaultSettings);
      return defaultSettings;
    }
    return result.first;
  }

  Future<int> updateSettings(Map<String, dynamic> settings) async {
    final db = await instance.database;
    settings['updated_at'] = DateTime.now().toIso8601String();
    final existing = await db.query('settings', limit: 1);
    if (existing.isEmpty) {
      settings['id'] = _uuid.v4();
      settings['created_at'] = DateTime.now().toIso8601String();
      return await db.insert('settings', settings);
    } else {
      return await db.update('settings', settings, where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  Future<void> resetDatabase() async {
    final db = await instance.database;
    await db.delete('order_items');
    await db.delete('orders');
    await db.delete('products');
    await db.delete('users');
    await db.delete('settings');
    await db.insert('users', {'id': _uuid.v4(), 'username': 'admin', 'password': 'admin123', 'role': 'admin'});
    await db.insert('users', {'id': _uuid.v4(), 'username': 'kasir', 'password': 'kasir123', 'role': 'kasir'});
    await db.insert('settings', {
      'id': _uuid.v4(),
      'store_name': 'Seblak Kacida',
      'store_address': '',
      'store_phone': '',
      'tax_rate': 0.0,
      'discount_rate': 0.0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}