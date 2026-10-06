import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:securevault/Data/DataSource/BaseUrl.dart';
import 'package:securevault/Presentation/BlocFile/AuthBloc/bloc/auth_bloc.dart';
import 'package:securevault/Presentation/BlocFile/FileBloc/file_bloc_bloc.dart';
import 'package:securevault/Presentation/BlocFile/ImageBloc/image_bloc.dart';
import 'package:securevault/Presentation/Widget/ColorPallete.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BaseScaffold extends StatefulWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final FloatingActionButton? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showAppBar;
  final bool extendBodyBehindAppBar;

  const BaseScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showAppBar = true,
    this.extendBodyBehindAppBar = false,
  });

  @override
  State<BaseScaffold> createState() => _BaseScaffoldState();
}

class _BaseScaffoldState extends State<BaseScaffold> {
  String? refreshToken;
  String? _cachedEmail;
  String? _cachedImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Fetch data to ensure drawer storage indicator is accurate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FileBlocBloc>().add(GetFilesEvent());
        context.read<ImageBloc>().add(ListImages());
      }
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();

    final storedRefreshToken = prefs.getString('refresh_token');
    final email = prefs.getString('email') ?? 'guest@example.com';
    final image = prefs.getString('image');

    final secureRefresh = await secureStorage.read(key: 'refresh');

    setState(() {
      refreshToken = storedRefreshToken ?? secureRefresh;
      _cachedEmail = email;
      _cachedImageUrl = image;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: widget.showAppBar ? _buildDrawer(context) : null,
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: ColorPalette.appBarColor,
              elevation: 0,
              titleSpacing: 20,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
              title: Text(
                widget.title ?? "SecureVault",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              actions: widget.actions ??
                  [
                    IconButton(
                      onPressed: () {},
                      icon: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          const Icon(Icons.notifications, color: Colors.white),
                          Positioned(
                            right: 0,
                            top: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
            )
          : null,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: Padding(
        padding: widget.showAppBar
            ? const EdgeInsets.symmetric(horizontal: 16.0)
            : EdgeInsets.zero,
        child: widget.body,
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Drawer Header
                  Container(
                    height: 220,
                    decoration: const BoxDecoration(
                      color: ColorPalette.appBarColor,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(60),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated avatar entrance
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutBack,
                          builder: (context, value, child) => Transform.scale(
                            scale: value,
                            child: Opacity(
                                opacity: value.clamp(0, 1), child: child),
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            backgroundImage: _cachedImageUrl != null
                                ? NetworkImage(
                                    "${Baseurl.baseUrl}$_cachedImageUrl")
                                : null,
                            radius: 70,
                            child: _cachedImageUrl == null
                                ? const Icon(Icons.person,
                                    size: 80, color: Colors.grey)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _cachedEmail ?? "guest@gmail.com",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main Items — with staggered entrance animation
                  _AnimatedDrawerItem(
                    delay: 0,
                    icon: Icons.folder,
                    title: "My Files",
                    onTap: () {
                      Navigator.pop(context);
                      if (ModalRoute.of(context)?.settings.name != '/home') {
                        Navigator.pushNamed(context, '/home');
                      }
                    },
                  ),
                  _AnimatedDrawerItem(
                    delay: 1,
                    icon: Icons.analytics,
                    title: "Dashboard",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/dashboard');
                    },
                  ),
                  _AnimatedDrawerItem(
                    delay: 2,
                    icon: Icons.download,
                    title: "Downloads",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/downloads');
                    },
                  ),
                  _AnimatedDrawerItem(
                    delay: 3,
                    icon: Icons.favorite,
                    title: "Favorites",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/favorites');
                    },
                  ),

                  const Divider(
                    thickness: 1,
                    height: 20,
                    indent: 20,
                    endIndent: 20,
                    color: Colors.grey,
                  ),

                  const Padding(
                    padding: EdgeInsets.fromLTRB(28, 10, 0, 5),
                    child: Text(
                      "More",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  _AnimatedDrawerItem(
                    delay: 4,
                    icon: Icons.settings,
                    title: "Settings",
                    onTap: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                  _AnimatedDrawerItem(
                    delay: 5,
                    icon: Icons.help,
                    title: "Help & Support",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/help');
                    },
                  ),
                  _AnimatedDrawerItem(
                    delay: 6,
                    icon: Icons.exit_to_app,
                    title: "Sign Out",
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.read<AuthBloc>().add(
                            LogoutEvent(refreshToken: refreshToken ?? ""),
                          );
                    },
                  ),
                ],
              ),
            ),
            _buildStorageUsage(context),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageUsage(BuildContext context) {
    return BlocBuilder<FileBlocBloc, FileBlocState>(
      builder: (context, fileState) {
        return BlocBuilder<ImageBloc, ImageState>(
          builder: (context, imageState) {
            double usedSpace = 0;
            if (fileState is FileList) {
              usedSpace += fileState.fileList
                  .fold(0, (sum, file) => sum + file.file_size)
                  .toDouble();
            }
            if (imageState is GetImageState) {
              usedSpace += imageState.imageListEntities
                  .fold(0, (sum, image) => sum + image.image_size)
                  .toDouble();
            }

            const double maxSpace = 50 * 1024 * 1024; // 50MB in bytes
            double percentage = (usedSpace / maxSpace).clamp(0.0, 1.0);

            String usedSpaceStr =
                (usedSpace / (1024 * 1024)).toStringAsFixed(2);
            String maxSpaceStr = "50";

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_outlined,
                            size: 16,
                            color: percentage > 0.9
                                ? Colors.redAccent
                                : ColorPalette.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Storage",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "${(percentage * 100).toStringAsFixed(1)}%",
                        style: TextStyle(
                          color: percentage > 0.9
                              ? Colors.redAccent
                              : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 6,
                      backgroundColor: Colors.grey[100],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage > 0.9
                            ? Colors.redAccent
                            : ColorPalette.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "$usedSpaceStr MB of $maxSpaceStr MB used",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Animated Drawer Item ──────────────────────────────────────────────────────
// Each item slides in from the left with a staggered delay for a premium feel.
class _AnimatedDrawerItem extends StatefulWidget {
  final int delay;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AnimatedDrawerItem({
    required this.delay,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_AnimatedDrawerItem> createState() => _AnimatedDrawerItemState();
}

class _AnimatedDrawerItemState extends State<_AnimatedDrawerItem>
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
      begin: const Offset(-0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger the entrance
    Future.delayed(Duration(milliseconds: 60 * widget.delay), () {
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onTap();
            },
            splashColor: Colors.black.withOpacity(0.06),
            highlightColor: Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ColorPalette.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: ColorPalette.primaryColor),
                ),
                title: Text(
                  widget.title,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
