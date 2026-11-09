import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/colors.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../medical_records/new_medical_record_screen.dart';
import '../medical_records/medical_records_screen.dart';

class ProviderDashboard extends StatefulWidget {
  final String providerName;
  final String? facilityId;

  const ProviderDashboard({
    super.key,
    required this.providerName,
    this.facilityId,
  });

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  int selectedIndex = 0;

  final AuthService _authService = AuthService();

  String? _facilityName;

  @override
  void initState() {
    super.initState();
    _facilityName = widget.facilityId;
  }

  Future<void> logout() async {
    await _authService.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ProviderLoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 850;

    return Scaffold(
      body: Row(
        children: [
          if (isWide)
            Container(
              width: 245,
              color: AppColors.primary,
              child: dashboardSidebar(),
            ),
          Expanded(
            child: Column(
              children: [
                // TOP HEADER
                Container(
                  height: 75,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  color: Colors.white,
                  child: Row(
                    children: [
                      if (!isWide)
                        const Icon(
                          Icons.health_and_safety,
                          color: AppColors.primary,
                          size: 30,
                        ),
                      if (!isWide) const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          _facilityName?.isNotEmpty == true
                              ? _facilityName!
                              : 'MDHP Provider Portal',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          'Dr. ${widget.providerName}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: logout,
                        icon: const Icon(Icons.logout),
                      ),

                      const SizedBox(width: 5),

                      const CircleAvatar(
                        radius: 19,
                        backgroundColor: AppColors.primary,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ],
                  ),
                ),

                // MAIN CONTENT
                Expanded(
                  child: IndexedStack(
                    index: selectedIndex,
                    children: [
                      dashboardHome(),

                      NewMedicalRecordScreen(
                        providerName: widget.providerName,
                        facilityId: widget.facilityId,
                      ),

                      // CONNECTED MEDICAL RECORDS SCREEN
                      const MedicalRecordsScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                setState(() => selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: 'Analytics',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_box_outlined),
                  label: 'New Record',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  label: 'Records',
                ),
              ],
            ),
    );
  }

  // SIDEBAR

  Widget dashboardSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 28, 16, 38),
          child: Row(
            children: [
              Icon(Icons.health_and_safety, color: Colors.white, size: 37),
              SizedBox(width: 10),
              Text(
                'MDHP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        sidebarItem(Icons.analytics_outlined, 'Analytics', 0),
        sidebarItem(Icons.add_box_outlined, 'New Medical Record', 1),
        sidebarItem(Icons.folder_outlined, 'Medical Records', 2),

        const Spacer(),

        const Padding(
          padding: EdgeInsets.all(22),
          child: Text(
            'MALAWI DIGITAL HEALTH PASSPORT\nHealthcare Provider Portal',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              height: 1.7,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget sidebarItem(IconData icon, String label, int index) {
    final selected = selectedIndex == index;

    return InkWell(
      onTap: () => setState(() => selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 21),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ANALYTICS DASHBOARD

  Widget dashboardHome() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text('Please sign in again.'));
    }

    final recordsStream = FirebaseFirestore.instance
        .collection('medical_records')
        .where('providerUID', isEqualTo: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: recordsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load analytics: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data?.docs ?? [];

        final records = documents
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        // Update header with the actual facility name.
        if (records.isNotEmpty) {
          final name = records
              .map((record) => record['facilityName']?.toString().trim() ?? '')
              .firstWhere((name) => name.isNotEmpty, orElse: () => '');

          if (name.isNotEmpty && name != _facilityName) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _facilityName != name) {
                setState(() {
                  _facilityName = name;
                });
              }
            });
          }
        }

        final today = DateUtils.dateOnly(DateTime.now());

        final todaysVisits = records.where((record) {
          final date = _recordDate(record);

          return date != null && DateUtils.isSameDay(date, today);
        }).length;

        final visitTrend = _calculateVisitTrend(records, today);
        final diseaseTrends = _calculateDiseaseTrends(records);

        return LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= 950;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Analytics Dashboard',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Welcome, ${widget.providerName}. Here is your workspace.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),

                  const SizedBox(height: 30),

                  Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      overviewCard(
                        "Today's Visits",
                        '$todaysVisits',
                        Icons.today_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // VISIT TRENDS + DISEASE TRENDS
                  if (sideBySide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: visitTrendCard(visitTrend)),
                        const SizedBox(width: 22),
                        Expanded(
                          flex: 5,
                          child: diseaseTrendCard(diseaseTrends),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        visitTrendCard(visitTrend),
                        const SizedBox(height: 22),
                        diseaseTrendCard(diseaseTrends),
                      ],
                    ),

                  const SizedBox(height: 35),

                  // QUICK ACTIONS
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() => selectedIndex = 1);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create New Medical Record'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
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

  // VISIT TREND CARD

  Widget visitTrendCard(List<int> visitTrend) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: AppColors.secondary,
                size: 25,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Visit Trends',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          const Text(
            'Patient visits over the past 7 days',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),

          const SizedBox(height: 25),

          SizedBox(
            height: 220,
            width: double.infinity,
            child: VisitHistogram(values: visitTrend),
          ),
        ],
      ),
    );
  }

  // DISEASE TREND PIE CHART CARD

  Widget diseaseTrendCard(List<MapEntry<String, int>> diseaseTrends) {
    final total = diseaseTrends.fold<int>(0, (sum, entry) => sum + entry.value);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.pie_chart_outline,
                color: AppColors.secondary,
                size: 25,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Disease Trends',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          const Text(
            'Distribution of the top 5 recorded diagnoses',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),

          const SizedBox(height: 22),

