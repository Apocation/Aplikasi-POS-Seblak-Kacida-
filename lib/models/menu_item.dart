// menu_item.dart
class MenuItem {
  final int id;
  final String name;
  final String kategori;
  final int harga;
  final int stok;
  final String image;
  final String status;

  const MenuItem({
    required this.id,
    required this.name,
    required this.kategori,
    required this.harga,
    required this.stok,
    required this.image,
    this.status = 'Aktif',
  });

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['id'] ?? 0,
      name: map['name'] ?? '',
      kategori: map['category'] ?? '',
      harga: map['price'] ?? 0,
      stok: map['stock'] ?? 0,
      image: map['icon'] ?? '',
      status: map['status'] ?? 'Aktif',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': kategori,
      'price': harga,
      'stock': stok,
      'icon': image,
      'status': status,
    };
  }

  String get hargaFormat {
    return "Rp $harga";
  }

  MenuItem copyWith({
    int? id,
    String? name,
    String? kategori,
    int? harga,
    int? stok,
    String? image,
    String? status,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      kategori: kategori ?? this.kategori,
      harga: harga ?? this.harga,
      stok: stok ?? this.stok,
      image: image ?? this.image,
      status: status ?? this.status,
    );
  }
}