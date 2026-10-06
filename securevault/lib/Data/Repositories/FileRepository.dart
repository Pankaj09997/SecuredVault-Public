import 'dart:io';

import 'package:securevault/Data/DataSource/FilesService.dart';
import 'package:securevault/Data/Models/FileModels.dart';

class FileRepository {
  final FilesService filesService;

  FileRepository({required this.filesService});

  Future<FileUpload> fileUploadRepository(File file,
      {required String vaultPassword}) async {
    try {
      final response =
          await filesService.uploadFiles(file, vaultPassword: vaultPassword);
      return FileUpload.fromJson(response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<List<FileAccessLog>> fileAccessLog(int fileId) async {
    try {
      final response = await filesService.fileAccessLog(fileId);
      return response.map((json) => FileAccessLog.fromJson(json)).toList();
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<DownloadFile> downloadFile(int fileId,
      {required String vaultPassword}) async {
    try {
      final response =
          await filesService.downloadFile(fileId, vaultPassword: vaultPassword);
      return DownloadFile(file: response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<List<ListFiles>> listFiles() async {
    try {
      final response = await filesService.listFiles();
      return response.map((json) => ListFiles.fromJson(json)).toList();
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<FileViewModels> fileViewRepository(int fileId,
      {required String vaultPassword}) async {
    try {
      final response =
          await filesService.viewFiles(fileId, vaultPassword: vaultPassword);
      return FileViewModels(bytes: response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<ShareableLink> shareableLink(
      String resourceType, int resourceId) async {
    try {
      final response = await filesService.createLink(resourceType, resourceId);
      return ShareableLink.fromJson(response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<DeleteFile> deleteFile(int fileId) async {
    try {
      final response = await filesService.deleteFile(fileId);
      return DeleteFile.fromJson(response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }
}
