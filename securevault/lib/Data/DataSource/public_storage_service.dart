import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

class PublicStorageService {
  static const MethodChannel _channel =
      MethodChannel('securevault/public_storage');

  Future<File> saveToDownloads({
    required Uint8List bytes,
    required String fileName,
    String? folderName,
  }) {
    return _savePublicFile(
      bytes: bytes,
      fileName: fileName,
      directory: 'downloads',
      folderName: folderName,
    );
  }

  /// Saves a file from an existing path to the Downloads folder.
  /// Copies the file instead of loading bytes into RAM — ideal for
  /// large files from the streaming receive flow.
  Future<File> saveFromFile({
    required File sourceFile,
    required String fileName,
    String? folderName,
  }) async {
    final safeName = sanitizeFileName(fileName);

    if (Platform.isAndroid) {
      // For Android, read bytes and use the platform channel
      // (MediaStore requires bytes). For very large files, consider
      // implementing a streaming platform channel in the future.
      final bytes = await sourceFile.readAsBytes();
      final savedPath = await _channel.invokeMethod<String>('saveFile', {
        'bytes': bytes,
        'fileName': safeName,
        'directory': 'downloads',
        'folderName': folderName,
        'mimeType': lookupMimeType(safeName) ?? 'application/octet-stream',
      });

      if (savedPath == null || savedPath.isEmpty) {
        throw Exception('Unable to save file to public storage.');
      }

      // Clean up the temp file
      try {
        await sourceFile.delete();
      } catch (_) {}

      return File(savedPath);
    }

    // For iOS/desktop, copy the file directly (no RAM spike)
    final baseDir = await _fallbackDirectory('downloads');
    final targetDir = folderName == null || folderName.trim().isEmpty
        ? baseDir
        : Directory('${baseDir.path}/${sanitizeFolderName(folderName)}');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final destFile = await availableFile(targetDir, safeName);
    await sourceFile.copy(destFile.path);

    // Clean up the temp file
    try {
      await sourceFile.delete();
    } catch (_) {}

    return destFile;
  }

  Future<File> _savePublicFile({
    required Uint8List bytes,
    required String fileName,
    required String directory,
    String? folderName,
  }) async {
    final safeName = sanitizeFileName(fileName);

    if (Platform.isAndroid) {
      final savedPath = await _channel.invokeMethod<String>('saveFile', {
        'bytes': bytes,
        'fileName': safeName,
        'directory': directory,
        'folderName': folderName,
        'mimeType': lookupMimeType(safeName) ?? 'application/octet-stream',
      });

      if (savedPath == null || savedPath.isEmpty) {
        throw Exception('Unable to save file to public storage.');
      }
      return File(savedPath);
    }

    final baseDir = await _fallbackDirectory(directory);
    final targetDir = folderName == null || folderName.trim().isEmpty
        ? baseDir
        : Directory('${baseDir.path}/${sanitizeFolderName(folderName)}');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final file = await availableFile(targetDir, safeName);
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<Directory> _fallbackDirectory(String directory) async {
    if (directory == 'downloads') {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return downloadsDir;
      }
    }

    return getApplicationDocumentsDirectory();
  }

  static String sanitizeFileName(String fileName) {
    final sanitized = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'securevault-file' : sanitized;
  }

  static String sanitizeFolderName(String folderName) {
    final sanitized =
        folderName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'SecureVault' : sanitized;
  }

  static Future<File> availableFile(
      Directory directory, String fileName) async {
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final extension = dotIndex > 0 ? fileName.substring(dotIndex) : '';

    var candidate = File('${directory.path}/$fileName');
    var suffix = 1;
    while (await candidate.exists()) {
      candidate = File('${directory.path}/$baseName ($suffix)$extension');
      suffix++;
    }
    return candidate;
  }
}
