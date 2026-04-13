// manajemen_user_page.dart
import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';

class ManajemenUserPage extends StatefulWidget {
  const ManajemenUserPage({super.key});

  @override
  State<ManajemenUserPage> createState() => _ManajemenUserPageState();
}

class _ManajemenUserPageState extends State<ManajemenUserPage> {
  List<Map<String, dynamic>> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    // Untuk demo, kita buat list user statis
    // Dalam implementasi nyata, ini akan diambil dari database
    setState(() {
      users = [
        {'id': '1', 'username': 'admin', 'role': 'admin', 'created_at': DateTime.now().toIso8601String()},
        {'id': '2', 'username': 'kasir', 'role': 'kasir', 'created_at': DateTime.now().toIso8601String()},
      ];
      loading = false;
    });
  }

  void tambahUser() {
    showDialog(
      context: context,
      builder: (_) => const TambahUserDialog(),
    ).then((_) => loadUsers());
  }

  void resetPassword(String userId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset Password"),
        content: const Text("Password akan direset ke 'password123'. Lanjutkan?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              // Implementasi reset password
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Password berhasil direset")),
              );
            },
            child: const Text("Reset"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: tambahUser,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '👥 Manajemen User',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kelola akun user dan hak akses',
                      style: TextStyle(color: Colors.grey[600]),
                    ),

                    const SizedBox(height: 20),

                    /// SUMMARY
                    Responsive.isMobile(context)
                        ? Column(
                            children: [
                              _card("Total User", "${users.length}", Icons.people),
                              const SizedBox(height: 12),
                              _card("Admin", "${users.where((u) => u['role'] == 'admin').length}", Icons.admin_panel_settings),
                              const SizedBox(height: 12),
                              _card("Kasir", "${users.where((u) => u['role'] == 'kasir').length}", Icons.point_of_sale),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: _card("Total User", "${users.length}", Icons.people)),
                              const SizedBox(width: 12),
                              Expanded(child: _card("Admin", "${users.where((u) => u['role'] == 'admin').length}", Icons.admin_panel_settings)),
                              const SizedBox(width: 12),
                              Expanded(child: _card("Kasir", "${users.where((u) => u['role'] == 'kasir').length}", Icons.point_of_sale)),
                            ],
                          ),

                    const SizedBox(height: 20),

                    /// LIST USER
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: users.length,
                      itemBuilder: (_, i) {
                        final user = users[i];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: user['role'] == 'admin'
                                  ? Colors.blue.shade100
                                  : Colors.green.shade100,
                              child: Icon(
                                user['role'] == 'admin'
                                    ? Icons.admin_panel_settings
                                    : Icons.point_of_sale,
                                color: user['role'] == 'admin' ? Colors.blue : Colors.green,
                              ),
                            ),
                            title: Text(user['username']),
                            subtitle: Text("Role: ${user['role']} • Dibuat: ${user['created_at'].toString().substring(0, 10)}"),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'reset',
                                  child: Text('Reset Password'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Hapus User'),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'reset') {
                                  resetPassword(user['id']);
                                } else if (value == 'delete') {
                                  // Implementasi hapus user
                                }
                              },
                            ),
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

class TambahUserDialog extends StatefulWidget {
  const TambahUserDialog({super.key});

  @override
  State<TambahUserDialog> createState() => _TambahUserDialogState();
}

class _TambahUserDialogState extends State<TambahUserDialog> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  String selectedRole = 'kasir';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Tambah User Baru"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: usernameController,
            decoration: const InputDecoration(labelText: "Username"),
          ),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: "Password"),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: selectedRole,
            items: ['kasir', 'admin']
                .map((role) => DropdownMenuItem(
                      value: role,
                      child: Text(role.toUpperCase()),
                    ))
                .toList(),
            onChanged: (val) {
              setState(() {
                selectedRole = val!;
              });
            },
            decoration: const InputDecoration(labelText: "Role"),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Batal"),
        ),
        ElevatedButton(
          onPressed: () {
            // Implementasi tambah user
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("User berhasil ditambahkan")),
            );
          },
          child: const Text("Tambah"),
        ),
      ],
    );
  }
}