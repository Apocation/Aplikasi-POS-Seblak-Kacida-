import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import 'data_notifier.dart';

class BackupService {
  /// Backup = salinan utuh file SQLite (seblak.db).
  /// Isinya SEMUA data: users, produk, transaksi, item transaksi, dan setting toko.
  /// Yang TIDAK ikut: preferensi printer & tema (shared_preferences) dan
  /// gambar produk yang diambil dari kamera/galeri (hanya path-nya yang tersimpan).
  static Future<File?> backupDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final sourceFile = File('$dbPath/seblak.db');

      if (!await sourceFile.exists()) {
        throw Exception('Database tidak ditemukan');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/backups');

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final now = DateTime.now();
      final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
      final backupFile = File('${backupDir.path}/seblak-kacida-backup_$stamp.db');

      await sourceFile.copy(backupFile.path);

      return backupFile;
    } catch (e) {
      debugPrint('Backup error: $e');
      return null;
    }
  }

  /// Buka file picker sistem — bisa memilih file backup dari folder Download,
  /// penyimpanan internal, maupun Google Drive (lewat SAF Android).
  /// Return null kalau user batal memilih.
  static Future<File?> pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Pilih file backup (.db)',
        type: FileType.any,
      );
      final path = result?.files.single.path;
      if (path == null) return null;
      return File(path);
    } catch (e) {
      debugPrint('Pick backup error: $e');
      return null;
    }
  }

  /// Restore: ganti database aktif dengan isi file backup.
  /// Langkah aman:
  /// 1. Validasi file benar-benar database SQLite (cek header file).
  /// 2. Tutup koneksi database yang sedang terbuka.
  /// 3. Salin file backup menimpa database aktif.
  /// Data yang di-restore TIDAK dihapus/direset setelahnya.
  static Future<bool> restoreDatabase(File backupFile) async {
    try {
      if (!await backupFile.exists()) {
        throw Exception('File backup tidak ditemukan');
      }

      // Validasi header SQLite: 16 byte pertama = "SQLite format 3\0"
      final raf = await backupFile.open();
      final header = await raf.read(16);
      await raf.close();
      final headerText = String.fromCharCodes(header.take(15));
      if (headerText != 'SQLite format 3') {
        throw Exception('File yang dipilih bukan file backup database (.db) yang valid');
      }

      final dbPath = await getDatabasesPath();
      final targetPath = '$dbPath/seblak.db';

      // Tutup koneksi lama dulu — tanpa ini file baru tidak akan terbaca
      await DatabaseHelper.instance.close();

      await backupFile.copy(targetPath);

      // Sentuh database sekali supaya langsung terbuka kembali
      // (sekalian menjalankan migrasi versi kalau backup-nya dari versi lama)
      await DatabaseHelper.instance.database;

      DataNotifier.notify();
      return true;
    } catch (e) {
      debugPrint('Restore error: $e');
      return false;
    }
  }

  static Future<List<FileSystemEntity>> getBackupFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/backups');

      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir.list().toList();
      final backups = files.where((file) => file.path.endsWith('.db')).toList();
      // Terbaru di atas
      backups.sort((a, b) => b.path.compareTo(a.path));
      return backups;
    } catch (e) {
      return [];
    }
  }

  static Future<void> shareBackup(File backupFile) async {
    await Share.shareXFiles(
      [XFile(backupFile.path)],
      text: 'Backup database Seblak Kacida - ${DateTime.now().toLocal()}',
    );
  }
}
