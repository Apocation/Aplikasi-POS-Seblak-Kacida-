import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import 'firebase_service.dart';

/// Menjaga data lokal selalu naik ke cloud tanpa perlu restart aplikasi:
/// 1. Timer berkala (tiap 5 menit) mengirim transaksi yang belum ter-sync.
/// 2. Listener konektivitas: begitu internet kembali, langsung sync saat itu juga.
class SyncService {
  static Timer? _timer;
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  static bool _syncing = false; // cegah sync bertumpuk

  static const Duration _interval = Duration(minutes: 5);

  /// Notifier untuk UI (misal badge "X transaksi belum ter-sync")
  static final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  static void start() {
    // Timer berkala
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => syncNow(reason: 'timer 5 menit'));

    // Deteksi internet kembali
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        debugPrint('[Sync] Internet kembali, sync sekarang...');
        syncNow(reason: 'internet kembali');
      } else {
        debugPrint('[Sync] Internet terputus, transaksi akan diantrikan');
      }
    });

    debugPrint('[Sync] SyncService aktif (interval ${_interval.inMinutes} menit)');
    // Sync pertama langsung, untuk mengejar antrian dari sesi sebelumnya
    syncNow(reason: 'startup');
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Kirim semua transaksi yang belum ter-sync. Aman dipanggil kapan saja.
  static Future<void> syncNow({String reason = 'manual'}) async {
    if (_syncing) {
      debugPrint('[Sync] Masih ada sync berjalan, lewati ($reason)');
      return;
    }
    _syncing = true;
    try {
      final sent = await FirebaseService.syncPendingTransactions();
      final remaining = await DatabaseHelper.instance.countUnsyncedOrders();
      pendingCount.value = remaining;
      if (sent > 0 || remaining > 0) {
        debugPrint('[Sync] ($reason) terkirim: $sent, sisa antrian: $remaining');
      }
    } catch (e) {
      debugPrint('[Sync] Error ($reason): $e');
    } finally {
      _syncing = false;
    }
  }

  /// Refresh angka antrian tanpa melakukan sync (untuk UI)
  static Future<void> refreshPendingCount() async {
    pendingCount.value = await DatabaseHelper.instance.countUnsyncedOrders();
  }
}
