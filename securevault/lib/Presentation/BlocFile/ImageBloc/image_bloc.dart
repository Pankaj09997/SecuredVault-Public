// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:securevault/Business/Entities/ImageEntities.dart';
import 'package:securevault/Business/Usecase/ImageUseCase.dart';

part 'image_event.dart';
part 'image_state.dart';

class ImageBloc extends Bloc<ImageEvent, ImageState> {
  final UploadImageUseCase uploadImageUseCase;
  final ListImagesUseCase listImagesUseCase;
  final DownloadImageUseCase downloadImageUseCase;
  final ImageAccessLogUseCase imageAccessLogUseCase;
  final ImageViewUseCase imageViewUseCase;
  final ImageShareableLinkUseCase imageShareableLinkUseCase;
  final DeleteImageUseCase deleteImageUseCase;
  ImageBloc(
    this.uploadImageUseCase,
    this.listImagesUseCase,
    this.downloadImageUseCase,
    this.imageAccessLogUseCase,
    this.imageViewUseCase,
    this.imageShareableLinkUseCase,
    this.deleteImageUseCase,
  ) : super(ImageInitial()) {
    on<ListImages>(listImages);
    on<UploadImage>(uploadImage);
    on<ImageAccessLogs>(imageAccessLogs);
    on<DownloadImage>(downloadImage);
    on<ViewImageEvent>(viewImageEvent);
    on<ImageDeleteEvent>(deleteImage);
    on<ImageShareableLink>(imageShareableLink);
  }
  Future<void> listImages(ListImages event, Emitter<ImageState> emit) async {
    emit(ImageLoadingState());
    try {
      final response = await listImagesUseCase.listImages();
      emit(GetImageState(imageListEntities: response));
    } catch (e) {
      emit(ImageErrorState(message: "$e"));
    }
  }

  Future<void> uploadImage(UploadImage event, Emitter<ImageState> emit) async {
    emit(ImageLoadingState());
    try {
      final response = await uploadImageUseCase.imageUpload(event.file!);
            final imageList =
          await listImagesUseCase.imageRepositoryBusiness.imageList();
      emit(ImageUploadSuccess(imageUploadEntities: response));
            emit(GetImageState(imageListEntities: imageList));
    } catch (e) {
      emit(ImageErrorState(message: "$e"));
    }
  }

  Future<void> imageAccessLogs(
      ImageAccessLogs event, Emitter<ImageState> emit) async {
    emit(ImageLoadingState());
    try {
      final response = await imageAccessLogUseCase.imageAccess(event.image_id);
      emit(ImageLogAccess(imageAccessLogEntities: response));
    } catch (e) {
      emit(ImageErrorState(message: "$e"));
    }
  }

  Future<void> downloadImage(
      DownloadImage event, Emitter<ImageState> emit) async {
    emit(ImageLoadingState());
    try {
      final response = await downloadImageUseCase.imageRepositoryBusiness
          .downloadImage(event.image_id);
      final imageList =
          await listImagesUseCase.imageRepositoryBusiness.imageList();
      final image = imageList.firstWhere((f) => f.id == event.image_id);
      emit(
        ImageDownloadSuccess(
            imageDownloadEntities: response, imagename: image.original_name),
      );
      emit(GetImageState(imageListEntities: imageList));
    } catch (e) {
      emit(ImageErrorState(message: "$e"));
    }
  }

  Future<void> viewImageEvent(
      ViewImageEvent event, Emitter<ImageState> emit) async {
    // Changed return type and Emitter type
    emit(ImageDownloadLoading());
    try {
      final response = await imageViewUseCase.imageViewEntities(event.image_id);
      emit(ImageViewState(imageViewEntites: response));
            final imagesList =
          await listImagesUseCase.imageRepositoryBusiness.imageList();

 emit(GetImageState(imageListEntities: imagesList));
    } catch (e) {
      emit(ImageErrorState(message: "Unable to view the image"));
    }
  }

  Future<void> deleteImage(ImageDeleteEvent event, Emitter<ImageState> emit) async {
    emit(ImageLoadingState());
    try {
      final response = await deleteImageUseCase.imageRepositoryBusiness
          .deleteImage(event.image_id);
      final imagesList =
          await listImagesUseCase.imageRepositoryBusiness.imageList();
      emit(DeleteImageState(deleteImageEntities: response));
      emit(GetImageState(imageListEntities: imagesList));
    } catch (e) {
      emit(ImageErrorState(message: "$e"));
    }
  }

  Future<void> imageShareableLink(
      ImageShareableLink event, Emitter<ImageState> emit) async {
    emit(ImageLoadingState());
    try {
      final response = await imageShareableLinkUseCase.imageRepositoryBusiness
          .shareLink(ImageShareableLink.resource_type, event.resource_id);
      final imagesList =
          await listImagesUseCase.imageRepositoryBusiness.imageList();
      emit(ShareableLinkState(imageShareableEntities: response));
      emit(GetImageState(imageListEntities: imagesList));
    } catch (e) {
      throw Exception("Error:$e");
    }
  }
}
