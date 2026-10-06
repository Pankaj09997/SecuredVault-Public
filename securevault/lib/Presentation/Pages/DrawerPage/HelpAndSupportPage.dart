import 'package:flutter/material.dart';

class HelpAndSupportPage extends StatelessWidget {
  const HelpAndSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.04),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -30,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.04),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Text(
                              "24/7 Support",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Help &\nSupport",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Column(
                    children: [
                      _buildFAQSection(),
                      const SizedBox(height: 24),
                      _buildArchitectureComparisonSection(),
                      const SizedBox(height: 24),
                      _buildSecurityInfoSection(),
                      const SizedBox(height: 24),
                      _buildTroubleshootingSection(),
                      const SizedBox(height: 24),
                      _buildContactSupportSection(),
                      const SizedBox(height: 24),
                      _buildAboutSection(),
                      const SizedBox(height: 40),
                    ],
                  );
                },
                childCount: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.black87),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Frequently Asked Questions", Icons.help_outline),
        _FaqCard(
          question: "How is my data protected?",
          answer:
              "We use AES-256-GCM encryption (the same standard used by the US Government and banks). Files are encrypted at rest, and each file receives a unique encryption key.",
        ),
        _FaqCard(
          question: "Can anyone at SecureVault read my files?",
          answer:
              "SecureVault uses Server-Side Encryption (SSE). This means while your files are completely encrypted and secure from outside hackers, the server does hold the master keys to manage your data and allow you to access it seamlessly across devices.",
        ),
        _FaqCard(
          question: "What happens if I forget my password?",
          answer:
              "You can easily reset your password using the 'Forgot Password' flow. We will send a secure One-Time Password (OTP) to your registered email to verify your identity before allowing a password change.",
        ),
        _FaqCard(
          question: "Why do I need to verify my device?",
          answer:
              "We track device logins and geolocation. If an attempt is made from a new device or suspicious location, our threat detection system blocks it until you verify it via email, protecting you against account takeovers.",
        ),
        _FaqCard(
          question: "What is a Secure Room?",
          answer:
              "Secure Room is our Peer-to-Peer (P2P) file sharing feature. It allows you to transfer files directly to another device using WebRTC, meaning the file travels securely from device to device without being permanently stored on our servers.",
        ),
      ],
    );
  }

  Widget _buildArchitectureComparisonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Architecture Comparison", Icons.compare_arrows),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Server-Side (Current) vs End-to-End Encryption",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "SecureVault currently uses robust Server-Side Encryption (SSE). While an End-to-End Encryption (E2EE) / Zero-Knowledge architecture offers the highest theoretical security (trusting no one), SSE offers an excellent balance of high-end protection and user convenience.",
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                _ComparisonRow(
                  label: "Who encrypts data?",
                  current: "Server",
                  intended: "Client (Your Device)",
                ),
                _ComparisonRow(
                  label: "Key Management",
                  current: "Server manages Master Key",
                  intended: "User manages Private Key",
                ),
                _ComparisonRow(
                  label: "Password Recovery",
                  current: "Yes, via Email OTP",
                  intended: "Impossible (Data Lost)",
                ),
                _ComparisonRow(
                  label: "Security Level",
                  current: "Bank-Grade (Trust Server)",
                  intended: "Zero-Knowledge (Trust Math)",
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Security Information", Icons.security),
        _InfoCard(
          items: [
            _InfoItem(
                title: "Encryption Standard",
                desc: "AES-256-GCM (US Government Standard)"),
            _InfoItem(
                title: "Authentication",
                desc:
                    "JWT tokens with automatic session blacklisting on password change"),
            _InfoItem(
                title: "Threat Detection",
                desc:
                    "Real-time geo-fencing, impossible travel detection, and failed login logging"),
            _InfoItem(
                title: "Data Integrity",
                desc:
                    "Every file verified with a cryptographic authentication tag on access"),
          ],
        ),
      ],
    );
  }

  Widget _buildTroubleshootingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Troubleshooting", Icons.build_circle_outlined),
        _FaqCard(
          question: "I can't log in",
          answer:
              "Ensure your credentials are correct. If you failed multiple times, your account may be temporarily locked for your protection. Try resetting your password.",
        ),
        _FaqCard(
          question: "I'm not receiving OTP emails",
          answer:
              "Check your spam/junk folder. Also, note that we limit the number of OTPs you can request to prevent spam. Please wait 15 minutes and try again.",
        ),
        _FaqCard(
          question: "File upload failed",
          answer:
              "Ensure your file size is within limits (up to 1GB) and that you have a stable internet connection. If the issue persists, the server might be performing maintenance.",
        ),
        _FaqCard(
          question: "Secure Room won't connect",
          answer:
              "P2P connections require compatible networks. Ensure both devices have stable internet. Corporate firewalls or strict NAT types can sometimes block WebRTC connections.",
        ),
      ],
    );
  }

  Widget _buildContactSupportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Contact Support", Icons.mail_outline),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Need more help? Send us a message directly from the app.",
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextField(
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Describe your issue...",
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Send Message",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  "Or email us at: support@securevault.com\nTypical response time: 24 hours",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("About", Icons.info_outline),
        _ActionCard(
          title: "App Version: 1.0.0 (Build 42)",
          icon: Icons.smartphone,
          onTap: null,
        ),
        _ActionCard(
          title: "Open Source Licenses",
          icon: Icons.code,
          onTap: () {},
        ),
      ],
    );
  }
}

// ── Custom Widgets ─────────────────────────────────────────────────────────

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String current;
  final String intended;

  const _ComparisonRow({
    required this.label,
    required this.current,
    required this.intended,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _Badge(
                    text: current,
                    color: Colors.blue.shade50,
                    textColor: Colors.blue.shade700),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: _Badge(
                    text: intended,
                    color: Colors.green.shade50,
                    textColor: Colors.green.shade700),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _Badge(
      {required this.text, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqCard({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.black87,
          collapsedIconColor: Colors.grey.shade400,
          title: Text(
            question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<_InfoItem> items;

  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: items.map((item) {
          final isLast = items.last == item;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.desc,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade600,
                ),
              ),
              if (!isLast) ...[
                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade100, height: 1),
                const SizedBox(height: 12),
              ],
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _InfoItem {
  final String title;
  final String desc;
  _InfoItem({required this.title, required this.desc});
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        trailing: onTap != null
            ? Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade300)
            : null,
      ),
    );
  }
}
