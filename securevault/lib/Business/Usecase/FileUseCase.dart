import 'dart:io';

import 'package:securevault/Business/Entities/FilesEntities.dart';
import 'package:securevault/Business/Repositories/FileRepository.dart';
import 'package:securevault/Data/DataSource/FilesService.dart';
import 'package:securevault/Data/Models/FileModels.dart';
import 'package:securevault/Data/Repositories/FileRepository.dart';

class FileUploadUseCase {
  final FileRepositoryBusiness fileRepositoryBusiness;

  FileUploadUseCase({required this.fileRepositoryBusiness});

  Future<FileUploadEntities> fileUpload(File file,
      {required String vaultPassword}) async {
    return fileRepositoryBusiness.uploadFile(file,
        vaultPassword: vaultPassword);
  }
}

class FileAccessLogUseCase {
  final FileRepositoryBusiness fileRepositoryBusiness;

  FileAccessLogUseCase({required this.fileRepositoryBusiness});
  Future<List<FileAccessEntities>> accessFiles(int fileId) async {
    return fileRepositoryBusiness.accessLogFile(fileId);
  }
}

class ListFilesUseCase {
  final FileRepositoryBusiness fileRepositoryBusiness;

  ListFilesUseCase({required this.fileRepositoryBusiness});
  Future<List<ListFileEntities>> listFiles() async {
    return fileRepositoryBusiness.listFiles();
  }
}

class DownloadFilesUseCase {
  final FileRepositoryBusiness fileRepositoryBusiness;

  DownloadFilesUseCase({required this.fileRepositoryBusiness});
  Future<DownloadFileEntities> downloadFiles(int fileId,
      {required String vaultPassword}) async {
    return fileRepositoryBusiness.downloadFile(fileId,
        vaultPassword: vaultPassword);
  }
}

class FileViewUseCase {
  final FileRepositoryBusiness fileRepositoryBusiness;

  FileViewUseCase({required this.fileRepositoryBusiness});
  Future<FilesViewEntities> viewFiles(int fileId,
      {required String vaultPassword}) async {
    return fileRepositoryBusiness.viewFiles(fileId,
        vaultPassword: vaultPassword);
  }
}

class FileShareableLinkUseCase {
  final FileRepositoryBusiness fileRepositoryBusiness;

  FileShareableLinkUseCase({required this.fileRepositoryBusiness});
  Future<ShareableLinkEntities> shareableLink(
      String resourceType, int resourceId) async {
    final response =
        await fileRepositoryBusiness.shareableLink(resourceType, resourceId);
    return response;
  }
}

class DeleteFileUseCase {
  final FileRepositoryBusiness fileRepositoryBusiness;

  DeleteFileUseCase({required this.fileRepositoryBusiness});

  Future<DeleteFileEntities> deleteFilesUseCase(int fileId) async {
    final response = await fileRepositoryBusiness.deleteFiles(fileId);
    return response;
  }
}
