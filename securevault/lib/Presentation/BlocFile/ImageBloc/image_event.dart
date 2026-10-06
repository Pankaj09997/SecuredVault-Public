part of 'image_bloc.dart';

@immutable
sealed class ImageEvent {}

final class ListImages extends ImageEvent {}

final class UploadImage extends ImageEvent {
  final File? file;

  UploadImage({required this.file});
}

final class ImageAccessLogs extends ImageEvent {
  final int image_id;

  ImageAccessLogs({required this.image_id});
}

final class DownloadImage extends ImageEvent {
  final int image_id;

  DownloadImage({required this.image_id});
}

final class ViewImageEvent extends ImageEvent {
  final int image_id;

  ViewImageEvent({required this.image_id});
}

final class ImageDeleteEvent extends ImageEvent {
  final int image_id;

  ImageDeleteEvent({required this.image_id});
}


final class ImageShareableLink extends ImageEvent {
  static const String resource_type='Image';
  final int resource_id;

  ImageShareableLink({required this.resource_id});


}
