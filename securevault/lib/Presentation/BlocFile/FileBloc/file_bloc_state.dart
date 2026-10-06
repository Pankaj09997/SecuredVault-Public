part of 'file_bloc_bloc.dart';

@immutable
sealed class FileBlocState {}

final class FileBlocInitial extends FileBlocState {}

final class FileBlocLoading extends FileBlocState {}

final class FileBlocSuccess extends FileBlocState {}

final class FileBlocFailure extends FileBlocState {
  final String message;

  FileBlocFailure({required this.message});
}

final class FileDownloadInProgress extends FileBlocState {
  final int fileId;

  FileDownloadInProgress({required this.fileId});
}

final class FileUploadSuccess extends FileBlocState {
  final FileUploadEntities fileUploadEntities;

  FileUploadSuccess({required this.fileUploadEntities});
}

final class FileDownloadSuccess extends FileBlocState {
  final DownloadFileEntities downloadFileEntities;
  final int fileId;
  final String fileName;

  FileDownloadSuccess(
      {required this.fileName,
      required this.downloadFileEntities,
      required this.fileId});
}

final class FileAccessLog extends FileBlocState {
  final List<FileAccessEntities> fileAccessEntities;

  FileAccessLog({required this.fileAccessEntities});
}

final class FileList extends FileBlocState {
  final List<ListFileEntities> fileList;

  FileList({required this.fileList});
}

final class FileViewState extends FileBlocState {
  final String fileExtension;
  final FilesViewEntities filesViewEntities;

  FileViewState({required this.fileExtension, required this.filesViewEntities});
}

final class ShareableLinkState extends FileBlocState {
  final ShareableLinkEntities shareableLinkEntities;

  ShareableLinkState({required this.shareableLinkEntities});
}

final class DeleteFileState extends FileBlocState {
  final DeleteFileEntities deleteFileEntities;

  DeleteFileState({required this.deleteFileEntities});
}
