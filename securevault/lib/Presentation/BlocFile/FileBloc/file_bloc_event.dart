part of 'file_bloc_bloc.dart';

@immutable
sealed class FileBlocEvent {}

final class GetFilesEvent extends FileBlocEvent {}

final class DownloadFilesEvent extends FileBlocEvent {
  final int file_id;
  final String vaultPassword;

  DownloadFilesEvent({required this.file_id, required this.vaultPassword});
}

final class UploadFilesEvent extends FileBlocEvent {
  final File file;
  final String vaultPassword;

  UploadFilesEvent({required this.file, required this.vaultPassword});
}

final class GetAccessLog extends FileBlocEvent {
  final int file_id;

  GetAccessLog({required this.file_id});
}

final class ViewFileEvent extends FileBlocEvent {
  final int file_id;
  final String vaultPassword;

  ViewFileEvent({required this.file_id, required this.vaultPassword});
}

final class ShareableLinkEvent extends FileBlocEvent {
  static const resource_type = "File";
  final int resource_id;

  ShareableLinkEvent({required this.resource_id});
}

final class DeleteFileEvent extends FileBlocEvent {
  final int file_id;

  DeleteFileEvent({required this.file_id});
}
