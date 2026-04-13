import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
//  SHEETS SERVICE — dengan Offline Queue
//  Taruh di: lib/core/services/sheets_service.dart
//
//  Cara kerja:
//  1. Transaksi selesai → coba kirim ke Sheets langsung
//  2. Kalau gagal (offline/lemot) → masuk antrian lokal
//  3. Saat internet kembali → antrian dikirim ulang otomatis
//  4. Data TIDAK pernah hilang
// ============================================================

class SheetsService {
  SheetsService._();
  static final SheetsService instance = SheetsService._();

  static const _prefKeyUrl   = 'sheets_webhook_url';
  static const _prefKeyQueue = 'sheets_pending_queue';

  String?        _webhookUrl;
  Timer?         _retryTimer;
  bool           _isSyncing = false;

  bool get isConfigured =>
      _webhookUrl != null && _webhookUrl!.trim().isNotEmpty;

  // ── Init — panggil di main() atau home_page ───────────────
  Future<void> init() async {
    final prefs  = await SharedPreferences.getInstance();
    _webhookUrl  = prefs.getString(_prefKeyUrl);
    // Mulai retry timer — cek queue setiap 30 detik
    _startRetryTimer();
  }

  Future<void> saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyUrl, url.trim());
    _webhookUrl = url.trim();
    // Langsung coba kirim queue yang pending
    _flushQueue();
  }

  Future<String?> getSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUrl);
  }

  // ── Mulai retry timer ─────────────────────────────────────
  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _flushQueue(),
    );
  }

  void dispose() {
    _retryTimer?.cancel();
  }

  // ── Public: kirim transaksi ───────────────────────────────
  Future<SheetsResult> syncTransaksi({
    required String orderId,
    required String invoiceNo,
    required double total,
    required String metode,
    required String pemesan,
    required String catatan,
    required List<Map<String, dynamic>> items,
    required DateTime waktu,
  }) async {
    if (!isConfigured) {
      return const SheetsResult(
          success: false,
          status:  SyncStatus.notConfigured,
          message: 'URL Google Sheets belum dikonfigurasi');
    }

    final payload = _buildPayload(
      invoiceNo: invoiceNo,
      total:     total,
      metode:    metode,
      pemesan:   pemesan,
      catatan:   catatan,
      items:     items,
      waktu:     waktu,
    );

    // Coba kirim langsung
    final result = await _sendPayload(payload);

    if (result.success) {
      debugPrint('✅ Sheets sync berhasil: $invoiceNo');
      return result;
    }

    // Gagal → masuk queue
    await _enqueue(payload);
    debugPrint('📥 Sheets sync gagal, masuk antrian: $invoiceNo');
    return SheetsResult(
      success: false,
      status:  SyncStatus.queued,
      message: 'Offline — akan dikirim ulang otomatis saat internet tersedia',
    );
  }

  // ── Bangun payload ────────────────────────────────────────
  Map<String, dynamic> _buildPayload({
    required String invoiceNo,
    required double total,
    required String metode,
    required String pemesan,
    required String catatan,
    required List<Map<String, dynamic>> items,
    required DateTime waktu,
  }) {
    final months = [
      'Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agt','Sep','Okt','Nov','Des'
    ];
    final tanggal =
        '${waktu.day} ${months[waktu.month - 1]} ${waktu.year}';
    final jam =
        '${waktu.hour.toString().padLeft(2,'0')}:'
        '${waktu.minute.toString().padLeft(2,'0')}:'
        '${waktu.second.toString().padLeft(2,'0')}';

    final itemStr =
        items.map((i) => '${i['name']} x${i['qty']}').join(', ');

    return {
      'action':   'addTransaksi',
      'order_id': invoiceNo,
      'tanggal':  tanggal,
      'jam':      jam,
      'pemesan':  pemesan.isEmpty ? 'Pelanggan' : pemesan,
      'catatan':  catatan,
      'items':    itemStr,
      'total':    total.toStringAsFixed(0),
      'metode':   metode,
      // Timestamp untuk deduplikasi di Apps Script
      'timestamp': waktu.millisecondsSinceEpoch.toString(),
    };
  }

  // ── Kirim HTTP ────────────────────────────────────────────
  Future<SheetsResult> _sendPayload(
      Map<String, dynamic> payload) async {
    try {
      final response = await http
          .post(
            Uri.parse(_webhookUrl!),
            headers: {'Content-Type': 'application/json'},
            body:    jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return const SheetsResult(
            success: true,
            status:  SyncStatus.sent,
            message: 'Berhasil dikirim ke Google Sheets');
      }
      return SheetsResult(
          success: false,
          status:  SyncStatus.failed,
          message: 'HTTP ${response.statusCode}');
    } on TimeoutException {
      return const SheetsResult(
          success: false,
          status:  SyncStatus.failed,
          message: 'Timeout — koneksi lambat');
    } catch (e) {
      return SheetsResult(
          success: false,
          status:  SyncStatus.failed,
          message: 'Error: $e');
    }
  }

  // ── Queue management ──────────────────────────────────────

  Future<void> _enqueue(Map<String, dynamic> payload) async {
    final prefs   = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefKeyQueue) ?? [];

    // Cegah duplikat berdasarkan order_id + timestamp
    final key = '${payload['order_id']}_${payload['timestamp']}';
    final exists = rawList.any((s) {
      try {
        final decoded = jsonDecode(s) as Map<String, dynamic>;
        return '${decoded['order_id']}_${decoded['timestamp']}' == key;
      } catch (_) {
        return false;
      }
    });

    if (!exists) {
      rawList.add(jsonEncode(payload));
      await prefs.setStringList(_prefKeyQueue, rawList);
    }
  }

  Future<List<Map<String, dynamic>>> _getQueue() async {
    final prefs   = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefKeyQueue) ?? [];
    return rawList.map((s) {
      try {
        return jsonDecode(s) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();
  }

  Future<void> _removeFromQueue(
      Map<String, dynamic> payload) async {
    final prefs   = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefKeyQueue) ?? [];
    final key     =
        '${payload['order_id']}_${payload['timestamp']}';

    rawList.removeWhere((s) {
      try {
        final decoded = jsonDecode(s) as Map<String, dynamic>;
        return '${decoded['order_id']}_${decoded['timestamp']}' ==
            key;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_prefKeyQueue, rawList);
  }

  Future<void> _clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyQueue);
  }

  // ── Flush queue — kirim semua yang pending ────────────────
  Future<FlushResult> _flushQueue() async {
    if (!isConfigured || _isSyncing) {
      return const FlushResult(sent: 0, failed: 0, remaining: 0);
    }

    _isSyncing = true;
    int sent    = 0;
    int failed  = 0;

    try {
      final queue = await _getQueue();
      if (queue.isEmpty) {
        _isSyncing = false;
        return const FlushResult(sent: 0, failed: 0, remaining: 0);
      }

      debugPrint('📤 Mengirim ${queue.length} antrian ke Sheets...');

      for (final payload in queue) {
        final result = await _sendPayload(payload);
        if (result.success) {
          await _removeFromQueue(payload);
          sent++;
          debugPrint(
              '✅ Antrian terkirim: ${payload['order_id']}');
        } else {
          failed++;
          // Stop jika gagal — kemungkinan masih offline
          break;
        }
      }

      final remaining = (await _getQueue()).length;
      debugPrint(
          '📊 Flush selesai: $sent terkirim, $failed gagal, $remaining sisa');

      return FlushResult(
          sent: sent, failed: failed, remaining: remaining);
    } finally {
      _isSyncing = false;
    }
  }

  // ── Public: manual flush (dipanggil dari UI) ──────────────
  Future<FlushResult> manualFlush() => _flushQueue();

  // ── Status queue ──────────────────────────────────────────
  Future<int> getPendingCount() async {
    final queue = await _getQueue();
    return queue.length;
  }

  Future<List<String>> getPendingInvoices() async {
    final queue = await _getQueue();
    return queue
        .map((p) => p['order_id'] as String? ?? '-')
        .toList();
  }

  // ── Test koneksi ──────────────────────────────────────────
  Future<SheetsResult> testConnection(String url) async {
    try {
      final response = await http
          .post(
            Uri.parse(url.trim()),
            headers: {'Content-Type': 'application/json'},
            body:    jsonEncode({'action': 'ping'}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          if (body['status'] == 'ok') {
            return const SheetsResult(
                success: true,
                status:  SyncStatus.sent,
                message: 'Terhubung ke Google Sheets ✓');
          }
        } catch (_) {}
        return const SheetsResult(
            success: true,
            status:  SyncStatus.sent,
            message: 'Terhubung ✓');
      }
      return SheetsResult(
          success: false,
          status:  SyncStatus.failed,
          message: 'HTTP ${response.statusCode} — cek URL deployment');
    } on TimeoutException {
      return const SheetsResult(
          success: false,
          status:  SyncStatus.failed,
          message: 'Timeout — internet lambat atau URL salah');
    } catch (e) {
      return SheetsResult(
          success: false,
          status:  SyncStatus.failed,
          message: 'Koneksi gagal: $e');
    }
  }
}

// ── Result types ──────────────────────────────────────────

enum SyncStatus { sent, queued, failed, notConfigured }

class SheetsResult {
  final bool       success;
  final SyncStatus status;
  final String     message;

  const SheetsResult({
    required this.success,
    required this.status,
    required this.message,
  });
}

class FlushResult {
  final int sent;
  final int failed;
  final int remaining;

  const FlushResult({
    required this.sent,
    required this.failed,
    required this.remaining,
  });
}