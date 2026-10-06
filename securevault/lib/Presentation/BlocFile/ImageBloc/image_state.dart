part of 'image_bloc.dart';

@immutable
sealed class ImageState {}

final class ImageInitial extends ImageState {}

final class ImageUploadSuccess extends ImageState {
  final ImageUploadEntities? imageUploadEntities;

  ImageUploadSuccess({required this.imageUploadEntities});
}

final class ImageDownloadSuccess extends ImageState {
  final ImageDownloadEntities imageDownloadEntities;
  final String imagename;
  ImageDownloadSuccess(
      {required this.imageDownloadEntities, required this.imagename});
}

final class ImageLogAccess extends ImageState {
  final List<ImageAccessLogEntities> imageAccessLogEntities;

  ImageLogAccess({required this.imageAccessLogEntities});
}

final class GetImageState extends ImageState {
  final List<ImageListEntities> imageListEntities;

  GetImageState({required this.imageListEntities});
}

final class ImageLoadingState extends ImageState {}

final class ImageErrorState extends ImageState {
  final String message;

  ImageErrorState({required this.message});
}

final class ImageViewState extends ImageState {
  final ImageViewEntites imageViewEntites;

  ImageViewState({required this.imageViewEntites});
}

final class DeleteImageState extends ImageState {
  final DeleteImageEntities deleteImageEntities;

  DeleteImageState({required this.deleteImageEntities});
}

final class ShareableLinkState extends ImageState {
  final ImageShareableEntities imageShareableEntities;

  ShareableLinkState({required this.imageShareableEntities});
}

final class ImageDownloadLoading extends ImageState {}
