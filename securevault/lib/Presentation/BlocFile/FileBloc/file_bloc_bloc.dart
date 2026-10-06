import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:securevault/Business/Entities/FilesEntities.dart';
import 'package:securevault/Business/Usecase/FileUseCase.dart';

part 'file_bloc_event.dart';
part 'file_bloc_state.dart';

class FileBlocBloc extends Bloc<FileBlocEvent, FileBlocState> {
  final FileUploadUseCase fileUploadUseCase;
  final FileAccessLogUseCase fileAccessLogUseCase;
  final ListFilesUseCase listFilesUseCase;
  final DownloadFilesUseCase downloadFilesUseCase;
  final FileViewUseCase fileViewUseCase;
  final FileShareableLinkUseCase fileShareableLinkUseCase;
  final DeleteFileUseCase deleteFileUseCase;
  FileBlocBloc(
      this.fileUploadUseCase,
      this.fileAccessLogUseCase,
      this.listFilesUseCase,
      this.downloadFilesUseCase,
      this.fileViewUseCase,
      this.fileShareableLinkUseCase,
      this.deleteFileUseCase)
      : super(FileBlocInitial()) {
    on<DownloadFilesEvent>(downloadFilesEvent);
    on<UploadFilesEvent>(uploadFilesEvent);
    on<GetAccessLog>(getAccessLog);
    on<GetFilesEvent>(getFilesEvent);
    on<ViewFileEvent>(viewFileEvent);
    on<ShareableLinkEvent>(shareableLinkEvent);
    on<DeleteFileEvent>(deleteFileEvent);
  }
  Future<void> getFilesEvent(
      GetFilesEvent event, Emitter<FileBlocState> emit) async {
    emit(FileBlocLoading());
    try {
      final response = await listFilesUseCase.listFiles();
      emit(FileList(fileList: response));
    } catch (e) {
      emit(FileBlocFailure(message: "$e"));
    }
  }

  Future<void> getAccessLog(
      GetAccessLog event, Emitter<FileBlocState> emit) async {
    emit(FileBlocLoading());
    try {
      final response = await fileAccessLogUseCase.accessFiles(event.file_id);
      emit(FileAccessLog(fileAccessEntities: response));
    } catch (e) {
      emit(FileBlocFailure(message: "$e"));
    }
  }

  Future<void> uploadFilesEvent(
      UploadFilesEvent event, Emitter<FileBlocState> emit) async {
    emit(FileBlocLoading());
    try {
      final response = await fileUploadUseCase.fileUpload(event.file,
          vaultPassword: event.vaultPassword);
      emit(FileUploadSuccess(fileUploadEntities: response));
      emit(FileBlocSuccess());
    } catch (e) {
      emit(FileBlocFailure(message: "$e"));
    }
  }

  Future<void> downloadFilesEvent(
      DownloadFilesEvent event, Emitter<FileBlocState> emit) async {
    emit(FileDownloadInProgress(fileId: event.file_id));
    try {
      final response = await downloadFilesUseCase.downloadFiles(event.file_id,
          vaultPassword: event.vaultPassword);
      final fileList = await listFilesUseCase.listFiles();
      // firstwhere is mainly used with the conditions
      final file = fileList.firstWhere((f) => f.id == event.file_id);
      emit(FileDownloadSuccess(
        downloadFileEntities: response,
        fileId: event.file_id,
        fileName: file.original_name,
      ));

      emit(FileList(fileList: fileList));
    } catch (e) {
      emit(FileBlocFailure(message: "$e"));
    }
  }

  Future<void> viewFileEvent(
      ViewFileEvent event, Emitter<FileBlocState> emit) async {
    emit(FileBlocLoading());
    try {
      print('Starting file view for ID: ${event.file_id}');
      final response = await fileViewUseCase.fileRepositoryBusiness
          .viewFiles(event.file_id, vaultPassword: event.vaultPassword);
      print('Received file data. Bytes length: ${response.file.length}');

      final fileList = await listFilesUseCase.listFiles();
      print('Fetched ${fileList.length} files in list');
      final fileExtension = fileList.firstWhere((p) => p.id == event.file_id);
      print('Determined extension: ${fileExtension.original_name}');
      if (response.file.isEmpty) {
        print('WARNING: Received empty file data!');
      }

      emit(FileViewState(
          filesViewEntities: response,
          fileExtension: fileExtension.original_name));
      emit(FileList(fileList: fileList));
    } catch (e) {
      emit(FileBlocFailure(message: "$e"));
      final fileList = await listFilesUseCase.listFiles();
      emit(FileList(fileList: fileList));
    }
  }

  Future<void> shareableLinkEvent(
      ShareableLinkEvent event, Emitter<FileBlocState> emit) async {
    try {
      final response = await fileShareableLinkUseCase.shareableLink(
          ShareableLinkEvent.resource_type, event.resource_id);
      final fileList = await listFilesUseCase.listFiles();

      emit(ShareableLinkState(shareableLinkEntities: response));
      emit(FileList(fileList: fileList));
    } catch (e) {
      emit(FileBlocFailure(message: "$e"));
    }
  }

  Future<void> deleteFileEvent(
      DeleteFileEvent event, Emitter<FileBlocState> emit) async {
    try {
      final response = await deleteFileUseCase.fileRepositoryBusiness
          .deleteFiles(event.file_id);
      final fileList = await listFilesUseCase.listFiles();
      emit(DeleteFileState(deleteFileEntities: response));
      emit(FileList(fileList: fileList));
    } catch (e) {
      emit(FileBlocFailure(message: "$e"));
    }
  }
}
