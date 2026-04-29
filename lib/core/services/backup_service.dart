import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class BackupService {
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
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final backupFile = File('${backupDir.path}/backup_$timestamp.db');
      
      await sourceFile.copy(backupFile.path);
      
      return backupFile;
    } catch (e) {
      print('Backup error: $e');
      return null;
    }
  }
  
  static Future<bool> restoreDatabase(File backupFile) async {
    try {
      final dbPath = await getDatabasesPath();
      final sourceFile = File('$dbPath/seblak.db');
      
      if (await sourceFile.exists()) {
        await sourceFile.delete();
      }
      
      await backupFile.copy(sourceFile.path);
      
      await DatabaseHelper.instance.resetDatabase();
      
      return true;
    } catch (e) {
      print('Restore error: $e');
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
      return files.where((file) => file.path.endsWith('.db')).toList();
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