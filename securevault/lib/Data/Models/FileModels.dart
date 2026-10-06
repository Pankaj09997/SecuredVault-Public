import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class FileUpload {
  final String status;
  final int file_id;
  final String encryption_name;

  FileUpload(
      {required this.status,
      required this.file_id,
      required this.encryption_name});

  factory FileUpload.fromJson(Map<String, dynamic> json) {
    return FileUpload(
        status: json['status'],
        file_id: json['file_id'],
        encryption_name: json['encryption_name']);
  }
}

class FileAccessLog {
  final String user__email;
  final String access_time;
  final String action;
  final String ip_address;
  final DeviceInfo deviceInfo;

  FileAccessLog(
      {required this.user__email,
      required this.access_time,
      required this.action,
      required this.ip_address,
      required this.deviceInfo});

  factory FileAccessLog.fromJson(Map<String, dynamic> json) {
    return FileAccessLog(
        user__email: json['user__email'],
        access_time: json['access_time'],
        action: json['action'],
        ip_address: json['ip_address'],
        deviceInfo: DeviceInfo.fromJson(jsonDecode(json['device_info'])));
  }
}

class DeviceInfo {
  final String user_agent;
  final String? device_id;

  DeviceInfo({required this.user_agent, required this.device_id});

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
        user_agent: json['user_agent'], device_id: json['device_id']);
  }
}

class DownloadFile {
  final File file;

  DownloadFile({required this.file});
}

class ListFiles {
  final int id;
  final String original_name;
  final String file_type;
  final int file_size;
  final DateTime upload_date;

  ListFiles(
      {required this.id,
      required this.original_name,
      required this.file_type,
      required this.file_size,
      required this.upload_date});

  factory ListFiles.fromJson(Map<String, dynamic> json) {
    return ListFiles(
        id: json['id'],
        original_name: json['original_name'],
        file_type: json['file_type'],
        file_size: json['file_size'],
        upload_date: DateTime.parse(json['upload_date']));
  }
}

class FileViewModels {
  final Uint8List bytes;

  FileViewModels({required this.bytes});
}

class ShareableLink {
  final String msg;
  final String shared_url;
  final DateTime expires_at;

  ShareableLink(
      {required this.msg, required this.shared_url, required this.expires_at});

  factory ShareableLink.fromJson(Map<String, dynamic> json) {
    return ShareableLink(
        msg: json['msg'] ?? "",
        shared_url: json['shared_url'] ?? "",
        expires_at: DateTime.parse(json['expires_at'] ?? ""));
  }
}

class DeleteFile {
  final String msg;

  DeleteFile({required this.msg});
  factory DeleteFile.fromJson(Map<String, dynamic> json) {
    return DeleteFile(msg: json['msg'] ?? "");
  }
}
