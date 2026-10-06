import 'dart:io';

import 'package:securevault/Business/Entities/FilesEntities.dart';
import 'package:securevault/Business/Entities/ImageEntities.dart';
import 'package:securevault/Business/Repositories/ImageRepositoryBusiness.dart';
import 'package:securevault/Data/DataSource/ImageService.dart';

class UploadImageUseCase {
  final ImageRepositoryBusiness imageRepositoryBusiness;

  UploadImageUseCase({required this.imageRepositoryBusiness});
  Future<ImageUploadEntities> imageUpload(File file) async {
    return await imageRepositoryBusiness.uploadImage(file);
  }
}

class ListImagesUseCase {
  final ImageRepositoryBusiness imageRepositoryBusiness;

  ListImagesUseCase({required this.imageRepositoryBusiness});
  Future<List<ImageListEntities>> listImages() async {
    return await imageRepositoryBusiness.imageList();
  }
}

class DownloadImageUseCase {
  final ImageRepositoryBusiness imageRepositoryBusiness;

  DownloadImageUseCase({required this.imageRepositoryBusiness});
  Future<ImageDownloadEntities> imageDownload(int imageId) async {
    return imageRepositoryBusiness.downloadImage(imageId);
  }
}

class ImageAccessLogUseCase {
  final ImageRepositoryBusiness imageRepositoryBusiness;

  ImageAccessLogUseCase({required this.imageRepositoryBusiness});
  Future<List<ImageAccessLogEntities>> imageAccess(int imageId) async {
    return imageRepositoryBusiness.imageAccessLog(imageId);
  }
}

class ImageViewUseCase {
  final ImageRepositoryBusiness imageRepositoryBusiness;

  ImageViewUseCase({required this.imageRepositoryBusiness});
  Future<ImageViewEntites> imageViewEntities(int imageId) async {
    return imageRepositoryBusiness.viewImage(imageId);
  }
}

class ImageShareableLinkUseCase {
  final ImageRepositoryBusiness imageRepositoryBusiness;

  ImageShareableLinkUseCase({required this.imageRepositoryBusiness});
  Future<ImageShareableEntities> imageShareableLink(
      String resourceType, int resourceId) async {
    final response =
        await imageRepositoryBusiness.shareLink(resourceType, resourceId);
    return response;
  }
}

class DeleteImageUseCase {
  final ImageRepositoryBusiness imageRepositoryBusiness;

  DeleteImageUseCase({required this.imageRepositoryBusiness});
  Future<DeleteImageEntities> deleteImageEntities(int fileId) async {
    return imageRepositoryBusiness.deleteImage(fileId);
  }
}
