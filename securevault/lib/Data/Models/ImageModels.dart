import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'dart:typed_data' as typed_data;

class UploadImageModels {
  final String encryption_name;
  final int image;
  final String status;

  UploadImageModels(
      {required this.encryption_name,
      required this.image,
      required this.status});

  factory UploadImageModels.fromJson(Map<String, dynamic> json) {
    return UploadImageModels(
        encryption_name: json['encryption_name']??'',
        image: json['image']??0,
        status: json['status']??'');
  }
}

class ListImages {
  final int id;
  final String original_name;
  final String image_type;
  final int image_size;
  final DateTime upload_date;

  ListImages(
      {required this.id,
      required this.original_name,
      required this.image_type,
      required this.image_size,
      required this.upload_date});

  factory ListImages.fromJson(Map<String, dynamic> json) {
    return ListImages(
        id: json['id']??0,
        original_name: json['original_name'] ?? '',
        image_type: json['image_type'] ?? '',
        image_size: json['image_size'] ?? 0,
        upload_date: DateTime.parse(json['upload_date']));
  }
}

class DownloadImage {
  final File file;

  DownloadImage({required this.file});
}

class ImageAccessLog {
  final int id;
  final String access_time;
  final String action;
  final String ipAddress;
  final DeviceInfo deviceInfo;

  ImageAccessLog(
      {required this.id,
      required this.access_time,
      required this.action,
      required this.ipAddress,
      required this.deviceInfo});

  factory ImageAccessLog.fromJson(Map<String, dynamic> json) {
    return ImageAccessLog(
        id: json['id'] ??'',
        access_time: json['access_time']??'',
        action: json['action']??"",
        ipAddress: json['ipAddress']??"",
        deviceInfo: DeviceInfo.fromJson(jsonDecode(json['device_info'])));
  }
}

class DeviceInfo {
  final String user_agent;
  final String device_id;

  DeviceInfo({required this.user_agent, required this.device_id});

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
        user_agent: json['user_agent']??'', device_id: json['device_id']??'');
  }
}

class ViewImageModels {
  final typed_data.Uint8List imageBytes;

  ViewImageModels({required this.imageBytes});
}

class ImageSharebaleLink {
  final String msg;
  final String shared_url;
  final DateTime expires_at;

  ImageSharebaleLink(
      {required this.msg, required this.shared_url, required this.expires_at});
  factory ImageSharebaleLink.fromJson(Map<String, dynamic> json) {
    return ImageSharebaleLink(
        msg: json['msg']??'',
        shared_url: json['shared_url']??"",
        expires_at: DateTime.parse(json['expires_at']));
  }
}

class ImageDeleteModels {
  final String msg;

  ImageDeleteModels({required this.msg});
  factory ImageDeleteModels.fromJson(Map<String, dynamic> json) {
    return ImageDeleteModels(
      msg: json['msg'] ??""
      );
  }
}
