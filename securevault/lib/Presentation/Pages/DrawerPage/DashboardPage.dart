import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:securevault/Data/DataSource/DashboardService.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  final DashboardService _dashboardService = DashboardService();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadDashboard();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _dashboardService.getDashboardData();
      setState(() {
        _data = data;
        _isLoading = false;
      });
      _animController.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Colors.black)),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _buildErrorState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCards(),
                        const SizedBox(height: 28),
                        _buildActivityChart(),
                        const SizedBox(height: 28),
                        _buildThreatLevelPieChart(),
                        const SizedBox(height: 28),
                        _buildSuspiciousTypeBarChart(),
                        const SizedBox(height: 28),
                        _buildActiveDevices(),
                        const SizedBox(height: 28),
                        _buildRecentAlerts(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
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
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Text(
                        "Last 7 Days",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Security\nDashboard",
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
    );
  }

  // ── Error State ──────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "Could not load dashboard",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? "",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary Cards ────────────────────────────────────────
  Widget _buildSummaryCards() {
    final summary = _data!['summary'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Overview",
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _StatCard(
              title: "Files",
              value: "${summary['total_files']}",
              subtitle: "${summary['total_file_accesses']} accesses",
              icon: Icons.insert_drive_file_outlined,
              color: const Color(0xFF4A90D9),
            ),
            _StatCard(
              title: "Images",
              value: "${summary['total_images']}",
              subtitle: "${summary['total_image_accesses']} accesses",
              icon: Icons.image_outlined,
              color: const Color(0xFF7B61FF),
            ),
            _StatCard(
              title: "Logins",
              value: "${summary['total_logins']}",
              subtitle: "${summary['failed_logins']} failed",
              icon: Icons.login_rounded,
              color: const Color(0xFF34C759),
            ),
            _StatCard(
              title: "Alerts",
              value: "${summary['total_suspicious']}",
              subtitle: "suspicious events",
              icon: Icons.shield_outlined,
              color: summary['total_suspicious'] > 0
                  ? const Color(0xFFFF3B30)
                  : const Color(0xFF8E8E93),
            ),
          ],
        ),
      ],
    );
  }

  // ── 7-Day Activity Line Chart ────────────────────────────
  Widget _buildActivityChart() {
    final daily = (_data!['daily'] as List).cast<Map<String, dynamic>>();

    return _ChartContainer(
      title: "7-Day Activity",
      subtitle: "File & image access over time",
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    if (value == value.toInt().toDouble()) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx >= 0 && idx < daily.length) {
                      final date = daily[idx]['date'] as String;
                      final parts = date.split('-');
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "${parts[1]}/${parts[2]}",
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              _buildLine(daily, 'file_access', const Color(0xFF4A90D9)),
              _buildLine(daily, 'image_access', const Color(0xFF7B61FF)),
              _buildLine(daily, 'suspicious', const Color(0xFFFF3B30)),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final labels = ['Files', 'Images', 'Alerts'];
                    return LineTooltipItem(
                      '${labels[spot.barIndex]}: ${spot.y.toInt()}',
                      TextStyle(
                        color: spot.bar.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildLine(
      List<Map<String, dynamic>> daily, String key, Color color) {
    return LineChartBarData(
      spots: List.generate(daily.length,
          (i) => FlSpot(i.toDouble(), (daily[i][key] as num).toDouble())),
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 3,
          color: Colors.white,
          strokeWidth: 2,
          strokeColor: color,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.08),
      ),
    );
  }

  // ── Threat Level Pie Chart ───────────────────────────────
  Widget _buildThreatLevelPieChart() {
    final threatData =
        (_data!['suspicious_by_threat'] as List).cast<Map<String, dynamic>>();

    if (threatData.isEmpty) {
      return _ChartContainer(
        title: "Threat Levels",
        subtitle: "No suspicious activity detected",
        child: SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user, size: 48, color: Colors.green[300]),
                const SizedBox(height: 12),
                Text(
                  "All Clear!",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final colors = {
      'LOW': const Color(0xFF34C759),
      'MEDIUM': const Color(0xFFFF9500),
      'HIGH': const Color(0xFFFF3B30),
      'CRITICAL': const Color(0xFF8B0000),
    };

    final total =
        threatData.fold<int>(0, (sum, item) => sum + (item['count'] as int));

    return _ChartContainer(
      title: "Threat Levels",
      subtitle: "Distribution of security alerts",
      child: SizedBox(
        height: 220,
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: threatData.map((item) {
                    final level = item['threat_level'] as String;
                    final count = item['count'] as int;
                    final pct = total > 0 ? (count / total * 100) : 0;
                    return PieChartSectionData(
                      value: count.toDouble(),
                      color: colors[level] ?? Colors.grey,
                      radius: 45,
                      title: "${pct.toInt()}%",
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: threatData.map((item) {
                final level = item['threat_level'] as String;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[level] ?? Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$level (${item['count']})",
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Suspicious Activity Type Bar Chart ───────────────────
  Widget _buildSuspiciousTypeBarChart() {
    final typeData =
        (_data!['suspicious_by_type'] as List).cast<Map<String, dynamic>>();

    if (typeData.isEmpty) {
      return const SizedBox.shrink();
    }

    final barColor = const Color(0xFF4A90D9);
    final maxCount = typeData.fold<int>(
        0, (max, item) => (item['count'] as int) > max ? item['count'] as int : max);

    return _ChartContainer(
      title: "Alert Types",
      subtitle: "Breakdown by activity category",
      child: SizedBox(
        height: (typeData.length * 48.0).clamp(100, 300),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxCount.toDouble() + 1,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    "${_formatActivityType(typeData[groupIndex]['activity_type'])}\n${rod.toY.toInt()}",
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    if (value == value.toInt().toDouble()) {
                      return Text(value.toInt().toString(),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500));
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx >= 0 && idx < typeData.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _shortenType(typeData[idx]['activity_type']),
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              ),
            ),
            barGroups: List.generate(typeData.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (typeData[i]['count'] as int).toDouble(),
                    color: barColor,
                    width: 20,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxCount.toDouble() + 1,
                      color: Colors.grey.shade100,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Active Devices ─────────────────────────────────────────
  Widget _buildActiveDevices() {
    final devices = (_data!['devices'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (devices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Active Devices",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  "Recently used devices & sessions",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                // Implement Revoke All Sessions logic
              },
              child: const Text(
                "Revoke All",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...devices.map((item) {
          final isTrusted = item['is_trusted'] as bool? ?? false;
          final os = (item['os'] as String?)?.toLowerCase() ?? '';
          
          IconData deviceIcon;
          Color iconColor;
          
          if (os.contains('ios') || os.contains('iphone') || os.contains('mac')) {
            deviceIcon = Icons.apple;
            iconColor = Colors.grey.shade800;
          } else if (os.contains('android')) {
            deviceIcon = Icons.android;
            iconColor = Colors.green;
          } else if (os.contains('win') || os.contains('windows')) {
            deviceIcon = Icons.laptop_windows;
            iconColor = Colors.blue;
          } else {
            deviceIcon = Icons.devices;
            iconColor = Colors.blueGrey;
          }

          final ts = DateTime.tryParse(item['last_used'] ?? '');
          final timeStr = ts != null
              ? "${ts.month}/${ts.day} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}"
              : "Unknown";

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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(deviceIcon, color: iconColor, size: 22),
              ),
              title: Text(
                item['device_name'] ?? 'Unknown Device',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                "${item['os']} · Last: $timeStr",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              trailing: isTrusted
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "TRUSTED",
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "UNVERIFIED",
                        style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
          );
        }),
      ],
    );
  }

  // ── Recent Alerts ────────────────────────────────────────
  Widget _buildRecentAlerts() {
    final recent =
        (_data!['recent_suspicious'] as List).cast<Map<String, dynamic>>();

    if (recent.isEmpty) {
      return const SizedBox.shrink();
    }

    final threatColors = {
      'LOW': const Color(0xFF34C759),
      'MEDIUM': const Color(0xFFFF9500),
      'HIGH': const Color(0xFFFF3B30),
      'CRITICAL': const Color(0xFF8B0000),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Recent Alerts",
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        Text(
          "Latest 5 security events",
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 16),
        ...recent.map((item) {
          final level = item['threat_level'] as String? ?? 'LOW';
          final color = threatColors[level] ?? Colors.grey;
          final ts = DateTime.tryParse(item['timestamp'] ?? '');
          final timeStr = ts != null
              ? "${ts.month}/${ts.day} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}"
              : "";

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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.warning_amber_rounded, color: color, size: 22),
              ),
              title: Text(
                _formatActivityType(item['activity_type'] ?? ''),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                "$level · ${item['action_taken'] ?? ''} · ${item['ip_address'] ?? ''}",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              trailing: Text(
                timeStr,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────
  String _formatActivityType(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  String _shortenType(String type) {
    final map = {
      'login': 'Login',
      'new_device': 'Device',
      'location_change': 'Location',
      'file_access': 'File',
      'image_access': 'Image',
      'password_change': 'Pwd',
      'unusual_time': 'Time',
      'rapid_location_change': 'Travel',
      'multiple_failed_login': 'Failed',
      'tampering_detected': 'Tamper',
    };
    return map[type] ?? type;
  }
}

// ── Reusable Widgets ──────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartContainer extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartContainer({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
