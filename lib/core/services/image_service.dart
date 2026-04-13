import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

// ============================================================
//  IMAGE SERVICE
//  Pick foto dari galeri/kamera, simpan ke app storage
//  Path disimpan di DB sebagai absolute path (bukan asset)
// ============================================================

class ImageService {
  static final ImageService instance = ImageService._();
  ImageService._();

  static const _uuid = Uuid();
  final _picker     = ImagePicker();

  // ── Pick dari galeri ──────────────────────────────────────
  Future<String?> pickFromGallery() async {
    try {
      final picked = await _picker.pickImage(
        source:    ImageSource.gallery,
        maxWidth:  800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return null;
      return await _saveToAppDir(picked.path);
    } catch (e) {
      debugPrint('ImageService.pickFromGallery error: $e');
      return null;
    }
  }

  // ── Pick dari kamera ──────────────────────────────────────
  Future<String?> pickFromCamera() async {
    try {
      final picked = await _picker.pickImage(
        source:       ImageSource.camera,
        maxWidth:     800,
        maxHeight:    800,
        imageQuality: 85,
      );
      if (picked == null) return null;
      return await _saveToAppDir(picked.path);
    } catch (e) {
      debugPrint('ImageService.pickFromCamera error: $e');
      return null;
    }
  }

  // ── Simpan ke folder app ──────────────────────────────────
  Future<String> _saveToAppDir(String sourcePath) async {
    final appDir   = await getApplicationDocumentsDirectory();
    final produkDir = Directory(p.join(appDir.path, 'produk_images'));
    if (!await produkDir.exists()) {
      await produkDir.create(recursive: true);
    }

    final ext      = p.extension(sourcePath).toLowerCase();
    final fileName = 'produk_${_uuid.v4()}$ext';
    final destPath = p.join(produkDir.path, fileName);

    await File(sourcePath).copy(destPath);
    return destPath; // absolute path
  }

  // ── Hapus foto lama ───────────────────────────────────────
  Future<void> deleteIfLocal(String? path) async {
    if (path == null || path.isEmpty) return;
    // Hanya hapus kalau bukan asset bawaan
    if (path.startsWith('assets/')) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('ImageService.deleteIfLocal error: $e');
    }
  }

  // ── Helper: apakah path ini file lokal (bukan asset) ─────
  static bool isLocalFile(String? path) {
    if (path == null || path.isEmpty) return false;
    return !path.startsWith('assets/');
  }
}