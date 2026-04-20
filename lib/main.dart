import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/firebase_service.dart';
import 'firebase_options.dart';  

import 'theme.dart';
import 'features/auth/login_page.dart';

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

  // Status bar transparan (biar nyambung sama theme)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      statusBarIconBrightness:  Brightness.dark,
      statusBarBrightness:      Brightness.light,
    ),
  );
  // Error handling
FlutterError.onError = (details) {
    debugPrint(details.exceptionAsString());
  };

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Firebase sync
  FirebaseService.syncAll();

  // await FirebaseService.clearDuplicateProducts();

  runApp(const SeblakPOSApp());


}

class SeblakPOSApp extends StatelessWidget {
  const SeblakPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
title:  'Seblak Kacida',
      theme:  posTheme,
      home:   const LoginPage(),
    );
  }
}