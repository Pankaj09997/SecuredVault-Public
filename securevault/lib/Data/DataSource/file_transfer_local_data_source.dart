import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:securevault/Data/DataSource/public_storage_service.dart';

/// Saves received files to the device's local filesystem.
///
/// After the full E2EE receive flow (decrypt + verify), the plaintext
/// bytes are passed here for persistent storage. Files are saved into a
/// user-visible Downloads/SecuredVault transfers folder.
class FileTransferLocalDataSource {
  Future<String> saveFile(Uint8List data, String fileName) async {
    final file = await PublicStorageService().saveToDownloads(
      bytes: data,
      fileName: fileName,
      folderName: 'SecuredVault transfers',
    );
    return file.path;
  }

  /// Moves a temp file to the Downloads folder without loading into RAM.
  /// Used by the streaming receive flow — the decrypted data is already
  /// on disk in a temp file, so we just move/copy it to the final location.
  Future<String> saveFileFromPath(String tempFilePath, String fileName) async {
    final savedFile = await PublicStorageService().saveFromFile(
      sourceFile: File(tempFilePath),
      fileName: fileName,
      folderName: 'SecuredVault transfers',
    );
    return savedFile.path;
  }
}

