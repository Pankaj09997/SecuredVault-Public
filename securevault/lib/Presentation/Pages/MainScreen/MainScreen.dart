import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:securevault/Presentation/BlocFile/AuthBloc/bloc/auth_bloc.dart';
import 'package:securevault/Presentation/BlocFile/FileBloc/file_bloc_bloc.dart';
import 'package:securevault/Presentation/BlocFile/ImageBloc/image_bloc.dart';
import 'package:securevault/Presentation/Pages/Base_Scaffold/baseScaffold.dart';
import 'package:securevault/Presentation/Pages/HomePage/HomePage.dart';
import 'package:securevault/Presentation/Pages/ImagePage/ImagePage.dart';
import 'package:securevault/Presentation/Pages/SharePage/SharePageFirst.dart';
import 'package:securevault/Presentation/Widget/ColorPallete.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const double _kMaxStorageBytes = 50 * 1024 * 1024; // 50 MB

// ---------------------------------------------------------------------------
// Nav item model
// ---------------------------------------------------------------------------

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.title,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String title;
}

const List<_NavItem> _navItems = [
  _NavItem(
    icon: Icons.folder_outlined,
    activeIcon: Icons.folder,
    label: 'Files',
    title: 'SecureVault',
  ),
  _NavItem(
    icon: Icons.image_outlined,
    activeIcon: Icons.image,
    label: 'Images',
    title: 'SecureVault',
  ),
  _NavItem(
    icon: Icons.share_outlined,
    activeIcon: Icons.share,
    label: 'Share',
    title: 'Secure Share',
  ),
];

// ---------------------------------------------------------------------------
// MainScreen
// ---------------------------------------------------------------------------

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _homeKey = GlobalKey<HomePageState>();
  final _imageKey = GlobalKey<ImagePageState>();
  final _shareKey = GlobalKey<SharePageFirstState>();

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _computeUsedSpace(FileBlocState fileState, ImageState imageState) {
    double used = 0;
    if (fileState is FileList) {
      used += fileState.fileList.fold(0.0, (sum, f) => sum + f.file_size);
    }
    if (imageState is GetImageState) {
      used += imageState.imageListEntities
          .fold(0.0, (sum, img) => sum + img.image_size);
    }
    return used;
  }

  void _onStorageFullTap(String itemLabel) {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Storage full (50 MB). Please delete some $itemLabel.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  FloatingActionButton? _buildFAB(bool isStorageFull) {
    switch (_currentIndex) {
      case 0:
        return _fabFor(
          heroTag: 'files_fab',
          isStorageFull: isStorageFull,
          normalIcon: Icons.add,
          fullIcon: Icons.cloud_off_rounded,
          onAdd: () {
            HapticFeedback.lightImpact();
            _homeKey.currentState?.pickFile();
          },
          itemLabel: 'files',
        );
      case 1:
        return _fabFor(
          heroTag: 'images_fab',
          isStorageFull: isStorageFull,
          normalIcon: Icons.add_photo_alternate,
          fullIcon: Icons.no_photography_rounded,
          onAdd: () {
            HapticFeedback.lightImpact();
            _imageKey.currentState?.pickFile();
          },
          itemLabel: 'images',
        );
      default:
        return null;
    }
  }

  FloatingActionButton _fabFor({
    required String heroTag,
    required bool isStorageFull,
    required IconData normalIcon,
    required IconData fullIcon,
    required VoidCallback onAdd,
    required String itemLabel,
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      backgroundColor:
          isStorageFull ? Colors.grey[400] : ColorPalette.primaryColor,
      elevation: isStorageFull ? 2 : 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: isStorageFull ? () => _onStorageFullTap(itemLabel) : onAdd,
      child: Icon(
        isStorageFull ? fullIcon : normalIcon,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              _navItems.length,
              (i) => _buildNavItem(index: i, item: _navItems[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required int index, required _NavItem item}) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (_currentIndex == index) return;
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorPalette.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                key: ValueKey(isSelected ? 'active_$index' : 'inactive_$index'),
                color: isSelected
                    ? ColorPalette.primaryColor
                    : ColorPalette.unSelectedColor,
                size: 24,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: ColorPalette.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is NavigateToLoginPage) {
          ScaffoldMessenger.of(context).clearSnackBars();
          Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
        }
      },
      child: BlocBuilder<FileBlocBloc, FileBlocState>(
        builder: (context, fileState) {
          return BlocBuilder<ImageBloc, ImageState>(
            builder: (context, imageState) {
              final usedSpace = _computeUsedSpace(fileState, imageState);
              final isStorageFull = usedSpace >= _kMaxStorageBytes;

              return BaseScaffold(
                title: _navItems[_currentIndex].title,
                floatingActionButton: _buildFAB(isStorageFull),
                bottomNavigationBar: _buildBottomNavigationBar(),
                body: IndexedStack(
                  index: _currentIndex,
                  children: [
                    HomePage(key: _homeKey),
                    ImagePage(key: _imageKey),
                    SharePageFirst(key: _shareKey),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
