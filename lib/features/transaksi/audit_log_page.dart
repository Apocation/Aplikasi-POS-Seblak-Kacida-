// audit_log_page.dart
import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  List<Map<String, dynamic>> auditLogs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadAuditLogs();
  }

  Future<void> loadAuditLogs() async {
    // Untuk demo, kita buat audit log statis
    // Dalam implementasi nyata, ini akan diambil dari database
    await Future.delayed(const Duration(seconds: 1)); // Simulasi loading

    setState(() {
      auditLogs = [
        {
          'id': '1',
          'user': 'admin',
          'action': 'Login',
          'description': 'User admin berhasil login',
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          'ip': '192.168.1.100'
        },
        {
          'id': '2',
          'user': 'kasir',
          'action': 'Create Order',
          'description': 'Membuat order #ORD-abc123 dengan total Rp 45.000',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
          'ip': '192.168.1.101'
        },
        {
          'id': '3',
          'user': 'admin',
          'action': 'Update Product',
          'description': 'Mengubah harga Mie Kuning dari Rp 3.000 ke Rp 3.500',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
          'ip': '192.168.1.100'
        },
        {
          'id': '4',
          'user': 'kasir',
          'action': 'Delete Order',
          'description': 'Menghapus order #ORD-def456',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
          'ip': '192.168.1.101'
        },
      ];
      loading = false;
    });
  }

  String formatTimestamp(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }

  IconData getActionIcon(String action) {
    switch (action) {
      case 'Login':
        return Icons.login;
      case 'Create Order':
        return Icons.add_shopping_cart;
      case 'Update Product':
        return Icons.edit;
      case 'Delete Order':
        return Icons.delete;
      default:
        return Icons.info;
    }
  }

  Color getActionColor(String action) {
    switch (action) {
      case 'Login':
        return Colors.green;
      case 'Create Order':
        return Colors.blue;
      case 'Update Product':
        return Colors.orange;
      case 'Delete Order':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Audit Log',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log aktivitas sistem untuk audit dan monitoring',
                      style: TextStyle(color: Colors.grey[600]),
                    ),

                    const SizedBox(height: 20),

                    /// SUMMARY
                    Responsive.isMobile(context)
                        ? Column(
                            children: [
                              _card("Total Log", "${auditLogs.length}", Icons.history),
                              const SizedBox(height: 12),
                              _card("Login Hari Ini", "${auditLogs.where((log) => log['action'] == 'Login').length}", Icons.login),
                              const SizedBox(height: 12),
                              _card("Order Hari Ini", "${auditLogs.where((log) => log['action'].contains('Order')).length}", Icons.shopping_cart),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: _card("Total Log", "${auditLogs.length}", Icons.history)),
                              const SizedBox(width: 12),
                              Expanded(child: _card("Login Hari Ini", "${auditLogs.where((log) => log['action'] == 'Login').length}", Icons.login)),
                              const SizedBox(width: 12),
                              Expanded(child: _card("Order Hari Ini", "${auditLogs.where((log) => log['action'].contains('Order')).length}", Icons.shopping_cart)),
                            ],
                          ),

                    const SizedBox(height: 20),

                    /// FILTER BUTTONS
                    Row(
                      children: [
                        FilterChip(
                          label: const Text("Semua"),
                          selected: true,
                          onSelected: (_) {},
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text("Login"),
                          selected: false,
                          onSelected: (_) {},
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text("Order"),
                          selected: false,
                          onSelected: (_) {},
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text("Product"),
                          selected: false,
                          onSelected: (_) {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    /// AUDIT LOG LIST
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: auditLogs.length,
                      itemBuilder: (_, i) {
                        final log = auditLogs[i];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: getActionColor(log['action']).withValues(alpha: 0.1),
                              child: Icon(
                                getActionIcon(log['action']),
                                color: getActionColor(log['action']),
                              ),
                            ),
                            title: Text(
                              "${log['user']} - ${log['action']}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(log['description']),
                                const SizedBox(height: 2),
                                Text(
                                  "${formatTimestamp(log['timestamp'])} • IP: ${log['ip']}",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _card(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}