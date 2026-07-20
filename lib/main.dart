import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'core/services/firebase_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/sync_service.dart';
import 'features/auth/login_page.dart';
import 'core/services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi sqflite untuk desktop (Linux/Windows/macOS)
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Paksa orientasi portrait di HP, bebas di tablet
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Status bar transparan
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Error handling default (tanpa Firebase, hanya log ke console)
  FlutterError.onError = (details) {
    debugPrint(details.exceptionAsString());
  };

  // Initialize Firebase untuk platform yang didukung dan siap pakai.
  try {
    await FirebaseService.initialize();

    // Crashlytics: semua error terkirim ke dashboard Firebase,
    // bisa dicek dari rumah tanpa harus datang ke warung
    FlutterError.onError = (details) {
      debugPrint(details.exceptionAsString());
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Sync penuh sekali saat startup (push semua + pull dari cloud)
    unawaited(FirebaseService.syncAll());

    // Sync otomatis: timer tiap 5 menit + kirim ulang saat internet kembali
    SyncService.start();
  } catch (e) {
    debugPrint('ℹ️ Firebase dilewati: $e');
  }

  runApp(const SeblakPOSApp());
}

class SeblakPOSApp extends StatelessWidget {
  const SeblakPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
      return FutureBuilder<bool>(
        future: ThemeService.isDarkMode(),
        builder: (context, snapshot) {
          final isDark = snapshot.data ?? false;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Seblak Kacida',
            theme: ThemeService.getLightTheme(),
            darkTheme: ThemeService.getDarkTheme(),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            home: const SplashScreen(),
          );
        },
      );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkPermissionsAndNavigate();
  }

  Future<void> _checkPermissionsAndNavigate() async {
    // Efek splash
    await Future.delayed(const Duration(seconds: 1));

    // Minta izin Bluetooth — pakai method yang benar
    final permissionsGranted = await PermissionService.requestBluetooth();

    if (!permissionsGranted && mounted) {
      // Tampilkan dialog manual jika izin ditolak
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Izin Bluetooth Diperlukan'),
          content: const Text(
            'Aplikasi membutuhkan izin Bluetooth untuk terhubung ke printer.\n\n'
            'Buka Pengaturan dan aktifkan izin Bluetooth untuk aplikasi ini.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Lewati'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await PermissionService.openAppSettings();
              },
              child: const Text('Buka Pengaturan'),
            ),
          ],
        ),
      );
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF6B35),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.restaurant,
                size: 60,
                color: Color(0xFFFF6B35),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SEBLAK KACIDA',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}