import 'dart:math' as math;
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/health_repository.dart';
import '../../config/theme.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final Map<String, dynamic> workout;
  final HealthRepository healthRepository;

  const WorkoutDetailScreen({
    super.key,
    required this.workout,
    required this.healthRepository,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  List<Map<String, dynamic>> _hrSamples = [];
  bool _isLoading = true;

  // HR Zone thresholds (age-based defaults, ~25yo)
  static const List<int> _zoneThresholds = [0, 98, 117, 137, 156, 176];
  static const List<String> _zoneNames = ['Z0', 'Z1', 'Z2', 'Z3', 'Z4', 'Z5'];
  static const List<Color> _zoneColors = [
    Color(0xFF94A3B8), // Z0 grey
    Color(0xFF3B82F6), // Z1 blue
    Color(0xFF22C55E), // Z2 green
    Color(0xFFEAB308), // Z3 yellow
    Color(0xFFEF4444), // Z4 red
    Color(0xFF8B5CF6), // Z5 purple
  ];

  @override
  void initState() {
    super.initState();
    _loadHeartRateData();
  }

  Future<void> _loadHeartRateData() async {
    final from = widget.workout['dateFrom'] as DateTime?;
    final to = widget.workout['dateTo'] as DateTime?;
    if (from != null && to != null) {
      final samples = await widget.healthRepository.getWorkoutHeartRateSamples(from, to);
      if (mounted) {
        setState(() {
          _hrSamples = samples;
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  int _getZoneIndex(double bpm) {
    for (int i = _zoneThresholds.length - 1; i >= 0; i--) {
      if (bpm >= _zoneThresholds[i]) return i;
    }
    return 0;
  }

  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString()}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.workout;
    final type = w['type'] as String? ?? 'Workout';
    final dateFrom = w['dateFrom'] as DateTime?;
    final dateTo = w['dateTo'] as DateTime?;
    final durationSec = w['durationSec'] as int? ?? 0;
    final distance = w['distance'] as double?;
    final activeEnergy = w['activeEnergy'] as int?;
    final paceString = w['paceString'] as String?;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.nc.scaffoldBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      body: CustomScrollView(
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Immersive Map Header (Purely Visual)
          SliverAppBar(
            expandedHeight: 340, // Standardized height for visual balance
            collapsedHeight: 100,
            pinned: false,
            stretch: true,
            backgroundColor: context.nc.scaffoldBg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Map Visualization
                  if (_isOutdoorType(type))
                    _buildRouteMap(distance, durationSec)
                  else
                    Container(
                      color: const Color(0xFF020617),
                      child: Center(
                        child: Icon(LucideIcons.activity, size: 80, color: Colors.white.withValues(alpha: 0.05)),
                      ),
                    ),

                  // Heavy Gradient Overlay to blend seamlessly into scaffold background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                          context.nc.scaffoldBg,
                        ],
                        stops: const [0.0, 0.5, 1.0], // Smooth fade into the background
                      ),
                    ),
                  ),

                  // Header Info (Cleanly aligned at the bottom)
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 48, // Much larger and clearer
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.0,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDate(dateFrom ?? DateTime.now()),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.6),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),


          // 2. Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 16), // Clean gap after the header

                  // Primary Metric Bento
                  _buildFloatingMetricBar(durationSec, distance, paceString, activeEnergy),
                  const SizedBox(height: 24),

                  // Intelligence Insight
                  _buildPerformanceInsight(type, durationSec, distance),
                  const SizedBox(height: 24),

                  // Bento Stats
                  _buildSummaryBento(activeEnergy),
                  const SizedBox(height: 24),

                  // Heart Rate
                  if (_hrSamples.isNotEmpty) ...[
                    _buildHeartRateSection(),
                    const SizedBox(height: 24),
                    _buildZoneTable(),
                    const SizedBox(height: 24),
                    _buildHeartRateRecovery(),
                    const SizedBox(height: 24),
                  ],

                  // Splits
                  if (distance != null && distance > 0.1)
                    _buildSplitsSection(durationSec, distance, dateFrom!, dateTo!),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }





  Widget _buildFloatingMetricBar(int durationSec, double? distance, String? pace, int? energy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _barItem("TIME", _formatDuration(durationSec), LucideIcons.timer),
          if (distance != null) ...[
            _barItem("DIST", distance.toStringAsFixed(2), LucideIcons.map),
            _barItem("PACE", pace?.split(' ')[0] ?? '—', LucideIcons.zap),
          ] else
            _barItem("ENERGY", '${energy ?? '—'}', LucideIcons.flame),
        ],
      ),
    );
  }


  Widget _barItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: context.nc.textTertiary, letterSpacing: 1.0),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontFamily: 'JetBrains Mono',
            fontWeight: FontWeight.w900,
            color: context.nc.textPrimary,
            letterSpacing: -1.0,
          ),
        ),
      ],
    );
  }

  Widget _barDivider() {
    return Container(width: 1, height: 40, color: context.nc.divider.withValues(alpha: 0.2));
  }

  String _formatDate(DateTime d) {
    final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  bool _isOutdoorType(String type) {
    final t = type.toLowerCase();
    return t.contains('walk') || t.contains('run') || t.contains('cycl') || t.contains('hik') || t.contains('out');
  }

  Widget _buildRouteMap(double? distance, int durationSec) {
    return Container(
      color: const Color(0xFF020617), // Deep Obsidian base
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dark Technical Map Texture
          Opacity(
            opacity: 0.15, // Lowered opacity for even darker look
            child: Image.network(
              'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&q=80&w=1000',
              fit: BoxFit.cover,
            ),
          ),

          // Route
          CustomPaint(
            painter: RoutePainter(
              seed: widget.workout['dateFrom']?.millisecondsSinceEpoch ?? 1,
              color: Colors.white,
              glowColor: Colors.white.withValues(alpha: 0.4),
            ),
          ),

        ],
      ),
    );
  }



  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SUMMARY ROW (Energy / HR)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildSummaryBento(int? energy) {
    final avgHR = _hrSamples.isNotEmpty
        ? (_hrSamples.fold<double>(0, (sum, s) => sum + (s['bpm'] as double)) / _hrSamples.length).round()
        : null;

    return Row(
      children: [
        Expanded(
          child: _bentoTile(
            "METABOLIC",
            "${energy ?? '—'}",
            "KCAL",
            LucideIcons.flame,
            Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _bentoTile(
            "CARDIAC",
            avgHR != null ? "$avgHR" : "—",
            "BPM",
            LucideIcons.heart,
            const Color(0xFFF472B6),
          ),
        ),
      ],
    );
  }

  Widget _bentoTile(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.nc.cardBorder.withValues(alpha: 0.1)),
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [
            color.withValues(alpha: 0.1),
            context.nc.cardSurface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: context.nc.textTertiary, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(fontSize: 24, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w800, color: context.nc.textPrimary),
                ),
                TextSpan(
                  text: " $unit",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: context.nc.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPerformanceInsight(String type, int durationSec, double? distance) {
    final avgHR = _hrSamples.isNotEmpty
        ? (_hrSamples.fold<double>(0, (sum, s) => sum + (s['bpm'] as double)) / _hrSamples.length).round()
        : 0;
    
    String insightTitle = "Base Training";
    String insightDesc = "This session contributed primarily to your aerobic base. Consistent volume at this intensity builds mitochondrial density.";
    Color insightColor = const Color(0xFF22C55E);

    if (avgHR > 150) {
      insightTitle = "Anaerobic Capacity";
      insightDesc = "High intensity detected. This session improves your lactate threshold and top-end power output. Ensure 48h recovery.";
      insightColor = Colors.white;
    } else if (durationSec > 3600) {
      insightTitle = "Endurance Engine";
      insightDesc = "Great sustained effort. Long duration sessions improve metabolic flexibility and fat oxidation efficiency.";
      insightColor = const Color(0xFF3B82F6);
    }


    return Container(
      padding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.nc.cardBorder.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: insightColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle colored glow in top corner
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: insightColor.withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "PERFORMANCE INTELLIGENCE",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: insightColor, letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              Text(
                insightTitle,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.nc.textPrimary, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                insightDesc,
                style: TextStyle(fontSize: 14, height: 1.5, color: context.nc.textSecondary.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }




  Widget _buildHeartRateSection() {
    final avgHR = _hrSamples.fold<double>(0, (sum, s) => sum + (s['bpm'] as double)) / _hrSamples.length;
    final maxHR = _hrSamples.fold<double>(0, (mx, s) => (s['bpm'] as double) > mx ? (s['bpm'] as double) : mx);
    final zoneIndex = _getZoneIndex(avgHR);

    return Container(
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.nc.cardBorder.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "HEART RATE",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: context.nc.textTertiary, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${avgHR.round()} BPM',
                      style: TextStyle(fontSize: 32, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w800, color: context.nc.textPrimary, letterSpacing: -1.0),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _zoneColors[zoneIndex].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ZONE $zoneIndex',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _zoneColors[zoneIndex]),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: _buildHRChart(maxHR),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildTimeLabels(),
                const SizedBox(height: 20),
                _buildZoneBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildHRChart(double maxHR) {
    if (_hrSamples.isEmpty) return const SizedBox.shrink();

    final firstTime = _hrSamples.first['time'] as DateTime;
    final spots = _hrSamples.map((s) {
      final t = s['time'] as DateTime;
      final x = t.difference(firstTime).inSeconds.toDouble();
      final y = s['bpm'] as double;
      return FlSpot(x, y);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 40,
        maxY: maxHR + 10,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.round()} bpm',
                  TextStyle(color: context.nc.textOnDark, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: const Color(0xFF3B82F6),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF3B82F6).withValues(alpha: 0.25),
                  const Color(0xFF3B82F6).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeLabels() {
    if (_hrSamples.isEmpty) return const SizedBox.shrink();
    final first = _hrSamples.first['time'] as DateTime;
    final last = _hrSamples.last['time'] as DateTime;
    final mid = first.add(Duration(seconds: last.difference(first).inSeconds ~/ 2));

    String fmt(DateTime d) {
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final m = d.minute.toString().padLeft(2, '0');
      final ap = d.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ap';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(fmt(first), style: TextStyle(fontSize: 10, color: context.nc.textTertiary)),
        Text(fmt(mid), style: TextStyle(fontSize: 10, color: context.nc.textTertiary)),
        Text(fmt(last), style: TextStyle(fontSize: 10, color: context.nc.textTertiary)),
      ],
    );
  }

  Widget _buildZoneBar() {
    Map<int, int> zoneDurations = {};
    for (int i = 0; i < _zoneThresholds.length; i++) {
      zoneDurations[i] = 0;
    }

    for (int i = 0; i < _hrSamples.length - 1; i++) {
      final bpm = _hrSamples[i]['bpm'] as double;
      final t1 = _hrSamples[i]['time'] as DateTime;
      final t2 = _hrSamples[i + 1]['time'] as DateTime;
      final secs = t2.difference(t1).inSeconds;
      final zone = _getZoneIndex(bpm);
      zoneDurations[zone] = (zoneDurations[zone] ?? 0) + secs;
    }

    final totalSecs = zoneDurations.values.fold<int>(0, (s, v) => s + v);
    if (totalSecs == 0) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_zoneNames.length, (i) {
            return Text(_zoneNames[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _zoneColors[i]));
          }),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: List.generate(_zoneThresholds.length, (i) {
              final fraction = (zoneDurations[i] ?? 0) / totalSecs;
              if (fraction < 0.01) return const SizedBox.shrink();
              return Expanded(
                flex: (fraction * 1000).round(),
                child: Container(height: 10, color: _zoneColors[i]),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _zoneThresholds.map((t) {
            final label = t == 176 ? '176+' : '$t';
            return Text(label, style: TextStyle(fontSize: 10, color: context.nc.textTertiary));
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildZoneTable() {
    Map<int, int> zoneDurations = {};
    for (int i = 0; i < _zoneThresholds.length; i++) {
      zoneDurations[i] = 0;
    }
    for (int i = 0; i < _hrSamples.length - 1; i++) {
      final bpm = _hrSamples[i]['bpm'] as double;
      final t1 = _hrSamples[i]['time'] as DateTime;
      final t2 = _hrSamples[i + 1]['time'] as DateTime;
      final secs = t2.difference(t1).inSeconds;
      final zone = _getZoneIndex(bpm);
      zoneDurations[zone] = (zoneDurations[zone] ?? 0) + secs;
    }
    final totalSecs = zoneDurations.values.fold<int>(0, (s, v) => s + v);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: context.nc.shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(width: 40, child: Text('Zone', style: TextStyle(fontSize: 12, color: context.nc.textTertiary, fontWeight: FontWeight.w500))),
              Expanded(child: Text('Duration', style: TextStyle(fontSize: 12, color: context.nc.textTertiary, fontWeight: FontWeight.w500))),
              const SizedBox(width: 120),
              SizedBox(width: 50, child: Text('%', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: context.nc.textTertiary, fontWeight: FontWeight.w500))),
            ],
          ),
          const Divider(height: 16),
          ...List.generate(_zoneNames.length, (i) {
            final secs = zoneDurations[i] ?? 0;
            final pct = totalSecs > 0 ? (secs / totalSecs * 100).round() : 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 40, child: Text('$i', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.nc.textPrimary))),
                  Expanded(child: Text(_formatDuration(secs), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.nc.textPrimary))),
                  SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: totalSecs > 0 ? secs / totalSecs : 0,
                        backgroundColor: context.nc.divider,
                        color: _zoneColors[i],
                        minHeight: 6,
                      ),
                    ),
                  ),
                  SizedBox(width: 50, child: Text('$pct%', textAlign: TextAlign.right, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.nc.textPrimary))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeartRateRecovery() {
    if (_hrSamples.length < 5) {
      return _buildInfoCard('Heart Rate Recovery', '—', 'bpm', 'HR difference', 'HRR data requires reaching Zone 4');
    }

    double peakHR = 0;
    int peakIdx = 0;
    for (int i = 0; i < _hrSamples.length; i++) {
      final bpm = _hrSamples[i]['bpm'] as double;
      if (bpm > peakHR) {
        peakHR = bpm;
        peakIdx = i;
      }
    }

    final peakTime = _hrSamples[peakIdx]['time'] as DateTime;
    final oneMinLater = peakTime.add(const Duration(minutes: 1));
    double? hrAfter;
    for (int i = peakIdx; i < _hrSamples.length; i++) {
      final t = _hrSamples[i]['time'] as DateTime;
      if (t.isAfter(oneMinLater) || t.isAtSameMomentAs(oneMinLater)) {
        hrAfter = _hrSamples[i]['bpm'] as double;
        break;
      }
    }

    final hrr = hrAfter != null ? (peakHR - hrAfter).round() : null;
    final reached = _getZoneIndex(peakHR) >= 4;

    return _buildInfoCard(
      'Heart Rate Recovery',
      hrr != null && reached ? '$hrr' : '—',
      'bpm',
      'HR difference',
      !reached ? 'HRR data requires reaching Zone 4' : null,
    );
  }

  Widget _buildInfoCard(String title, String value, String unit, String subtitle, String? note) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.nc.textPrimary)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.nc.cardSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: context.nc.shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(children: [
                  TextSpan(text: '$value ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: context.nc.textPrimary)),
                  TextSpan(text: unit, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: context.nc.textTertiary)),
                ]),
              ),
              Text(subtitle, style: TextStyle(fontSize: 13, color: context.nc.textTertiary)),
              if (note != null) ...[
                const SizedBox(height: 24),
                Center(child: Text(note, style: TextStyle(fontSize: 13, color: context.nc.textTertiary))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSplitsSection(int totalDurationSec, double totalDistanceKm, DateTime from, DateTime to) {
    final totalKm = totalDistanceKm.floor();
    final remainder = totalDistanceKm - totalKm;
    final splits = <Map<String, dynamic>>[];

    final pacePerKmSec = totalDistanceKm > 0 ? totalDurationSec / totalDistanceKm : 0;
    for (int i = 0; i < totalKm; i++) {
      splits.add({
        'km': 1.0,
        'label': '${i + 1}.0',
        'paceSec': pacePerKmSec.round(),
      });
    }
    if (remainder > 0.01) {
      splits.add({
        'km': remainder,
        'label': (totalKm + remainder).toStringAsFixed(1),
        'paceSec': pacePerKmSec.round(),
      });
    }

    for (int i = 0; i < splits.length; i++) {
      final splitStart = from.add(Duration(seconds: (i * pacePerKmSec).round()));
      final splitEnd = from.add(Duration(seconds: ((i + 1) * pacePerKmSec).round()));
      final samplesInSplit = _hrSamples.where((s) {
        final t = s['time'] as DateTime;
        return t.isAfter(splitStart) && t.isBefore(splitEnd);
      }).toList();
      if (samplesInSplit.isNotEmpty) {
        splits[i]['avgHR'] = (samplesInSplit.fold<double>(0, (s, e) => s + (e['bpm'] as double)) / samplesInSplit.length).round();
      }
    }

    final fastestPace = splits.isNotEmpty ? splits.map((s) => s['paceSec'] as int).reduce((a, b) => a < b ? a : b) : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Splits', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.nc.textPrimary)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.nc.cardSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: context.nc.shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(width: 40, child: Text('Km', style: TextStyle(fontSize: 12, color: context.nc.textTertiary, fontWeight: FontWeight.w500))),
                  Expanded(child: Text('Pace (/km)', style: TextStyle(fontSize: 12, color: context.nc.textTertiary, fontWeight: FontWeight.w500))),
                  SizedBox(width: 50, child: Text('HR', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: context.nc.textTertiary, fontWeight: FontWeight.w500))),
                ],
              ),
              const Divider(height: 16),
              ...splits.map((split) {
                final paceSec = split['paceSec'] as int;
                final paceMin = paceSec ~/ 60;
                final pSec = paceSec % 60;
                final paceStr = '$paceMin:${pSec.toString().padLeft(2, '0')}';
                final barFraction = fastestPace / paceSec;
                final hr = split['avgHR'] as int?;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 40, child: Text(split['label'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.nc.textPrimary))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Text(paceStr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.nc.textPrimary)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: barFraction.clamp(0.0, 1.0),
                                  backgroundColor: context.nc.divider,
                                  color: context.nc.textPrimary,
                                  minHeight: 6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 50, child: Text(hr != null ? '$hr' : '—', textAlign: TextAlign.right, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.nc.textPrimary))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ROUTE PAINTER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RoutePainter extends CustomPainter {
  final int seed;
  final Color color;
  final Color glowColor;

  RoutePainter({required this.seed, required this.color, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = glowColor
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    final random = math.Random(seed);
    
    final points = <Offset>[];
    double x = size.width * 0.2;
    double y = size.height * 0.55; 
    points.add(Offset(x, y));

    const int segments = 12;
    for (int i = 0; i < segments; i++) {
      x += (random.nextDouble() * 40) + 10;
      y -= (random.nextDouble() * 60) - 20;
      
      x = x.clamp(size.width * 0.1, size.width * 0.9);
      y = y.clamp(size.height * 0.1, size.height * 0.8); 
      
      points.add(Offset(x, y));
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final xc = (points[i].dx + points[i - 1].dx) / 2;
      final yc = (points[i].dy + points[i - 1].dy) / 2;
      path.quadraticBezierTo(points[i - 1].dx, points[i - 1].dy, xc, yc);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    final startPaint = Paint()..color = color..style = PaintingStyle.fill;
    final endPaint = Paint()..color = color..style = PaintingStyle.fill;
    
    canvas.drawCircle(points.first, 5, startPaint);
    canvas.drawCircle(points.last, 5, endPaint);
    
    canvas.drawCircle(points.first, 2, Paint()..color = Colors.white);
    canvas.drawCircle(points.last, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
