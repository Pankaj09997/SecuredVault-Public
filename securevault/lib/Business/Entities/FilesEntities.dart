import 'dart:io' show File;
import 'dart:typed_data';

class FileUploadEntities {
  final String status;
  final int file_id;
  final String encryption_name;

  FileUploadEntities(
      {required this.status,
      required this.file_id,
      required this.encryption_name});
}

class FileAccessEntities {
  final String user__email;
  final String access_time;
  final String action;
  final String ip_address;
  final DeviceInfoEntities deviceInfoEntities;

  FileAccessEntities(
      {required this.user__email,
      required this.access_time,
      required this.action,
      required this.ip_address,
      required this.deviceInfoEntities});
}

class DeviceInfoEntities {
  final String user_agent;
  final String? device_id;

  DeviceInfoEntities({required this.user_agent, required this.device_id});
}

class DownloadFileEntities {
  final File file;

  DownloadFileEntities({required this.file});
}

class ListFileEntities {
  final int id;
  final String original_name;
  final String file_type;
  final int file_size;
  final DateTime upload_date;

  ListFileEntities(
      {required this.id,
      required this.original_name,
      required this.file_type,
      required this.file_size,
      required this.upload_date});
}

class FilesViewEntities {
  final Uint8List file;

  FilesViewEntities({required this.file});
}

class ShareableLinkEntities {
  final String msg;
  final String shared_url;
  final DateTime expires_at;

  ShareableLinkEntities(
      {required this.msg, required this.shared_url, required this.expires_at});
}

class DeleteFileEntities {
  final String message;

  DeleteFileEntities({required this.message});
}
