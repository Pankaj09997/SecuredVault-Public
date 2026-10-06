import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _sections = [
    _PolicySection(
      icon: Icons.person_outline_rounded,
      title: "Information We Collect",
      number: "01",
      content:
          "When you create an account, we collect your email address and profile information. When you use SecureVault to store files and images, these files are securely uploaded and stored on our backend servers to allow you to access them from anywhere.",
    ),
    _PolicySection(
      icon: Icons.swap_horiz_rounded,
      title: "Peer-to-Peer File Sharing",
      number: "02",
      content:
          "SecureVault offers a direct device-to-device file sharing feature powered by WebRTC technology.",
      bullets: [
        "Direct Transfer — Files move directly between devices, never stored mid-transfer.",
        "No Server Storage — File data never passes through our servers during a direct transfer.",
        "Encryption — Connections are natively encrypted using DTLS to prevent eavesdropping.",
        "Signaling Data — Our servers only act as a matchmaker to exchange network metadata.",
      ],
    ),
    _PolicySection(
      icon: Icons.shield_outlined,
      title: "Data Security & Storage",
      number: "03",
      content:
          "We take your security seriously. Authentication tokens are stored using hardware-backed encryption — Secure Enclave on iOS and Keystore on Android. Your vault requires authentication to access, ensuring your files remain strictly private.",
    ),
    _PolicySection(
      icon: Icons.share_outlined,
      title: "Sharing Your Information",
      number: "04",
      content:
          "We do not sell, trade, or rent your personal information or stored files to others. Your files are yours alone, unless you explicitly choose to generate a shareable link or send them directly to another peer.",
    ),
    _PolicySection(
      icon: Icons.update_rounded,
      title: "Changes to This Policy",
      number: "05",
      content:
          "We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the effective date above.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

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
                            child: Text(
                              "Last updated: $dateStr",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Privacy\n& Policy",
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
                  if (index < _sections.length) {
                    return _SectionCard(section: _sections[index]);
                  }
                  // Footer note
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.mail_outline_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Questions about this Privacy Policy? Reach out to our support team anytime.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                childCount: _sections.length + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _PolicySection {
  final String number;
  final IconData icon;
  final String title;
  final String content;
  final List<String>? bullets;

  const _PolicySection({
    required this.number,
    required this.icon,
    required this.title,
    required this.content,
    this.bullets,
  });
}

class _SectionCard extends StatelessWidget {
  final _PolicySection section;

  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            // ── Card header ─────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(section.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.number,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade400,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Divider
            Container(
              height: 1,
              color: Colors.grey.shade100,
            ),

            const SizedBox(height: 14),

            // ── Content ─────────────────────────────────────────────
            Text(
              section.content,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.grey.shade600,
              ),
            ),

            // ── Bullets ─────────────────────────────────────────────
            if (section.bullets != null) ...[
              const SizedBox(height: 12),
              ...section.bullets!.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 7),
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          b,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.55,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
