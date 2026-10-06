import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:securevault/Presentation/Pages/HomePage/HomePage.dart';
import 'package:securevault/Presentation/Pages/ImagePage/ImagePage.dart';

class NavigationBarItems extends StatefulWidget {
  const NavigationBarItems({super.key});

  @override
  State<NavigationBarItems> createState() => _NavigationBarItemsState();
}

class _NavigationBarItemsState extends State<NavigationBarItems>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomePage(),
    ImagePage(),
    // Placeholder for Share screen
    Scaffold(backgroundColor: Colors.white),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(icon: FontAwesomeIcons.file, label: 'Files'),
    _NavItem(icon: FontAwesomeIcons.image, label: 'Images'),
    _NavItem(icon: FontAwesomeIcons.shareNodes, label: 'Share'),
  ];

  void _onTappedIndex(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true, // lets body go behind the floating nav
      body: _screens[_currentIndex],
      bottomNavigationBar: _PremiumNavBar(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: _onTappedIndex,
      ),
    );
  }
}

// ── Data class ──────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ── Premium floating nav bar ────────────────────────────────────────────────

class _PremiumNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _PremiumNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 28,
        right: 28,
        bottom: bottomPadding + 20,
      ),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (i) {
            return _NavTile(
              item: items[i],
              isSelected: i == currentIndex,
              onTap: () => onTap(i),
            );
          }),
        ),
      ),
    );
  }
}

// ── Individual tile ──────────────────────────────────────────────────────────

class _NavTile extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTapDown(_) => _ctrl.forward();
  void _handleTapUp(_) {
    _ctrl.reverse();
    widget.onTap();
  }

  void _handleTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          padding: widget.isSelected
              ? const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                widget.item.icon,
                size: 16,
                color: widget.isSelected ? Colors.black : Colors.white54,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                child: widget.isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          widget.item.label,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
