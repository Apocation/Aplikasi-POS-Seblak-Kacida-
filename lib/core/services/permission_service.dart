import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestBluetooth() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // Required for Android 12+
    ].request();
    
    bool granted = statuses[Permission.bluetooth]?.isGranted == true &&
                   statuses[Permission.bluetoothScan]?.isGranted == true &&
                   statuses[Permission.bluetoothConnect]?.isGranted == true;
    
    if (!granted) {
      // Open app settings if permissions denied
      await openAppSettings();
    }
    
    return granted;
  }
  
  static Future<bool> hasBluetoothPermission() async {
    final status = await Permission.bluetooth.status;
    return status.isGranted;
  }
  
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}

