import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:securevault/Data/DataSource/FilesService.dart';
import 'package:securevault/Presentation/BlocFile/FileBloc/file_bloc_bloc.dart';
import 'package:securevault/Presentation/BlocFile/ImageBloc/image_bloc.dart'
    hide ShareableLinkState;
import 'package:securevault/Presentation/Pages/FilePreviewPage/FilePreviewPage.dart';
import 'package:share_plus/share_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  final FilesService _filesService = FilesService();

  /// Name of the file the user asked to preview. Stored here so the
  /// BlocListener can pass the real file name to the preview page.
  String? _pendingPreviewName;

  @override
  bool get wantKeepAlive => true;

  Route _customRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    context.read<FileBlocBloc>().add(GetFilesEvent());
  }

  Future<void> onRefresh() async {
    context.read<FileBlocBloc>().add(GetFilesEvent());
  }

  // ── Vault password ────────────────────────────────────────────────────────

  Future<String?> _askVaultPassword() async {
    if (!mounted) return null;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _VaultPasswordDialog(),
    );
    return (result == null || result.isEmpty) ? null : result;
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  Future<void> pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );
    if (!mounted) return;

    if (result == null) {
      _showInfoSnackbar("No files selected");
      return;
    }

    final vaultPassword = await _askVaultPassword();
    if (vaultPassword == null || !mounted) return;

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

    final List<File> files =
        result.paths.whereType<String>().map((path) => File(path)).toList();

    for (final file in files) {
      final String name = file.path.split('/').last;
      final int fileSize = await file.length();
      if (!mounted) return;

      if (currentTotalSize + fileSize > maxStorage) {
        _showErrorSnackbar("Storage limit reached (50MB). Cannot upload $name");
        continue;
      }

      try {
        await _filesService.uploadFiles(file, vaultPassword: vaultPassword);
        if (!mounted) return;
        _showUploadSnackbar("Uploaded: $name");

        // Update current total size for the next file in the loop
        currentTotalSize += fileSize;

        context.read<FileBlocBloc>().add(GetFilesEvent());
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackbar("Upload Failed: ${e.toString()}");
      }
    }
  }

  // ── Share link dialog ─────────────────────────────────────────────────────

  void _showShareLinkDialog(String shareUrl) {
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Share Link',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, secondAnim, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (dialogContext, _, __) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Clipboard.setData(ClipboardData(text: shareUrl));
              _showSuccessSnackbar("Link has been copied to clipboard");
            },
            child: const Text("Copy"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Share.share(shareUrl);
            },
            child: const Text("Share"),
          ),
        ],
      ),
    );
  }

  // ── File options bottom sheet ─────────────────────────────────────────────

  void _showFileOptionsBottomSheet(
      BuildContext context, dynamic file, int fileId) {
    HapticFeedback.lightImpact();

    // Capture the bloc NOW, while `context` is alive. The sheet's own context
    // is dead by the time the password dialog finishes.
    final bloc = context.read<FileBlocBloc>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _AnimatedSheet(
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
              ),
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
                  title: const Text("File Options"),
                  subtitle: Text(
                    file.original_name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(height: 1),
                _buildBottomSheetOption(
                  icon: const Icon(Icons.download_rounded, color: Colors.black),
                  label: "Download",
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final password = await _askVaultPassword();
                    if (password != null && mounted) {
                      bloc.add(DownloadFilesEvent(
                          file_id: fileId, vaultPassword: password));
                      _showDownloadSnackbar(file.original_name);
                    }
                  },
                ),
                _buildBottomSheetOption(
                  icon: const Icon(Icons.remove_red_eye_rounded,
                      color: Colors.black),
                  label: "Preview",
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final password = await _askVaultPassword();
                    if (password != null && mounted) {
                      _pendingPreviewName = file.original_name;
                      bloc.add(ViewFileEvent(
                          file_id: fileId, vaultPassword: password));
                    }
                  },
                ),
                _buildBottomSheetOption(
                  icon: const Icon(Icons.share_rounded, color: Colors.black),
                  label: "Share",
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showShareProgressSnackbar();
                    bloc.add(ShareableLinkEvent(resource_id: fileId));
                  },
                ),
                _buildBottomSheetOption(
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                  label: "Delete",
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showDeleteConfirmationDialog(file, bloc);
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

  Widget _buildBottomSheetOption({
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

  // ── Delete confirmation dialog ────────────────────────────────────────────

  void _showDeleteConfirmationDialog(dynamic file, FileBlocBloc bloc) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Delete',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, secondAnim, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (dialogContext, _, __) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to delete ${file.original_name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              bloc.add(DeleteFileEvent(file_id: file.id));
              _showDeleteSnackbar(file.original_name);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Snackbar helpers ──────────────────────────────────────────────────────

  void _showSnack(SnackBar snackBar) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _showUploadSnackbar(String message) {
    _showSnack(_buildSnackBar(
      message: message,
      icon: Icons.cloud_upload_rounded,
      color: Colors.black,
    ));
  }

  void _showSuccessSnackbar(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showSnack(_buildSnackBar(
      message: message,
      icon: Icons.check_circle_rounded,
      color: Colors.green[800]!,
      duration: duration,
    ));
  }

  void _showDownloadSnackbar(String filename) {
    _showSnack(_buildSnackBar(
      message: "Downloading $filename...",
      icon: Icons.download_rounded,
      color: Colors.blue[800]!,
    ));
  }

  void _showDeleteSnackbar(String filename) {
    _showSnack(_buildSnackBar(
      message: "Deleting $filename...",
      icon: Icons.delete_rounded,
      color: Colors.red[800]!,
    ));
  }

  void _showErrorSnackbar(String message) {
    debugPrint(message);
    _showSnack(_buildSnackBar(
      message: message,
      icon: Icons.error_rounded,
      color: Colors.red[800]!,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showInfoSnackbar(String message) {
    _showSnack(_buildSnackBar(
      message: message,
      icon: Icons.info_rounded,
      color: Colors.grey[800]!,
    ));
  }

  void _showShareProgressSnackbar() {
    _showSnack(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text("Generating share link..."),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.blue[800],
        duration: const Duration(minutes: 1),
      ),
    );
  }

  /// Centralized snackbar builder — consistent styling across the app
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

  // ── Preview ───────────────────────────────────────────────────────────────

  void _previewFile(Uint8List fileBytes, String fileName) {
    if (!mounted) return;
    final String fileExtension = fileName.split('.').last.toLowerCase();
    Navigator.push(
      context,
      _customRoute(FilePreviewPage(
        fileBytes: fileBytes,
        fileExtension: fileExtension,
        fileName: fileName,
      )),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            "Your Files",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: BlocListener<FileBlocBloc, FileBlocState>(
            listener: (context, state) {
              debugPrint('FileBloc state: $state');
              if (state is FileBlocFailure) {
                _showErrorSnackbar(state.message);
              } else if (state is FileDownloadSuccess) {
                _showSuccessSnackbar(
                  "${state.fileName} downloaded successfully\nSaved to: ${state.downloadFileEntities.file.path}",
                  duration: const Duration(seconds: 5),
                );
              } else if (state is FileViewState) {
                // Use the real file name captured when Preview was tapped,
                // falling back to the extension from the state.
                final name = _pendingPreviewName ?? state.fileExtension;
                _pendingPreviewName = null;
                _previewFile(state.filesViewEntities.file, name);
              } else if (state is ShareableLinkState) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _showSuccessSnackbar("Share link created successfully");
                _showShareLinkDialog(state.shareableLinkEntities.shared_url);
              }
            },
            // Only rebuild the list for list-related states, so preview /
            // download / share states don't replace the list with
            // "No files found".
            child: BlocBuilder<FileBlocBloc, FileBlocState>(
              buildWhen: (prev, curr) =>
                  curr is FileBlocLoading || curr is FileList,
              builder: (context, state) {
                if (state is FileBlocLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  );
                } else if (state is FileList) {
                  if (state.fileList.isEmpty) {
                    return const _EmptyFileState();
                  }

                  return RefreshIndicator(
                    onRefresh: onRefresh,
                    color: Colors.black,
                    backgroundColor: Colors.white,
                    displacement: 20,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: state.fileList.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final file = state.fileList[index];
                        final fileId = file.id;

                        // Staggered entrance animation for list items
                        return _StaggeredListItem(
                          index: index,
                          child: _buildFileCard(context, file, fileId),
                        );
                      },
                    ),
                  );
                }
                return const Center(child: Text("No files found"));
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileCard(BuildContext context, dynamic file, int fileId) {
    final String fileExtension =
        file.original_name.split('.').last.toLowerCase();
    IconData iconData;
    Color iconColor;

    switch (fileExtension) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description;
        iconColor = Colors.blue;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        iconData = Icons.image;
        iconColor = Colors.purple;
        break;
      case 'mp4':
      case 'mov':
        iconData = Icons.movie;
        iconColor = Colors.amber;
        break;
      case 'mp3':
        iconData = Icons.audiotrack;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }

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
          _showFileOptionsBottomSheet(context, file, fileId);
        },
        onLongPress: () => _showFileOptionsBottomSheet(context, file, fileId),
        splashColor: Colors.black.withOpacity(0.04),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: iconColor),
          ),
          title: Text(
            file.original_name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            "Uploaded: ${file.upload_date.toString().split(' ')[0]}",
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: () => _showFileOptionsBottomSheet(context, file, fileId),
          ),
        ),
      ),
    );
  }
}

// ── Vault password dialog ─────────────────────────────────────────────────────
// The controller lives in this widget's State, so it is disposed only after
// the dialog route is fully removed from the tree.
class _VaultPasswordDialog extends StatefulWidget {
  const _VaultPasswordDialog();

  @override
  State<_VaultPasswordDialog> createState() => _VaultPasswordDialogState();
}

class _VaultPasswordDialogState extends State<_VaultPasswordDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vault password'),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        decoration:
            const InputDecoration(labelText: 'Enter your account password'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Continue'),
        ),
      ],
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

    // Cap the stagger so items beyond 8th appear instantly
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

// ── Empty State with pulse animation ──────────────────────────────────────────
class _EmptyFileState extends StatefulWidget {
  const _EmptyFileState();

  @override
  State<_EmptyFileState> createState() => _EmptyFileStateState();
}

class _EmptyFileStateState extends State<_EmptyFileState>
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
            child: Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          Text(
            "No files uploaded yet",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap + to upload your first file",
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
