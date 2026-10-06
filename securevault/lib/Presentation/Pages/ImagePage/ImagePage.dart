import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:securevault/Business/Entities/ImageEntities.dart';
import 'package:securevault/Data/DataSource/ImageService.dart';
import 'package:securevault/Presentation/BlocFile/FileBloc/file_bloc_bloc.dart'
    hide ShareableLinkState;
import 'package:securevault/Presentation/BlocFile/ImageBloc/image_bloc.dart';
import 'package:share_plus/share_plus.dart';

class ImagePage extends StatefulWidget {
  const ImagePage({super.key});

  @override
  State<ImagePage> createState() => ImagePageState();
}

class ImagePageState extends State<ImagePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final ImageService imageService = ImageService();
  final ImagePicker imagePicker = ImagePicker();

  @override
  bool get wantKeepAlive => true;

  // init function to initialize the function that is i want to show the list of the images when user enters to this page thats why add the list show event
  @override
  void initState() {
    context.read<ImageBloc>().add(ListImages());
    super.initState();
  }

  void _showUploadSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar(
      message: message,
      icon: Icons.cloud_upload_rounded,
      color: Colors.black,
    ));
  }

  void pickFile() async {
    final XFile? image =
        await imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final fileState = context.read<FileBlocBloc>().state;
      final imageState = context.read<ImageBloc>().state;

      int currentTotalSize = 0;
      if (fileState is FileList) {
        currentTotalSize +=
            fileState.fileList.fold(0, (sum, file) => sum + file.file_size);
      }
      if (imageState is GetImageState) {
        currentTotalSize += imageState.imageListEntities
            .fold(0, (sum, image) => sum + image.image_size);
      }

      const int maxStorage = 50 * 1024 * 1024; // 50MB
      final int imageSize = await image.length();

      if (currentTotalSize + imageSize > maxStorage) {
        _showErrorSnackbar(
            "Storage limit reached (50MB). Cannot upload ${image.name}");
        return;
      }

      try {
        context.read<ImageBloc>().add(UploadImage(file: File(image.path)));
        _showUploadSnackbar("Uploaded: ${image.path.split('/').last}");
        context.read<ImageBloc>().add(ListImages());
      } catch (e) {
        _showErrorSnackbar("Upload Failed: ${e.toString()}");
      }
    } else {
      _showInfoSnackbar("No files selected");
    }
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar(
      message: message,
      icon: Icons.info_rounded,
      color: Colors.grey[800]!,
    ));
  }

  // on refreshing the page i want to show all the pages we have so on refresh show all the pages
  Future<void> onRefresh() async {
    context.read<ImageBloc>().add(ListImages());
  }

  // when user clicks on the trailing icon i want the user to be shown the bottom sheet
  void _showImageOptionsBottomSheet(
      BuildContext context, ImageListEntities image, int imageId) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AnimatedSheet(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                spreadRadius: 0,
                offset: Offset(0, -4),
              )
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.black),
                  title: const Text("Image Options"),
                  subtitle: Text(
                    image.original_name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(height: 1),
                _buildBottomSheetOption(
                  context,
                  icon: const Icon(Icons.download_rounded, color: Colors.black),
                  label: "Download",
                  onTap: () {
                    Navigator.pop(context);
                    context
                        .read<ImageBloc>()
                        .add(DownloadImage(image_id: imageId));
                    _showDownloadSnackbar(image.original_name);
                  },
                ),
                _buildBottomSheetOption(
                  context,
                  icon: const Icon(Icons.remove_red_eye_rounded,
                      color: Colors.black),
                  label: "Preview",
                  onTap: () {
                    Navigator.pop(context);
                    context
                        .read<ImageBloc>()
                        .add(ViewImageEvent(image_id: imageId));
                  },
                ),
                _buildBottomSheetOption(
                  context,
                  icon: const Icon(Icons.share_rounded, color: Colors.black),
                  label: "Share",
                  onTap: () {
                    Navigator.pop(context);
                    _showShareProgressSnackbar();
                    context
                        .read<ImageBloc>()
                        .add(ImageShareableLink(resource_id: imageId));
                  },
                ),
                _buildBottomSheetOption(
                  context,
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                  label: "Delete",
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmationDialog(context, image);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetOption(
    BuildContext context, {
    required Widget icon,
    required String label,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        splashColor:
            (isDestructive ? Colors.red : Colors.black).withOpacity(0.06),
        child: ListTile(
          leading: icon,
          title: Text(
            label,
            style: TextStyle(
              color: isDestructive ? Colors.red : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: isDestructive ? Colors.red[200] : Colors.grey[400],
            size: 20,
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, ImageListEntities image) {
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Delete',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim, secondAnim, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (context, _, __) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Confirm Delete"),
        content:
            Text("Are you sure you want to delete ${image.original_name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context
                  .read<ImageBloc>()
                  .add(ImageDeleteEvent(image_id: image.id));
              _showDeleteSnackbar(image.original_name);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showShareLinkDialog(BuildContext context, String shareUrl) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Share Link',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim, secondAnim, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (context, _, __) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Share Link Created"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Your secure share link is ready:"),
            const SizedBox(height: 16),
            SelectableText(
              shareUrl,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text("This link will expire in 10 minutes."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: shareUrl));
              _showSuccessSnackbar("Link has been copied to clipboard");
              Share.share(shareUrl);
            },
            child: const Text("Copy Link"),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(
      BuildContext context, Uint8List imageBytes, String imageName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Preview',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, anim, secondAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    imageName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Snackbar helpers ──────────────────────────────────────────────────────

  void _showShareProgressSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            const Text("Generating share link..."),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.blue[800],
        duration: const Duration(minutes: 1),
      ),
    );
  }

  void _showSuccessSnackbar(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar(
      message: message,
      icon: Icons.check_circle_rounded,
      color: Colors.green[800]!,
      duration: duration,
    ));
  }

  void _showDownloadSnackbar(String filename) {
    ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar(
      message: "Downloading $filename...",
      icon: Icons.download_rounded,
      color: Colors.blue[800]!,
    ));
  }

  void _showDeleteSnackbar(String filename) {
    ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar(
      message: "Deleting $filename...",
      icon: Icons.delete_rounded,
      color: Colors.red[800]!,
    ));
  }

  void _showErrorSnackbar(String message) {
    debugPrint(message);
    ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar(
      message: message,
      icon: Icons.error_rounded,
      color: Colors.red[800]!,
      duration: const Duration(seconds: 3),
    ));
  }

  /// Centralized snackbar builder
  SnackBar _buildSnackBar({
    required String message,
    required IconData icon,
    required Color color,
    Duration duration = const Duration(seconds: 2),
  }) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: color,
      duration: duration,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: const Text(
            "Your Images",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: BlocConsumer<ImageBloc, ImageState>(
            listener: (context, state) {
              if (state is ImageErrorState) {
                _showErrorSnackbar(state.message);
              } else if (state is ImageDownloadSuccess) {
                _showSuccessSnackbar(
                  "${state.imagename} downloaded successfully\nSaved to: ${state.imageDownloadEntities.file.path}",
                  duration: const Duration(seconds: 5),
                );
              } else if (state is ImageDeleteEvent) {
                _showSuccessSnackbar("Image deleted successfully");
                context.read<ImageBloc>().add(ListImages());
              } else if (state is ImageViewState) {
                _showImagePreview(
                    context, state.imageViewEntites.imageView, "Preview");
              } else if (state is ShareableLinkState) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _showSuccessSnackbar("Share link created successfully");
                _showShareLinkDialog(
                    context, state.imageShareableEntities.shared_url);
              }
            },
            builder: (context, state) {
              if (state is ImageLoadingState) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.black),
                );
              } else if (state is GetImageState) {
                if (state.imageListEntities.isEmpty) {
                  return _EmptyImageState();
                }

                return RefreshIndicator(
                  onRefresh: onRefresh,
                  color: Colors.black,
                  backgroundColor: Colors.white,
                  displacement: 20,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: state.imageListEntities.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final image = state.imageListEntities[index];

                      return _StaggeredListItem(
                        index: index,
                        child: _buildImageCard(context, image),
                      );
                    },
                  ),
                );
              }
              return const Center(child: Text("No images found"));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageCard(BuildContext context, ImageListEntities image) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          _showImageOptionsBottomSheet(context, image, image.id);
        },
        onLongPress: () =>
            _showImageOptionsBottomSheet(context, image, image.id),
        splashColor: Colors.black.withOpacity(0.04),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.image, color: Colors.redAccent),
          ),
          title: Text(
            image.original_name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            "Uploaded: ${image.upload_date.toString().split(' ')[0]}",
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: () =>
                _showImageOptionsBottomSheet(context, image, image.id),
          ),
        ),
      ),
    );
  }
}

// ── Staggered List Item Animation ─────────────────────────────────────────────
class _StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredListItem({required this.index, required this.child});

  @override
  State<_StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<_StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final delay = (widget.index < 8) ? widget.index * 50 : 0;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}

// ── Empty State with subtle pulse animation ───────────────────────────────────
class _EmptyImageState extends StatefulWidget {
  @override
  State<_EmptyImageState> createState() => _EmptyImageStateState();
}

class _EmptyImageStateState extends State<_EmptyImageState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              return Opacity(
                opacity: 0.4 + (_ctrl.value * 0.3),
                child: Transform.scale(
                  scale: 0.95 + (_ctrl.value * 0.05),
                  child: child,
                ),
              );
            },
            child: Icon(Icons.photo_library, size: 80, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          Text(
            "No images uploaded yet",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap + to upload your first image",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated Bottom Sheet Wrapper ─────────────────────────────────────────────
class _AnimatedSheet extends StatefulWidget {
  final Widget child;
  const _AnimatedSheet({required this.child});

  @override
  State<_AnimatedSheet> createState() => _AnimatedSheetState();
}

class _AnimatedSheetState extends State<_AnimatedSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: widget.child,
    );
  }
}
