import 'dart:io';
import 'dart:typed_data';

import 'package:securevault/Business/Entities/FilesEntities.dart';
import 'package:securevault/Data/DataSource/FilesService.dart';
import 'package:securevault/Data/Models/FileModels.dart';

abstract class FileRepositoryBusiness {
  Future<FileUploadEntities> uploadFile(File file,
      {required String vaultPassword});
  Future<List<FileAccessEntities>> accessLogFile(int fileId);
  Future<DownloadFileEntities> downloadFile(int fileId,
      {required String vaultPassword});
  Future<List<ListFileEntities>> listFiles();
  Future<FilesViewEntities> viewFiles(int fileId,
      {required String vaultPassword});
  Future<ShareableLinkEntities> shareableLink(
      String resourceType, int resourceId);
  Future<DeleteFileEntities> deleteFiles(int fileId);
}

class FileRepositoryImpl extends FileRepositoryBusiness {
  final FilesService filesService;

  FileRepositoryImpl({required this.filesService});
  @override
  Future<FileUploadEntities> uploadFile(File file,
      {required String vaultPassword}) async {
    try {
      final response =
          await filesService.uploadFiles(file, vaultPassword: vaultPassword);
      final data = FileUpload.fromJson(response);
      return FileUploadEntities(
          status: data.status,
          file_id: data.file_id,
          encryption_name: data.encryption_name);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  @override
  Future<List<FileAccessEntities>> accessLogFile(int fileId) async {
    try {
      final response = await filesService.fileAccessLog(fileId);
      final data =
          response.map((json) => FileAccessLog.fromJson(json)).toList();
      final userData = data
          .map((json) => FileAccessEntities(
              user__email: json.user__email,
              access_time: json.access_time,
              action: json.action,
              ip_address: json.ip_address,
              deviceInfoEntities: DeviceInfoEntities(
                  user_agent: json.deviceInfo.user_agent,
                  device_id: json.deviceInfo.device_id)))
          .toList();
      return userData;
    } catch (e) {
      throw Exception("Error$e");
    }
  }

  @override
  Future<DownloadFileEntities> downloadFile(int fileId,
      {required String vaultPassword}) async {
    try {
      final response =
          await filesService.downloadFile(fileId, vaultPassword: vaultPassword);
      final data = DownloadFile(file: response);
      return DownloadFileEntities(file: response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  @override
  Future<List<ListFileEntities>> listFiles() async {
    try {
      final response = await filesService.listFiles();
      final data = response.map((json) => ListFiles.fromJson(json)).toList();
      final userData = data
          .map((json) => ListFileEntities(
              id: json.id,
              original_name: json.original_name,
              file_type: json.file_type,
              file_size: json.file_size,
              upload_date: json.upload_date))
          .toList();
      return userData;
    } catch (e) {
      throw Exception("Error $e");
    }
  }

  @override
  Future<FilesViewEntities> viewFiles(int fileId,
      {required String vaultPassword}) async {
    try {
      final response =
          await filesService.viewFiles(fileId, vaultPassword: vaultPassword);
      final data = FileViewModels(bytes: response);
      return FilesViewEntities(file: response);
    } catch (e) {
      if (e.toString().contains(
          "Vault password is incorrect or the encrypted file was altered.")) {
        throw Exception("Vault password is incorrect.");
      }
      throw Exception("Unable to view the file");
    }
  }

  @override
  Future<ShareableLinkEntities> shareableLink(
      String resourceType, int resourceId) async {
    try {
      final response = await filesService.createLink(resourceType, resourceId);
      final data = ShareableLink.fromJson(response);
      return ShareableLinkEntities(
          msg: data.msg,
          shared_url: data.shared_url,
          expires_at: data.expires_at);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  @override
  Future<DeleteFileEntities> deleteFiles(int fileId) async {
    try {
      final response = await filesService.deleteFile(fileId);
      final data = DeleteFile.fromJson(response);
      return DeleteFileEntities(message: data.msg);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }
}
