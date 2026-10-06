import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:securevault/Presentation/Pages/Base_Scaffold/baseScaffold.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const List<_SettingsItem> _items = [
    _SettingsItem(
      icon: Icons.dashboard_outlined,
      title: "Dashboard",
      subtitle: "Security overview & analytics",
      route: "/dashboard",
    ),
    _SettingsItem(
      icon: Icons.vpn_key_rounded,
      title: "Change Password",
      subtitle: "Update your account password",
      route: "/changepassword",
    ),
    _SettingsItem(
      icon: Icons.person_outline_rounded,
      title: "Update Profile",
      subtitle: "Edit name & profile photo",
      route: "/updateprofile",
    ),
    _SettingsItem(
      icon: Icons.policy_outlined,
      title: "Privacy & Policy",
      subtitle: "How we handle your data",
      route: "/privacypolicy",
    ),
    _SettingsItem(
      icon: Icons.help_outline_rounded,
      title: "Help & Support",
      subtitle: "FAQs and contact support",
      route: "/help",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: "Settings",
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _items[index];
          // Staggered entrance animation
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + (index * 60)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pushNamed(context, item.route);
                },
                splashColor: Colors.black.withOpacity(0.04),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(item.icon,
                            color: Colors.black87, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Colors.grey[400], size: 22),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}
