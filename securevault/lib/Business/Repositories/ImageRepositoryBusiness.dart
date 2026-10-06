import 'dart:io';

import 'package:securevault/Business/Entities/FilesEntities.dart'
    as files_entities;
import 'package:securevault/Business/Entities/ImageEntities.dart';
import 'package:securevault/Data/DataSource/ImageService.dart';
import 'package:securevault/Data/Models/ImageModels.dart';

abstract class ImageRepositoryBusiness {
  Future<ImageUploadEntities> uploadImage(File file);
  Future<List<ImageAccessLogEntities>> imageAccessLog(int imageId);
  Future<List<ImageListEntities>> imageList();
  Future<ImageDownloadEntities> downloadImage(int imageId);
  Future<ImageViewEntites> viewImage(int imageId);
  Future<ImageShareableEntities> shareLink(String resourceType, int resourceId);
  Future<DeleteImageEntities> deleteImage(int fileId);
}

class ImageRepositoryBusinessImpl extends ImageRepositoryBusiness {
  final ImageService imageService;

  ImageRepositoryBusinessImpl({required this.imageService});

  @override
  Future<ImageUploadEntities> uploadImage(File file) async {
    try {
      final response = await imageService.uploadImage(file);
      final data = UploadImageModels.fromJson(response);
      return ImageUploadEntities(
          encryption_name: data.encryption_name,
          image: data.image,
          status: data.status);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  @override
  Future<List<ImageListEntities>> imageList() async {
    try {
      final response = await imageService.listImages();
      final data = response.map((json) => ListImages.fromJson(json)).toList();
      final imagesLists = data
          .map((json) => ImageListEntities(
              id: json.id,
              original_name: json.original_name,
              image_type: json.image_type,
              image_size: json.image_size,
              upload_date: json.upload_date))
          .toList();
      return imagesLists;
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  @override
  Future<List<ImageAccessLogEntities>> imageAccessLog(int imageId) async {
    try {
      final response = await imageService.accessLog(imageId);
      final data =
          response.map((json) => ImageAccessLog.fromJson(json)).toList();
      final userData = data
          .map((json) => ImageAccessLogEntities(
              id: json.id,
              access_time: json.access_time,
              action: json.action,
              ipAddress: json.ipAddress,
              deviceInfoEntities: DeviceInfoEntities(
                  // Changed from deviceInfoEntities
                  user_agent: json.deviceInfo.user_agent,
                  device_id: json.deviceInfo.device_id)))
          .toList();
      return userData;
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  @override
  Future<ImageDownloadEntities> downloadImage(int imageId) async {
    try {
      final response = await imageService.downloadImage(imageId);
      return ImageDownloadEntities(file: response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  @override
  Future<ImageViewEntites> viewImage(int imageId) async {
    try {
      final response = await imageService.viewImage(imageId);
      return ImageViewEntites(imageView: response);
    } catch (e) {
      throw Exception("Unable to show the image: $e");
    }
  }

  @override
  Future<ImageShareableEntities> shareLink(
      String resourceType, int resourceId) async {
    try {
      final response =
          await imageService.shareableImageLink(resourceType, resourceId);
      final data = ImageSharebaleLink.fromJson(response);
      return ImageShareableEntities(
          msg: data.msg,
          shared_url: data.shared_url,
          expires_at: data.expires_at);
    } catch (e) {
      print("Error in repository:$e");
      throw Exception("Error:$e");
    }
  }

  @override
  Future<DeleteImageEntities> deleteImage(int fileId) async {
    try {
      final response = await imageService.deleteImage(fileId);
      final data = ImageDeleteModels.fromJson(response);
      return DeleteImageEntities(msg: data.msg);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }
}
