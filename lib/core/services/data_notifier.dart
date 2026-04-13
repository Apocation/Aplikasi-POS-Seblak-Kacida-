import 'package:flutter/material.dart';



// ============================================================
//  DATA NOTIFIER
//  Taruh di: lib/core/services/data_notifier.dart
// ============================================================

class DataNotifier {
  DataNotifier._();

  static final ValueNotifier<int> _notifier = ValueNotifier<int>(0);

  /// Panggil setelah ada perubahan di database
  static void notify() => _notifier.value++;

  static void addListener(VoidCallback cb) =>
      _notifier.addListener(cb);

  static void removeListener(VoidCallback cb) =>
      _notifier.removeListener(cb);
}

// ============================================================
//  MIXIN
//  Cara pakai:
//
//    class _MyPageState extends State<MyPage>
//        with DataRefreshMixin {
//
//      @override
//      void onDataChanged() => _load();
//    }
// ============================================================

mixin DataRefreshMixin<T extends StatefulWidget> on State<T> {
  // Simpan sebagai field agar referensi sama saat remove
  late final VoidCallback _dataRefreshHandler;

  /// Override ini dengan method reload data halaman
  void onDataChanged();

  @override
  void initState() {
    super.initState();
    _dataRefreshHandler = () {
      if (mounted) onDataChanged();
    };
    DataNotifier.addListener(_dataRefreshHandler);
  }

  @override
  void dispose() {
    DataNotifier.removeListener(_dataRefreshHandler);
    super.dispose();
  }
}