          if (diseaseTrends.isEmpty)
            const SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  'No diagnosis data available yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: DiseasePieChart(values: diseaseTrends),
                ),

                const SizedBox(height: 18),

                ...List.generate(diseaseTrends.length, (index) {
                  final entry = diseaseTrends[index];

                  final percentage = total == 0
                      ? 0
                      : (entry.value / total * 100).round();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color:
                                DiseasePieChart.palette[index %
                                    DiseasePieChart.palette.length],
                            shape: BoxShape.circle,
                          ),
                        ),

                        const SizedBox(width: 9),

                        Expanded(
                          child: Text(
                            entry.key,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        Text(
                          '${entry.value} ($percentage%)',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  // RECORD DATE

  DateTime? _recordDate(Map<String, dynamic> record) {
    final value = record['createdAt'] ?? record['visitDate'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // CALCULATE LAST 7 DAYS

  List<int> _calculateVisitTrend(
    List<Map<String, dynamic>> records,
    DateTime today,
  ) {
    final counts = List<int>.filled(7, 0);

    for (final record in records) {
      final date = _recordDate(record);

      if (date == null) continue;

      final recordDay = DateUtils.dateOnly(date);
      final difference = today.difference(recordDay).inDays;

      if (difference >= 0 && difference < 7) {
        final index = 6 - difference;
        counts[index]++;
      }
    }

    return counts;
  }

  // CALCULATE DISEASE TRENDS

  List<MapEntry<String, int>> _calculateDiseaseTrends(
    List<Map<String, dynamic>> records,
  ) {
    final Map<String, int> counts = {};
    final Map<String, String> displayNames = {};

    for (final record in records) {
      final diagnosis = record['diagnosis']?.toString().trim() ?? '';

      if (diagnosis.isEmpty) continue;

      final key = diagnosis.toLowerCase();

      counts.update(key, (value) => value + 1, ifAbsent: () => 1);

      displayNames.putIfAbsent(key, () => diagnosis);
    }

    final entries = counts.entries.map((entry) {
      return MapEntry(displayNames[entry.key] ?? entry.key, entry.value);
    }).toList();

    entries.sort((a, b) => b.value.compareTo(a.value));

    return entries.take(5).toList();
  }

  // TODAY'S VISITS OVERVIEW CARD

  Widget overviewCard(String title, String value, IconData icon) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.secondary, size: 29),

          const SizedBox(height: 18),

          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(title, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ============================================================
// VISIT HISTOGRAM
// ============================================================

class VisitHistogram extends StatelessWidget {
  final List<int> values;

  const VisitHistogram({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 220),
      painter: VisitHistogramPainter(values: values),
    );
  }
}

class VisitHistogramPainter extends CustomPainter {
  final List<int> values;

  VisitHistogramPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 35.0;
    const rightPadding = 10.0;
    const topPadding = 15.0;
    const bottomPadding = 35.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final maxValue = values.isEmpty
        ? 1
        : values.reduce((a, b) => a > b ? a : b);

    final scaleMax = maxValue == 0 ? 1 : maxValue;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    final barPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.fill;

    const textStyle = TextStyle(color: AppColors.textSecondary, fontSize: 10);

    const labelStyle = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    for (int i = 0; i <= 4; i++) {
      final y = topPadding + chartHeight * i / 4;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      final label = (scaleMax * (4 - i) / 4).round().toString();

      _drawText(canvas, label, Offset(0, y - 7), textStyle);
    }

    final barSpacing = chartWidth / 7;
    final barWidth = barSpacing * 0.48;

    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final today = DateTime.now();

    final startDay = DateUtils.dateOnly(
      today.subtract(const Duration(days: 6)),
    );

    for (int i = 0; i < values.length && i < 7; i++) {
      final value = values[i];

      final barHeight = chartHeight * value / scaleMax;

      final x = leftPadding + i * barSpacing + (barSpacing - barWidth) / 2;

      final y = topPadding + chartHeight - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight > 0 ? barHeight : 2),
        const Radius.circular(5),
      );

      canvas.drawRRect(rect, barPaint);

      _drawText(
        canvas,
        value.toString(),
        Offset(x + barWidth / 2 - 4, y - 17),
        labelStyle,
      );

      final date = startDay.add(Duration(days: i));
      final dayName = dayLabels[date.weekday - 1];

      _drawCenteredText(
        canvas,
        dayName,
        Offset(leftPadding + i * barSpacing + barSpacing / 2, size.height - 20),
        textStyle,
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset position, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );

    painter.layout();
    painter.paint(canvas, position);
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );

    painter.layout();

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant VisitHistogramPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

// ============================================================
// DISEASE PIE CHART
// ============================================================

class DiseasePieChart extends StatelessWidget {
  final List<MapEntry<String, int>> values;

  const DiseasePieChart({super.key, required this.values});

  static const List<Color> palette = [
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DiseasePieChartPainter(values: values),
      child: const SizedBox.expand(),
    );
  }
}

class DiseasePieChartPainter extends CustomPainter {
  final List<MapEntry<String, int>> values;

  DiseasePieChartPainter({required this.values});

  static const List<Color> palette = DiseasePieChart.palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final total = values.fold<int>(0, (sum, entry) => sum + entry.value);

    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);

    final radius = math.min(size.width, size.height) * 0.43;

    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i].value / total) * 2 * math.pi;

      final paint = Paint()
        ..color = palette[i % palette.length]
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      final separatorPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawArc(rect, startAngle, sweepAngle, true, separatorPaint);

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DiseasePieChartPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) {
      return true;
    }

    for (int i = 0; i < values.length; i++) {
      if (oldDelegate.values[i].key != values[i].key ||
          oldDelegate.values[i].value != values[i].value) {
        return true;
      }
    }

    return false;
  }
}
