// database.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

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
      version: 1,
      onCreate: _createDB,
    );
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

    // ORDERS (Header Transaksi)
    await db.execute('''
    CREATE TABLE orders (
      id TEXT PRIMARY KEY,
      total_price REAL NOT NULL,
      payment_method TEXT NOT NULL CHECK(payment_method IN ('Cash', 'QRIS')),
      status TEXT NOT NULL DEFAULT 'Pending' CHECK(status IN ('Paid', 'Pending')),
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
      {
        'name': 'Mie Kuning',
        'category': 'Base',
        'price': 3000.0,
        'stock': 100,
        'image_url': 'assets/images/base seblak/mie.jpg',
      },
 
      // ── TOPPING ──────────────────────────────────────────
      {
        'name': 'Bakso Besar',
        'category': 'Topping',
        'price': 5000.0,
        'stock': 50,
        'image_url': 'assets/images/topping/bakso_besar.jpeg',
      },
      {
        'name': 'Bakso Kecil',
        'category': 'Topping',
        'price': 3000.0,
        'stock': 50,
        'image_url': 'assets/images/topping/bakso_kecil.jpeg',
      },
      {
        'name': 'Crab Stick',
        'category': 'Topping',
        'price': 5000.0,
        'stock': 40,
        'image_url': 'assets/images/topping/crab_stick.jpeg',
      },
      {
        'name': 'Dumpling Ayam',
        'category': 'Topping',
        'price': 6000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/dumpling_ayam.jpeg',
      },
      {
        'name': 'Dumpling Keju',
        'category': 'Topping',
        'price': 6500.0,
        'stock': 30,
        'image_url': 'assets/images/topping/dumpling_keju.jpeg',
      },
      {
        'name': 'Fish Roll',
        'category': 'Topping',
        'price': 7000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/fish_roll.jpeg',
      },
      {
        'name': 'Otak-otak Ikan',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 40,
        'image_url': 'assets/images/topping/otak-otak_ikan.jpeg',
      },
      {
        'name': 'Pempek',
        'category': 'Topping',
        'price': 5000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/pempek.jpeg',
      },
      {
        'name': 'Sosis Ayam',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 50,
        'image_url': 'assets/images/topping/sosis_ayam.jpeg',
      },
      {
        'name': 'Sosis Sapi',
        'category': 'Topping',
        'price': 5000.0,
        'stock': 50,
        'image_url': 'assets/images/topping/sosis_sapi.jpeg',
      },
      {
        'name': 'Tahu Bakso',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 40,
        'image_url': 'assets/images/topping/tahu_bakso.jpeg',
      },
      {
        'name': 'Udang',
        'category': 'Topping',
        'price': 6000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/udang.jpeg',
      },
      // name1 - name19, name21 - name23 (belum ada nama, bisa diganti nanti)
      {
        'name': 'Topping 1',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name1.jpeg',
      },
      {
        'name': 'Topping 2',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name2.jpeg',
      },
      {
        'name': 'Topping 3',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name3.jpeg',
      },
      {
        'name': 'Topping 4',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name4.jpeg',
      },
      {
        'name': 'Topping 5',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name5.jpeg',
      },
      {
        'name': 'Topping 6',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name6.jpeg',
      },
      {
        'name': 'Topping 7',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name7.jpeg',
      },
      {
        'name': 'Topping 8',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name8.jpeg',
      },
      {
        'name': 'Topping 9',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name9.jpeg',
      },
      {
        'name': 'Topping 10',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name10.jpeg',
      },
      {
        'name': 'Topping 11',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name11.jpeg',
      },
      {
        'name': 'Topping 12',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name12.jpeg',
      },
      {
        'name': 'Topping 13',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name13.jpeg',
      },
      {
        'name': 'Topping 14',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name14.jpeg',
      },
      {
        'name': 'Topping 15',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name15.jpeg',
      },
      {
        'name': 'Topping 16',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name16.jpeg',
      },
      {
        'name': 'Topping 17',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name17.jpeg',
      },
      {
        'name': 'Topping 18',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name18.jpeg',
      },
      {
        'name': 'Topping 19',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name19.jpeg',
      },
      {
        'name': 'Topping 21',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name21.jpeg',
      },
      {
        'name': 'Topping 22',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name22.jpeg',
      },
      {
        'name': 'Topping 23',
        'category': 'Topping',
        'price': 4000.0,
        'stock': 30,
        'image_url': 'assets/images/topping/name23.jpeg',
      },
 
      // ── SAYUR ────────────────────────────────────────────
      {
        'name': 'Sayur 1',
        'category': 'Sayur',
        'price': 2000.0,
        'stock': 50,
        'image_url': 'assets/images/sayur/name20.jpeg',
      },
      {
        'name': 'Sayur 2',
        'category': 'Sayur',
        'price': 2000.0,
        'stock': 50,
        'image_url': 'assets/images/sayur/name24.jpeg',
      },
      {
        'name': 'Sayur 3',
        'category': 'Sayur',
        'price': 2000.0,
        'stock': 50,
        'image_url': 'assets/images/sayur/name25.jpeg',
      },
 
      // ── LEVEL PEDAS ──────────────────────────────────────
      {
        'name': 'Level 1',
        'category': 'Pedas',
        'price': 0.0,
        'stock': 999,
        'image_url': '',
      },
      {
        'name': 'Level 2',
        'category': 'Pedas',
        'price': 0.0,
        'stock': 999,
        'image_url': '',
      },
      {
        'name': 'Level 3',
        'category': 'Pedas',
        'price': 0.0,
        'stock': 999,
        'image_url': '',
      },
      {
        'name': 'Level 4',
        'category': 'Pedas',
        'price': 0.0,
        'stock': 999,
        'image_url': '',
      },
      {
        'name': 'Level 5',
        'category': 'Pedas',
        'price': 0.0,
        'stock': 999,
        'image_url': '',
      },
    ];
 
    for (var product in products) {
      await db.insert('products', {
        'id':         _uuid.v4(),
        'name':       product['name'],
        'category':   product['category'],
        'price':      product['price'],
        'stock':      product['stock'],
        'image_url':  product['image_url'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // LOGIN
  Future<Map<String, dynamic>?> login(
      String username, String password) async {
    final db = await instance.database;

    final result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    return result.isNotEmpty ? result.first : null;
  }

  // PRODUCTS METHODS
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
    return await db.update('products', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteProduct(String id) async {
    final db = await instance.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateProductStock(String productId, int newStock) async {
    final db = await instance.database;
    return await db.update(
      'products',
      {'stock': newStock, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // ORDERS METHODS
  Future<String> createOrder(Map<String, dynamic> orderData) async {
    final db = await instance.database;
    final id = _uuid.v4();
    orderData['id'] = id;
    orderData['created_at'] = DateTime.now().toIso8601String();

    await db.insert('orders', orderData);
    return id;
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

  Future<int> updateOrderStatus(String id, String status) async {
    final db = await instance.database;
    return await db.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ORDER ITEMS METHODS
  Future<String> addOrderItem(Map<String, dynamic> itemData) async {
    final db = await instance.database;
    final id = _uuid.v4();
    itemData['id'] = id;
    itemData['created_at'] = DateTime.now().toIso8601String();

    await db.insert('order_items', itemData);
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

  // DASHBOARD METHODS
  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await instance.database;

    // Total products
    final totalProducts = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM products'),
    ) ?? 0;

    // Low stock products (< 10)
    final lowStockProducts = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM products WHERE stock < 10'),
    ) ?? 0;

    // Total orders
    final totalOrders = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM orders'),
    ) ?? 0;

    // Total revenue
    final totalRevenue = (await db.rawQuery('SELECT SUM(total_price) FROM orders WHERE status = "Paid"')).first['SUM(total_price)'] ?? 0.0;

    // Today's sales
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayRevenue = (await db.rawQuery(
      'SELECT SUM(total_price) FROM orders WHERE status = "Paid" AND DATE(created_at) = ?',
      [today],
    )).first['SUM(total_price)'] ?? 0.0;

    final todayOrders = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM orders WHERE status = "Paid" AND DATE(created_at) = ?',
        [today],
      ),
    ) ?? 0;

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
    return await db.rawQuery('''
      SELECT p.name AS item, SUM(oi.quantity) AS terjual, SUM(oi.subtotal) AS pendapatan
      FROM order_items oi
      LEFT JOIN products p ON p.id = oi.product_id
      GROUP BY oi.product_id
      ORDER BY terjual DESC
      LIMIT ?
    ''', [limit]);
  }

  /// Item terlaris HARI INI saja
  Future<List<Map<String, dynamic>>> getTopSellingProductsToday({int limit = 5}) async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await db.rawQuery('''
      SELECT p.name AS item, SUM(oi.quantity) AS terjual
      FROM order_items oi
      LEFT JOIN products p ON p.id = oi.product_id
      LEFT JOIN orders o ON o.id = oi.order_id
      WHERE o.status = "Paid" AND DATE(o.created_at) = ?
      GROUP BY oi.product_id
      ORDER BY terjual DESC
      LIMIT ?
    ''', [today, limit]);
  }
 
  /// Produk stok rendah (< 10)
  Future<List<Map<String, dynamic>>> getLowStockProducts({int threshold = 10}) async {
    final db = await instance.database;
    return await db.query(
      'products',
      where: 'stock < ? AND stock > 0',
      whereArgs: [threshold],
      orderBy: 'stock ASC',
      limit: 5,
    );
  }
 
  /// Transaksi terakhir beserta jumlah item
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
        FROM orders
        WHERE status = "Paid"
        GROUP BY DATE(created_at)
        ORDER BY DATE(created_at) DESC
        LIMIT 12
      ''');
    }

    if (range == 'Mingguan') {
      return await db.rawQuery('''
        SELECT strftime('%Y-%W', created_at) AS label, SUM(total_price) AS total
        FROM orders
        WHERE status = "Paid"
        GROUP BY strftime('%Y-%W', created_at)
        ORDER BY strftime('%Y-%W', created_at) DESC
        LIMIT 12
      ''');
    }

    return await db.rawQuery('''
      SELECT strftime('%Y-%m', created_at) AS label, SUM(total_price) AS total
      FROM orders
      WHERE status = "Paid"
      GROUP BY strftime('%Y-%m', created_at)
      ORDER BY strftime('%Y-%m', created_at) DESC
      LIMIT 12
    ''');
  }

  // SETTINGS METHODS
  Future<Map<String, dynamic>> getSettings() async {
    final db = await instance.database;
    final result = await db.query('settings', limit: 1);

    if (result.isEmpty) {
      // Create default settings if none exist
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

    // Check if settings exist
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

    // Delete all data from tables
    await db.delete('order_items');
    await db.delete('orders');
    await db.delete('products');
    await db.delete('users');
    await db.delete('settings');

    // Re-insert default users
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

    // Re-insert default settings
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