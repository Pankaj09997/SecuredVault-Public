import 'dart:io';

import 'package:flutter/material.dart';
import 'package:securevault/Data/DataSource/ImageService.dart';
import 'package:securevault/Data/Models/ImageModels.dart';
import 'dart:typed_data' as typed_data;

class ImageRepository {
  final ImageService imageService;

  ImageRepository({required this.imageService});

  Future<UploadImageModels> uploadImage(File file) async {
    try {
      final response = await imageService.uploadImage(file);
      return UploadImageModels.fromJson(response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<List<ListImages>> listImages() async {
    try {
      final response = await imageService.listImages();
      return response.map((json) => ListImages.fromJson(json)).toList();
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<DownloadImage> downloadImages(int imageId) async {
    try {
      final response = await imageService.downloadImage(imageId);
      return DownloadImage(file: response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<List<ImageAccessLog>> imageAccessLog(int imageId) async {
    try {
      final response = await imageService.accessLog(imageId);
      return response.map((json) => ImageAccessLog.fromJson(json)).toList();
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<ViewImageModels> viewImageModels(int imageId) async {
    try {
      final response = await imageService.viewImage(imageId);
      return ViewImageModels(imageBytes: response);
    } catch (e) {
      throw Exception("Unable to show the images");
    }
  }

  Future<ImageSharebaleLink> imageShareableLink(
      String resourceType, int resourceId) async {
    try {
      final response =
          await imageService.shareableImageLink(resourceType, resourceId);
      return ImageSharebaleLink.fromJson(response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<ImageDeleteModels> deleteImage(int fileId) async {
    try {
      final response = await imageService.deleteImage(fileId);
      return ImageDeleteModels.fromJson(response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }
}
