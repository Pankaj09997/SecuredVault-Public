import 'dart:io';
import 'dart:typed_data';

class ImageUploadEntities {
  final String encryption_name;
  final int image;
  final String status;

  ImageUploadEntities(
      {required this.encryption_name,
      required this.image,
      required this.status});
}

class ImageDownloadEntities {
  final File file;

  ImageDownloadEntities({required this.file});
}

class ImageListEntities {
  final int id;
  final String original_name;
  final String image_type;
  final int image_size;
  final DateTime upload_date;

  ImageListEntities(
      {required this.id,
      required this.original_name,
      required this.image_type,
      required this.image_size,
      required this.upload_date});
}

class ImageAccessLogEntities {
  final int id;
  final String access_time;
  final String action;
  final String ipAddress;
  final DeviceInfoEntities deviceInfoEntities;

  ImageAccessLogEntities(
      {required this.id,
      required this.access_time,
      required this.action,
      required this.ipAddress,
      required this.deviceInfoEntities});
}

class DeviceInfoEntities {
  final String user_agent;
  final String device_id;

  DeviceInfoEntities({required this.user_agent, required this.device_id});
}

class ImageViewEntites {
  final Uint8List imageView;

  ImageViewEntites({required this.imageView});
}

class ImageShareableEntities {
  final String msg;
  final String shared_url;
  final DateTime expires_at;

  ImageShareableEntities(
      {required this.msg, required this.shared_url, required this.expires_at});
}

class DeleteImageEntities {
  final String msg;

  DeleteImageEntities({required this.msg});
}
