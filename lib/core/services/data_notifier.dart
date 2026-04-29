import 'package:flutter/material.dart';

class DataNotifier {
  DataNotifier._();

  static final ValueNotifier<int> _notifier = ValueNotifier<int>(0);

  static void notify() => _notifier.value++;

  static void addListener(VoidCallback cb) => _notifier.addListener(cb);
  static void removeListener(VoidCallback cb) => _notifier.removeListener(cb);
  
  // Tambahkan method untuk get current value
  static int get currentValue => _notifier.value;
}

mixin DataRefreshMixin<T extends StatefulWidget> on State<T> {
  late final VoidCallback _dataRefreshHandler;

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