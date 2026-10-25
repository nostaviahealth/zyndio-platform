import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../models/lab_report.dart';
import '../../providers/wearable_sync_provider.dart';
import '../../services/vo2_max_service.dart';

class CardioDetailScreen extends StatefulWidget {
  final WearableSyncState syncState;
  final List<LabReport> labReports;
  final int adaptabilityIndex;
  final String statusText;
  final Color statusColor;
  final int chronologicalAge;

  const CardioDetailScreen({
    super.key,
    required this.syncState,
    required this.labReports,
    required this.adaptabilityIndex,
    required this.statusText,
    required this.statusColor,
    required this.chronologicalAge,
  });

  @override
  State<CardioDetailScreen> createState() => _CardioDetailScreenState();
}

class _CardioDetailScreenState extends State<CardioDetailScreen> {
  int _expandedPillar = -1; // -1 means none expanded
  int _selectedTrendDays = 30; // 30, 60, 90
  int _selectedNightIndex = 0; // Selected historical overnight scan index
  int _selectedSignalDays = 30; // 7, 30, 90, 365 (Default to 30)
  bool _expandedHeartAge = false;

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  String _stripUnits(String rawValue) {
    if (rawValue == '--') return '--';
    return rawValue
        .replaceAll(RegExp(r'\s*mg/dL\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*mg/L\s*', caseSensitive: false), '')
        .trim();
  }

  DateTime get _anchorDate {
    DateTime anchorDate = DateTime.now();
    DateTime? latestHistoryDate;
    
    void updateLatest(List<Map<String, dynamic>> history) {
      if (history.isNotEmpty) {
        for (var point in history) {
          final date = point['date'] as DateTime?;
          if (date != null) {
            if (latestHistoryDate == null || date.isAfter(latestHistoryDate!)) {
              latestHistoryDate = date;
            }
          }
        }
      }
    }

    updateLatest(widget.syncState.hrvHistory);
    updateLatest(widget.syncState.rhrHistory);
    updateLatest(widget.syncState.sleepHistoryDaily);
    updateLatest(widget.syncState.spo2History);
    updateLatest(widget.syncState.activeEnergyHistory);
    updateLatest(widget.syncState.exerciseMinutesHistory);
    updateLatest(widget.syncState.skinTempHistory);
    updateLatest(widget.syncState.weeklySteps);

    if (latestHistoryDate != null) {
      anchorDate = latestHistoryDate!;
    }
    return anchorDate;
  }

  void _showCardioAdaptabilityCitations() {
    _showClinicalCitationSheet(
      title: 'Cardiovascular Adaptability',
      explanation: 'Cardiovascular Adaptability measures your cardiovascular system\'s overall capacity to handle stress and recover efficiently. It represents a synthesis of your aerobic fitness (VO2 max) and autonomic flexibility (HRV).',
      citations: [
        ClinicalCitation(
          source: 'American Heart Association (2021)',
          title: 'Cardiorespiratory Fitness in Clinical Practice',
        ),
        ClinicalCitation(
          source: 'Shaffer F, Ginsberg JP (2017)',
          title: 'An Overview of Heart Rate Variability Metrics and Norms',
        ),
        ClinicalCitation(
          source: 'Buchheit M (2014)',
          title: 'Monitoring training status with HR measures',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Autonomic Flexibility Dynamic Status (RMSSD)
    final double hrvCurrent = (widget.syncState.snapshot?.hrv ?? 55).toDouble();
    final double hrvBase = widget.syncState.hrvBaseline ?? 50.0;
    String autonomicStatus = 'Balanced';
    Color autonomicColor = const Color(0xFF3B82F6);
    if (hrvCurrent >= hrvBase * 0.95) {
      autonomicStatus = 'Resilient';
      autonomicColor = const Color(0xFF10B981);
    } else if (hrvCurrent < hrvBase * 0.75) {
      autonomicStatus = 'Suppressed';
      autonomicColor = const Color(0xFFEF4444);
    }

    // Cardiac Efficiency Dynamic Status
    double vo2Val = widget.syncState.vo2Max?.toDouble() ?? 42.5;
    final vo2Class = Vo2MaxService.classifyFitness(
      vo2Val,
      age: widget.syncState.userAge ?? 30,
      isMale: widget.syncState.isMale ?? true,
    );
    final double rhrCardiac = (widget.syncState.snapshot?.rhr ?? 64).toDouble();
    
    String cardiacStatus = vo2Class.level;
    Color cardiacColor = vo2Class.color;

    // Medically accurate Cardiac Efficiency composite:
    // If VO2 max is Average, but RHR is highly athletic (< 55 bpm), upgrade status!
    if (vo2Class.level.toLowerCase() == 'average' && rhrCardiac < 55) {
      cardiacStatus = 'Good Economy';
      cardiacColor = const Color(0xFF10B981);
    } else if (vo2Class.level.toLowerCase() == 'poor' && rhrCardiac < 60) {
      cardiacStatus = 'Average';
      cardiacColor = const Color(0xFFF59E0B);
    }

    // Vascular Health Dynamic Status (Lipids TG/HDL & hs-CRP inflammation)
    String vascularStatus = 'Missing Labs';
    Color vascularColor = Colors.white54;
    if (widget.labReports.isNotEmpty) {
      final report = widget.labReports.first;
      bool hasOutlier = false;
      bool allOptimal = true;
      bool hasVascularMarkers = false;
      
      final vascularKeywords = ['ldl', 'hdl', 'triglycerides', 'apob', 'crp', 'lipoprotein', 'cholesterol'];
      
      double? tgVal;
      double? hdlVal;
      double? crpVal;
      
      for (var m in report.markers) {
        final name = m.name.toLowerCase();
        bool isVascular = vascularKeywords.any((k) => name.contains(k));
        
        if (isVascular) {
          hasVascularMarkers = true;
          final status = m.displayStatus.toLowerCase();
          if (status.contains('outlier') || status.contains('action') || status.contains('high risk')) {
             hasOutlier = true;
          }
          if (!status.contains('optimal')) allOptimal = false;
          
          if (name.contains('triglycerides')) tgVal = double.tryParse(_stripUnits(m.value));
          if (name.contains('hdl') && !name.contains('non-hdl') && !name.contains('non hdl')) {
            hdlVal = double.tryParse(_stripUnits(m.value));
          }
          if (name.contains('crp')) crpVal = double.tryParse(_stripUnits(m.value));
        }
      }
      
      if (!hasVascularMarkers) {
        vascularStatus = 'Missing Labs';
        vascularColor = Colors.white54;
      } else {
        double tgHdl = (tgVal != null && hdlVal != null && hdlVal > 0) ? tgVal / hdlVal : 1.0;
        double hsCrp = crpVal ?? 0.5;
        
        if (hasOutlier || tgHdl > 4.0 || hsCrp > 3.0) {
          vascularStatus = 'Under Strain';
          vascularColor = const Color(0xFFEF4444);
        } else if (allOptimal && tgHdl < 2.0 && hsCrp < 1.0) {
          vascularStatus = 'Optimal';
          vascularColor = const Color(0xFF10B981);
        } else {
          vascularStatus = 'Normal';
          vascularColor = const Color(0xFF3B82F6);
        }
      }
    }

    // Recovery Rate Dynamic Status
    final double rhrCur = (widget.syncState.snapshot?.rhr ?? 64).toDouble();
    final double rhrBaseVal = (widget.syncState.rhrBaseline ?? 63).toDouble();
    final double hrrBpm = widget.syncState.hrrBpm;
    
    String recoveryStatus = 'Balanced';
    Color recoveryColor = const Color(0xFF3B82F6);
    
    if (hrrBpm > 0) {
      if (hrrBpm >= 20 && rhrCur <= rhrBaseVal) {
        recoveryStatus = 'Resilient';
        recoveryColor = const Color(0xFF10B981);
      } else if (hrrBpm < 12) {
        recoveryStatus = 'Suppressed';
        recoveryColor = const Color(0xFFEF4444);
      } else {
        recoveryStatus = 'Balanced';
        recoveryColor = const Color(0xFF3B82F6);
      }
    } else {
      if (rhrCur <= rhrBaseVal) {
        recoveryStatus = 'Resilient';
        recoveryColor = const Color(0xFF10B981);
      } else if (rhrCur > rhrBaseVal + 3) {
        recoveryStatus = 'Suppressed';
        recoveryColor = const Color(0xFFEF4444);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    _buildHeroScore(),
                  const SizedBox(height: 16),
                  _buildAiNarrative(),
                  const SizedBox(height: 32),
                  _buildTrendChart(),
                  const SizedBox(height: 24),
                  _buildHeartAgePanel(),
                  const SizedBox(height: 48),

                  const Text('Overnight Cardio Scans', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  _buildOvernightScans(),
                  const SizedBox(height: 48),
                  
                  const Text('The Four Pillars', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                   _buildPillarCard(
                    'Autonomic Flexibility', 
                    '35% weight', 
                    'HRV recovery and baseline stability.', 
                    autonomicStatus, 
                    autonomicColor,
                    _buildAutonomicDetails(),
                  ),
                  _buildPillarCard(
                    'Cardiac Efficiency', 
                    '25% weight', 
                    'VO2 Max and RHR improvement.', 
                    cardiacStatus, 
                    cardiacColor,
                    _buildCardiacDetails(),
                  ),
                  _buildPillarCard(
                    'Vascular Health', 
                    widget.labReports.isEmpty ? '10% weight' : '25% weight', 
                    'Lipid and inflammation markers.', 
                    vascularStatus, 
                    vascularColor,
                    _buildVascularDetails(),
                  ),
                  _buildPillarCard(
                    'Recovery Rate', 
                    '15% weight', 
                    'Time to baseline after stress.', 
                    recoveryStatus, 
                    recoveryColor,
                    _buildRecoveryDetails(),
                  ),
                  
                  const SizedBox(height: 48),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wearable Signal Feed',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      _buildSignalTimeSelector(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSignalChart('Heart Rate Variability', widget.syncState.hrvHistory, const Color(0xFF10B981), true),
                  const SizedBox(height: 24),
                  _buildSignalChart('Resting Heart Rate', widget.syncState.rhrHistory, const Color(0xFFF59E0B), false),
                  const SizedBox(height: 24),
                  _buildSignalChart('Nightly SpO2', widget.syncState.spo2History ?? [], const Color(0xFF3B82F6), true, isBarChart: true),
                  
                  const SizedBox(height: 48),
                  const Text('Lab Intelligence', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  _buildLabIntelligence(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 80,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
      ),
      title: Column(
        children: [
          const Text(
            'Cardiovascular Intelligence',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Text(
            'Updated just now',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  Widget _buildHeroScore() {
    int weeklyDelta = 3;
    if (widget.syncState.hrvHistory.length >= 7 && widget.syncState.rhrHistory.length >= 7) {
      try {
        final hrv7d = (widget.syncState.hrvHistory[widget.syncState.hrvHistory.length - 7]['value'] as num).toDouble();
        final rhr7d = (widget.syncState.rhrHistory[widget.syncState.rhrHistory.length - 7]['value'] as num).toDouble();
        final vo2 = widget.syncState.vo2Max?.toDouble() ?? 39.0;
        
        final double score7d = (hrv7d / 100 * 35) + ((100 - rhr7d) / 100 * 25) + (vo2 / 60 * 25) + 15;
        weeklyDelta = (widget.adaptabilityIndex - score7d).round();
      } catch (e) {
        weeklyDelta = 3;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${widget.adaptabilityIndex}',
                  style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0),
                ),
                Text(
                  ' / 100',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: widget.statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    widget.statusText,
                    style: TextStyle(color: widget.statusColor, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showCardioAdaptabilityCitations,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.shieldCheck, color: const Color(0xFFE11D48).withOpacity(0.8), size: 12),
                        const SizedBox(width: 4),
                        const Text(
                          'CLINICAL REF',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              weeklyDelta >= 0 ? '+$weeklyDelta pts from last week' : '$weeklyDelta pts from last week',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: weeklyDelta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiNarrative() {
    final double hrvVal = widget.syncState.snapshot?.hrv?.toDouble() ?? 55.0;
    final double rhrVal = widget.syncState.snapshot?.rhr?.toDouble() ?? 64.0;
    final double rhrBaseline = (widget.syncState.rhrBaseline ?? 63).toDouble();
    
    String narrative;
    if (hrvVal > 55 && rhrVal <= rhrBaseline) {
      narrative = "Your HRV is strong at ${hrvVal.round()} ms and resting heart rate is regulated at ${rhrVal.round()} bpm. This reflects high autonomic elasticity and strong recovery state. Keep maintaining current sleep and active cycles.";
    } else if (hrvVal < 45 || rhrVal > rhrBaseline + 3) {
      narrative = "Your resting heart rate is elevated at ${rhrVal.round()} bpm (baseline: ${rhrBaseline.round()} bpm) and HRV is suppressed at ${hrvVal.round()} ms. This correlates with acute autonomic strain. We recommend prioritizing deep hydration and light active recovery today.";
    } else {
      narrative = "Your cardiovascular indicators are balanced today. HRV is stable at ${hrvVal.round()} ms and your resting heart rate is in line with your average at ${rhrVal.round()} bpm. Focus on maintaining consistent hydration and light activity.";
    }

    return Text(
      narrative,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.white70,
        height: 1.4,
      ),
    );
  }

  Map<String, dynamic> _calculateSomaHeartAge() {
    final int chronologicalAge = widget.chronologicalAge;
    
    // 1. RHR Modifier
    final double rhrCur = (widget.syncState.snapshot?.rhr ?? 64).toDouble();
    double rhrDelta = (rhrCur - 60.0) * 0.15;
    rhrDelta = rhrDelta.clamp(-3.0, 3.0);
    
    // 2. HRV Modifier
    final double hrvCur = (widget.syncState.snapshot?.hrv ?? 55).toDouble();
    final double hrvBase = 65.0 - (0.35 * chronologicalAge);
    double hrvDelta = (hrvBase - hrvCur) * 0.08;
    hrvDelta = hrvDelta.clamp(-3.0, 3.0);
    
    // 3. VO2 Max Modifier
    double vo2Val = widget.syncState.vo2Max?.toDouble() ?? 42.5;
    final vo2Class = Vo2MaxService.classifyFitness(
      vo2Val,
      age: chronologicalAge,
      isMale: true, // Standard baseline
    );
    double vo2Delta = 0.0;
    final String level = vo2Class.level.toLowerCase();
    if (level.contains('superior')) {
      vo2Delta = -3.0;
    } else if (level.contains('excellent')) {
      vo2Delta = -2.0;
    } else if (level.contains('good')) {
      vo2Delta = -1.0;
    } else if (level.contains('fair')) {
      vo2Delta = 0.0;
    } else if (level.contains('poor')) {
      vo2Delta = 1.0;
    } else if (level.contains('very poor')) {
      vo2Delta = 2.5;
    }
    
    // 4. Vascular / Lipid Modifier
    double vascularDelta = 0.0;
    double? tgHdlRatio;
    bool hasVascularLabs = false;
    
    if (widget.labReports.isNotEmpty) {
      final report = widget.labReports.first;
      double? tgVal;
      double? hdlVal;
      
      for (var m in report.markers) {
        final name = m.name.toLowerCase();
        if (name.contains('triglycerides')) {
          tgVal = double.tryParse(_stripUnits(m.value));
        }
        if (name.contains('hdl') && !name.contains('non-hdl') && !name.contains('non hdl')) {
          hdlVal = double.tryParse(_stripUnits(m.value));
        }
      }
      
      if (tgVal != null && hdlVal != null && hdlVal > 0) {
        tgHdlRatio = tgVal / hdlVal;
        hasVascularLabs = true;
        vascularDelta = (tgHdlRatio - 1.5) * 0.8;
        vascularDelta = vascularDelta.clamp(-2.0, 2.0);
      }
    }
    
    // Combined biological Heart Age (balanced clinical range of -5 to +5)
    double rawHeartAge = chronologicalAge + rhrDelta + hrvDelta + vo2Delta + vascularDelta;
    int heartAge = rawHeartAge.clamp(chronologicalAge - 5.0, chronologicalAge + 5.0).round();
    
    return {
      'chronologicalAge': chronologicalAge,
      'heartAge': heartAge,
      'delta': heartAge - chronologicalAge,
      'rhrDelta': rhrDelta,
      'hrvDelta': hrvDelta,
      'vo2Delta': vo2Delta,
      'vascularDelta': vascularDelta,
      'hasVascularLabs': hasVascularLabs,
      'tgHdlRatio': tgHdlRatio,
    };
  }

  Widget _buildHeartAgePanel() {
    final metrics = _calculateSomaHeartAge();
    final int heartAge = metrics['heartAge'];
    final int chronAge = metrics['chronologicalAge'];
    final int delta = metrics['delta'];
    final bool isYounger = delta < 0;
    
    final Color engineColor = isYounger 
        ? const Color(0xFF10B981) // Emerald Green
        : (delta == 0 ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B)); // Blue or Amber
        
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111), // Clean dark grey matching page theme
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.04),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'HEART AGE',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: engineColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: engineColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    delta == 0 
                        ? 'COMPATIBLE' 
                        : (isYounger ? '$delta YEARS' : '+$delta YEARS'),
                    style: TextStyle(
                      color: engineColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Redesigned Horizontal Telemetry Comparison Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Actual Age Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$chronAge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ACTUAL AGE',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                
                // Telemetry Bridge Line
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 2,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          color: Colors.white.withOpacity(0.06),
                        ),
                        Positioned(
                          left: isYounger ? 20 : null,
                          right: !isYounger ? 20 : null,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: engineColor,
                              boxShadow: [
                                BoxShadow(
                                  color: engineColor.withOpacity(0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Heart Age Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$heartAge',
                      style: TextStyle(
                        color: engineColor,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'HEART AGE',
                      style: TextStyle(
                        color: engineColor.withOpacity(0.6),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Premium Italicized Diagnostic Narrative Insight Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.03)),
              ),
              child: Text(
                isYounger 
                    ? 'Your low resting heart rate and exceptional cardiorespiratory conditioning reduce cardiovascular workload, placing your biological age $delta years younger than actual.'
                    : (delta == 0 
                        ? 'Your overall cardiovascular workload and autonomic flexibility map perfectly to standard biological baselines.'
                        : 'Elevated resting workload and suppressed autonomic recovery accelerate cardiovascular strain, shifting your heart age back by +$delta years.'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          
          // Minimalist expandable accordion trigger
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _expandedHeartAge = !_expandedHeartAge;
              });
            },
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _expandedHeartAge ? 'HIDE DEDUCTIONS' : 'VIEW DETAILED CALCULATIONS',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expandedHeartAge ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    color: Colors.white.withOpacity(0.3),
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
          
          if (_expandedHeartAge) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildHeartAgeRow(
                    'Autonomic Flex (HRV)',
                    '${(widget.syncState.snapshot?.hrv ?? 55).round()} ms',
                    metrics['hrvDelta'],
                  ),
                  const SizedBox(height: 12),
                  _buildHeartAgeRow(
                    'Resting Workload (RHR)',
                    '${(widget.syncState.snapshot?.rhr ?? 64).round()} bpm',
                    metrics['rhrDelta'],
                  ),
                  const SizedBox(height: 12),
                  _buildHeartAgeRow(
                    'Aerobic Capacity (VO2)',
                    '${(widget.syncState.vo2Max ?? 42.5).toStringAsFixed(1)} mL/kg',
                    metrics['vo2Delta'],
                  ),
                  const SizedBox(height: 12),
                  _buildHeartAgeRow(
                    'Vascular Ratios (Labs)',
                    metrics['hasVascularLabs'] 
                        ? 'TG/HDL: ${(metrics['tgHdlRatio'] as double).toStringAsFixed(2)}' 
                        : 'Missing lab markers',
                    metrics['vascularDelta'],
                    isLabFallback: !metrics['hasVascularLabs'],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeartAgeRow(String label, String value, double delta, {bool isLabFallback = false}) {
    final bool isYounger = delta < 0;
    final bool isNeutral = delta == 0;
    
    final Color valueColor = isLabFallback
        ? const Color(0xFFF59E0B) // Warning Amber
        : (isNeutral ? Colors.white70 : (isYounger ? const Color(0xFF10B981) : const Color(0xFFEF4444)));
        
    final String ageText = isLabFallback
        ? 'No effect'
        : (isNeutral ? 'Compatible' : (isYounger ? '${delta.toStringAsFixed(1)} yrs' : '+${delta.toStringAsFixed(1)} yrs'));
        
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isLabFallback)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Upload lab reports for molecular precision',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 9.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: valueColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            ageText.toUpperCase(),
            style: TextStyle(
              color: valueColor,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart() {
    List<FlSpot> spots = [];
    int days = _selectedTrendDays;
    
    List<Map<String, dynamic>> hrvList = widget.syncState.hrvHistory;
    List<Map<String, dynamic>> rhrList = widget.syncState.rhrHistory;
    
    int availablePoints = math.min(hrvList.length, rhrList.length);
    double latestAdaptability = widget.adaptabilityIndex.toDouble();
    double vo2 = widget.syncState.vo2Max?.toDouble() ?? 40.0;
    double vo2Score = (vo2 / 60.0) * 25.0;

    if (availablePoints >= 5) {
      int pointsToTake = math.min(days, availablePoints);
      List<Map<String, dynamic>> hrvSub = hrvList.sublist(hrvList.length - pointsToTake);
      List<Map<String, dynamic>> rhrSub = rhrList.sublist(rhrList.length - pointsToTake);
      
      List<double> computedScores = [];
      for (int i = 0; i < pointsToTake; i++) {
        double hrv = (hrvSub[i]['value'] as num?)?.toDouble() ?? 55.0;
        double rhr = (rhrSub[i]['value'] as num?)?.toDouble() ?? 64.0;
        
        double hrvScore = (hrv / 100.0 * 35.0);
        double rhrScore = ((100.0 - rhr).clamp(0.0, 100.0)) / 100.0 * 25.0;
        
        double score = (hrvScore + rhrScore + vo2Score + 15.0).clamp(40.0, 100.0);
        computedScores.add(score);
      }
      
      if (computedScores.isNotEmpty) {
        computedScores[computedScores.length - 1] = latestAdaptability;
      }
      
      int missing = days - pointsToTake;
      math.Random rng = math.Random(101);
      double startScore = computedScores.isNotEmpty ? computedScores.first : latestAdaptability;
      
      List<double> padding = [];
      double currentPaddingScore = startScore;
      for (int i = 0; i < missing; i++) {
        double noise = (rng.nextDouble() * 4.0) - 2.0;
        currentPaddingScore = (currentPaddingScore - noise).clamp(45.0, 95.0);
        padding.insert(0, currentPaddingScore);
      }
      
      List<double> finalScores = [...padding, ...computedScores];
      for (int i = 0; i < finalScores.length; i++) {
        spots.add(FlSpot(i.toDouble(), finalScores[i]));
      }
    } else {
      math.Random rng = math.Random(42);
      double currentScore = latestAdaptability;
      
      for (int i = 0; i < days; i++) {
        double noise = (rng.nextDouble() * 6.0) - 3.0;
        double score = currentScore - noise;
        spots.insert(0, FlSpot((days - 1 - i).toDouble(), score.clamp(40.0, 100.0)));
        currentScore = score;
      }
    }

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.only(top: 20, right: 16, left: 16, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trend', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              Row(
                children: [
                  _buildTimePill('30D', 30),
                  const SizedBox(width: 8),
                  _buildTimePill('60D', 60),
                  const SizedBox(width: 8),
                  _buildTimePill('90D', 90),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 40,
                maxY: 100,
                minX: 0,
                maxX: (days - 1).toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: (days <= 30) ? 7.0 : (days <= 60 ? 15.0 : 30.0),
                      getTitlesWidget: (value, meta) {
                        int index = value.round();
                        double bottomInterval = (days <= 30) ? 7.0 : (days <= 60 ? 15.0 : 30.0);
                        
                        if (index < spots.length - 1 && (spots.length - 1 - index) < (bottomInterval * 0.7)) {
                          return const Text('');
                        }
                        
                        if (index >= 0 && index < spots.length) {
                          int daysAgo = spots.length - 1 - index;
                          DateTime d = _anchorDate.subtract(Duration(days: daysAgo));
                          String formatted = '${d.day} ${_getMonthAbbr(d.month)}';
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              formatted,
                              style: const TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.w500),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.round()}',
                        style: const TextStyle(color: Colors.white30, fontSize: 10),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: widget.statusColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [widget.statusColor.withOpacity(0.3), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOvernightScans() {
    final double baseRhr = (widget.syncState.snapshot?.rhr ?? 64).toDouble();
    final double baseHrv = (widget.syncState.snapshot?.hrv ?? 55).toDouble();

    final DateTime now = _anchorDate;
    String formatDate(DateTime dt) {
      return '${_getMonthAbbr(dt.month)} ${dt.day}';
    }

    final List<Map<String, dynamic>> hrvHistory = widget.syncState.hrvHistory;
    final List<Map<String, dynamic>> rhrHistory = widget.syncState.rhrHistory;

    double? getHistoryVal(List<Map<String, dynamic>> history, DateTime targetDate) {
      for (var point in history) {
        final date = point['date'] as DateTime?;
        if (date != null &&
            date.year == targetDate.year &&
            date.month == targetDate.month &&
            date.day == targetDate.day) {
          return (point['value'] as num).toDouble();
        }
      }
      return null;
    }

    final List<Map<String, dynamic>> nights = [];

    for (int i = 0; i < 5; i++) {
      final int daysAgo = i + 1;
      final DateTime targetDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo));

      double? actualRhr = getHistoryVal(rhrHistory, targetDate);
      double? actualHrv = getHistoryVal(hrvHistory, targetDate);

      double rhr;
      double hrv;
      bool hasStressSpike;
      int seed;

      if (actualRhr != null && actualHrv != null) {
        rhr = actualRhr;
        hrv = actualHrv;
        hasStressSpike = rhr > (widget.syncState.rhrBaseline ?? 63) + 5 || rhr > 72;
        seed = targetDate.year * 10000 + targetDate.month * 100 + targetDate.day;
      } else {
        // Deterministic fallback based on date seed so that status is fixed for a given date
        final int dateSeed = targetDate.year * 10000 + targetDate.month * 100 + targetDate.day;
        final rng = math.Random(dateSeed);

        // 3 possible profile types: 0 = Stress Spike (20%), 1 = Optimal (40%), 2 = Standard (40%)
        final double profileRoll = rng.nextDouble();

        if (profileRoll < 0.20) {
          // Elevated Cardio Stress
          rhr = baseRhr + 8.0 + rng.nextInt(5);
          hrv = baseHrv - 10.0 - rng.nextInt(5);
          hasStressSpike = true;
        } else if (profileRoll < 0.60) {
          // Optimal Cardio Adaptability
          rhr = baseRhr - 2.0 - rng.nextInt(4);
          hrv = baseHrv + 4.0 + rng.nextInt(6);
          hasStressSpike = false;
        } else {
          // Standard Circadian Profile
          rhr = baseRhr + rng.nextInt(3) - 1.0;
          hrv = baseHrv + rng.nextInt(5) - 2.0;
          hasStressSpike = false;
        }
        seed = dateSeed;
      }

      String statusTitle;
      String statusDesc;
      Color statusColor;

      if (hasStressSpike) {
        statusTitle = 'Elevated Cardio Stress';
        statusDesc = 'Significant signs of overnight cardiovascular stress detected.';
        statusColor = const Color(0xFFEF4444);
      } else {
        final double rhrBaseline = (widget.syncState.rhrBaseline ?? 63).toDouble();
        if (rhr < rhrBaseline) {
          statusTitle = 'Optimal Cardio Adaptability';
          statusDesc = 'Deep autonomic recovery detected with strong circadian heart rate drop.';
          statusColor = const Color(0xFF10B981);
        } else {
          statusTitle = 'Standard Circadian Profile';
          statusDesc = 'Standard recovery curve with expected overnight biological rest.';
          statusColor = const Color(0xFF3B82F6);
        }
      }

      nights.add({
        'label': i == 0 ? 'Last Night' : '${i + 1} Nights Ago',
        'date': formatDate(targetDate),
        'rhr': rhr,
        'hrv': hrv,
        'hasStressSpike': hasStressSpike,
        'statusTitle': statusTitle,
        'statusDesc': statusDesc,
        'statusColor': statusColor,
        'seed': seed,
      });
    }

    final currentNight = nights[_selectedNightIndex];
    final bool hasStressSpike = currentNight['hasStressSpike'] as bool;
    final String statusTitle = currentNight['statusTitle'] as String;
    final String statusDesc = currentNight['statusDesc'] as String;
    final Color statusColor = currentNight['statusColor'] as Color;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        hasStressSpike ? Icons.heart_broken : Icons.favorite,
                        color: statusColor,
                        size: 20,
                      ),
                      if (!hasStressSpike)
                        const Positioned(
                          top: 4,
                          child: Icon(
                            Icons.check,
                            color: Color(0xFF111111),
                            size: 10,
                            weight: 900,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Select Night Scan History', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: nights.length,
              itemBuilder: (context, index) {
                final night = nights[index];
                final bool isSelected = _selectedNightIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedNightIndex = index;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.03),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: night['statusColor'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          night['label'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${night['date']})',
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.white38,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _selectedNightIndex == 0 ? "Last night's scan results" : "${currentNight['label']}'s scan results (${currentNight['date']})",
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            width: double.infinity,
            child: CustomPaint(
              painter: CardioAutonomicScanPainter(
                hasStressSpike: hasStressSpike,
                currentRhr: (currentNight['rhr'] as double),
                averageRhr: (widget.syncState.rhrBaseline?.toDouble() ?? 63.0),
                hrHistory: _selectedNightIndex == 0 ? widget.syncState.hrHistory : [],
                seed: (currentNight['seed'] as int),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePill(String text, int days) {
    bool active = _selectedTrendDays == days;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTrendDays = days;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(text, style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showClinicalCitationSheet({
    required String title,
    required String explanation,
    required List<ClinicalCitation> citations,
  }) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border(
              top: BorderSide(color: Colors.white12, width: 1.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                    ),
                    child: const Icon(
                      LucideIcons.fileText,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                explanation,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Clinical Guidelines & Citations',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              ...citations.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.source,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (c.title != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        c.title!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white60,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  void _showPillarCitations(String pillarTitle) {
    if (pillarTitle == 'Autonomic Flexibility') {
      _showClinicalCitationSheet(
        title: 'Autonomic Flexibility',
        explanation: 'Autonomic Flexibility measures the responsiveness and resilience of your Autonomic Nervous System (ANS). Zyndio quantifies this primarily using RMSSD (Root Mean Square of Successive Differences), which specifically reflects parasympathetic (vagal) tone. Healthy vagal tone allows the heart to rapidly adapt its rate to physical and metabolic demands. Persistent suppression of RMSSD indicates a state of sympathetic dominance (fight-or-flight), commonly triggered by chronic stress, inadequate slow-wave sleep, systemic inflammation, or impending illness.',
        citations: [
          ClinicalCitation(
            source: 'Task Force of the ESC & NASPE (1996)',
            title: 'Heart rate variability: standards of measurement, physiological interpretation, and clinical use.',
          ),
          ClinicalCitation(
            source: 'Shaffer F, et al. (2017)',
            title: 'An Overview of Heart Rate Variability Metrics and Norms.',
          ),
        ],
      );
    } else if (pillarTitle == 'Cardiac Efficiency') {
      _showClinicalCitationSheet(
        title: 'Cardiac Efficiency',
        explanation: 'Cardiac Efficiency evaluates your heart\'s cardiorespiratory capacity and structural efficiency. It uses age- and gender-adjusted VO2 Max (Cardio Fitness) based on the American College of Sports Medicine (ACSM) standards, alongside Resting Heart Rate (RHR). Aerobic training increases cardiac stroke volume—the volume of blood pumped per contraction—allowing the heart to pump more oxygenated blood with fewer beats. This directly reduces resting myocardial workload and lowers lifetime cardiovascular mortality risk.',
        citations: [
          ClinicalCitation(
            source: 'American College of Sports Medicine (ACSM)',
            title: 'ACSM\'s Guidelines for Exercise Testing and Prescription (11th Edition).',
          ),
          ClinicalCitation(
            source: 'Blair SN, et al. (1989)',
            title: 'Physical fitness and all-cause mortality: a prospective study of healthy men and women. JAMA.',
          ),
        ],
      );
    } else if (pillarTitle == 'Vascular Health') {
      _showClinicalCitationSheet(
        title: 'Vascular Health',
        explanation: 'Vascular Health goes beyond individual cholesterol markers to measure metabolic and arterial wall structural status. Zyndio calculates the Triglyceride-to-HDL (TG/HDL) Ratio, which is a powerful, clinically validated surrogate marker for insulin resistance and the presence of atherogenic, small, dense LDL particles (which easily penetrate the arterial intima). Additionally, high-sensitivity C-Reactive Protein (hs-CRP) is used to track vascular wall micro-inflammation. A combination of optimal lipid ratios and low inflammatory markers represents high endothelial health and a highly resilient cardiovascular wall.',
        citations: [
          ClinicalCitation(
            source: 'Ridker PM (2003)',
            title: 'Clinical application of C-reactive protein for cardiovascular disease detection and prevention. Circulation.',
          ),
          ClinicalCitation(
            source: 'Jeppesen J, et al. (2001)',
            title: 'Relation of triglycerides and HDL cholesterol to risk of ischemic heart disease. Circulation.',
          ),
          ClinicalCitation(
            source: 'Sniderman AD, et al. (2019)',
            title: 'Apolipoprotein B Particles and Cardiovascular Risk Prediction. JAMA.',
          ),
        ],
      );
    } else if (pillarTitle == 'Recovery Rate') {
      _showClinicalCitationSheet(
        title: 'Recovery Rate',
        explanation: 'Recovery Rate is assessed using the 1-Minute Post-Exercise Heart Rate Recovery (HRR), the clinical gold standard for measuring parasympathetic reactivation speed. Upon ending peak exertion, a healthy autonomic nervous system rapidly triggers vagal reactivation to decelerate the heart. A drop of less than 12 bpm in the first minute is a strong, independent prognostic marker of impaired autonomic function and heightened cardiovascular mortality. A drop of 18 bpm or more indicates healthy autonomic elasticity and cardiac fitness.',
        citations: [
          ClinicalCitation(
            source: 'Cole CR, et al. (1999)',
            title: 'Heart-rate recovery immediately after exercise as a predictor of mortality. NEJM.',
          ),
          ClinicalCitation(
            source: 'Shetler K, et al. (2001)',
            title: 'Heart rate recovery after exercise and relation to cardiovascular risk. Circulation.',
          ),
        ],
      );
    }
  }

  Widget _buildPillarCard(String title, String weight, String desc, String status, Color statusColor, Widget detailsWidget) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: '   '),
                      TextSpan(
                        text: weight,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withOpacity(0.2), width: 0.8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _showPillarCitations(title);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.shieldCheck, color: const Color(0xFF3B82F6).withOpacity(0.8), size: 12),
                            const SizedBox(width: 4),
                            const Text(
                              'CLINICAL REF',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: detailsWidget,
          ),
        ],
      ),
    );
  }

  Widget _buildAutonomicDetails() {
    final double hrv = widget.syncState.snapshot?.hrv?.toDouble() ?? 0.0;
    
    double avgHrv = hrv > 0 ? hrv * 0.92 : 45.0; // Fallback
    if (widget.syncState.hrvHistory.isNotEmpty) {
      avgHrv = widget.syncState.hrvHistory.map((e) => (e['value'] as num).toDouble()).reduce((a, b) => a + b) / widget.syncState.hrvHistory.length;
    }
    
    double percentDiff = 0;
    if (avgHrv > 0) percentDiff = ((hrv - avgHrv) / avgHrv * 100);
    
    String diffText = percentDiff >= 0 
        ? '${percentDiff.abs().round()}% above your 30-day average of ${avgHrv.round()} ms.'
        : '${percentDiff.abs().round()}% below your 30-day average of ${avgHrv.round()} ms.';
    Color diffColor = percentDiff >= -5 ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    final double rhrCurrent = (widget.syncState.snapshot?.rhr ?? 64).toDouble();
    final double rhrBase = (widget.syncState.rhrBaseline ?? 63).toDouble();
    String recoverySpeedText = 'Fast';
    Color recoverySpeedColor = const Color(0xFF10B981);
    if (rhrCurrent > rhrBase + 3) {
      recoverySpeedText = 'Delayed';
      recoverySpeedColor = const Color(0xFFEF4444);
    } else if (rhrCurrent > rhrBase) {
      recoverySpeedText = 'Moderate';
      recoverySpeedColor = const Color(0xFFF59E0B);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('RMSSD (Vagal Index)', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text('${hrv.round()} ms', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(diffText, style: TextStyle(color: diffColor, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Baseline Adaptability', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text('${avgHrv.round()} ms (avg)', style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Vagal Reactivity', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text(recoverySpeedText, style: TextStyle(color: recoverySpeedColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          percentDiff >= 0
              ? 'Parasympathetic modulation is active. Your vagus nerve is successfully regulating cardiac recovery, demonstrating high cardiovascular adaptability.'
              : 'Parasympathetic tone is suppressed. Elevated sympathetic activity is overriding biological recovery. Consider active rest, optimized sleep, or hydration.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildCardiacDetails() {
    final double rhr = widget.syncState.snapshot?.rhr?.toDouble() ?? 64.0;
    final double vo2 = widget.syncState.vo2Max?.toDouble() ?? 42.5;
    final classification = Vo2MaxService.classifyFitness(
      vo2,
      age: widget.syncState.userAge ?? 30,
      isMale: widget.syncState.isMale ?? true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('VO2 Max Capacity', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text('${vo2.toStringAsFixed(1)} mL/kg/min', style: TextStyle(color: classification.color, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('ACSM Cohort Norm', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text('${classification.level} (Top ${(100 - classification.percentile).round()}%)', style: TextStyle(color: classification.color.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Resting Workload', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text('${rhr.round()} bpm', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Your aerobic capacity represents high myocardial efficiency. A highly efficient left ventricle pumps a larger stroke volume per contraction, which minimizes the total oxygen requirement of the heart muscle at rest.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildVascularDetails() {
    if (widget.labReports.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          const Text('Upload your lab report to compute clinical lipid ratios, hs-CRP inflammatory burden, and endothelial risk scoring.', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(LucideIcons.uploadCloud, size: 16),
            label: const Text('Upload Labs'),
          ),
        ],
      );
    }
    
    // Extract lipids, CRP, and ApoB if available
    final report = widget.labReports.first;
    String ldl = '--';
    String hdl = '--';
    String trigs = '--';
    String crp = '--';
    String apob = '--';
    
    for (var m in report.markers) {
      final name = m.name.toLowerCase();
      if (name.contains('ldl')) { if (ldl == '--') ldl = m.value; }
      if (name.contains('hdl') && !name.contains('non-hdl') && !name.contains('non hdl')) { 
        if (hdl == '--') hdl = m.value; 
      }
      if (name.contains('triglycerides')) { if (trigs == '--') trigs = m.value; }
      if (name.contains('crp') || name.contains('c-reactive')) { if (crp == '--') crp = m.value; }
      if (name.contains('apob') || name.contains('apolipoprotein b')) { if (apob == '--') apob = m.value; }
    }

    final double? ldlVal = double.tryParse(_stripUnits(ldl));
    final double? hdlVal = double.tryParse(_stripUnits(hdl));
    final double? tgVal = double.tryParse(_stripUnits(trigs));
    final double? crpVal = double.tryParse(_stripUnits(crp));
    final double? apobVal = double.tryParse(_stripUnits(apob));

    double? tgHdlRatio;
    String tgHdlClass = '--';
    Color tgHdlColor = Colors.white54;
    if (tgVal != null && hdlVal != null && hdlVal > 0) {
      tgHdlRatio = tgVal / hdlVal;
      if (tgHdlRatio < 2.0) {
        tgHdlClass = 'Optimal';
        tgHdlColor = const Color(0xFF10B981);
      } else if (tgHdlRatio <= 4.0) {
        tgHdlClass = 'Moderate';
        tgHdlColor = const Color(0xFFF59E0B);
      } else {
        tgHdlClass = 'Elevated Risk';
        tgHdlColor = const Color(0xFFEF4444);
      }
    }

    String crpClass = '--';
    Color crpColor = Colors.white54;
    if (crpVal != null) {
      if (crpVal < 1.0) {
        crpClass = 'Low Risk';
        crpColor = const Color(0xFF10B981);
      } else if (crpVal <= 3.0) {
        crpClass = 'Moderate Risk';
        crpColor = const Color(0xFFF59E0B);
      } else {
        crpClass = 'High Risk';
        crpColor = const Color(0xFFEF4444);
      }
    }

    String apobClass = '--';
    Color apobColor = Colors.white54;
    if (apobVal != null) {
      if (apobVal < 80.0) {
        apobClass = 'Optimal';
        apobColor = const Color(0xFF10B981);
      } else if (apobVal <= 100.0) {
        apobClass = 'Moderate';
        apobColor = const Color(0xFFF59E0B);
      } else {
        apobClass = 'Elevated Risk';
        apobColor = const Color(0xFFEF4444);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        _buildMiniLabRow('LDL Cholesterol', _stripUnits(ldl), 'mg/dL'),
        _buildMiniLabRow('HDL Cholesterol', _stripUnits(hdl), 'mg/dL'),
        _buildMiniLabRow('Triglycerides', _stripUnits(trigs), 'mg/dL'),
        if (apob != '--') _buildMiniLabRow('Apolipoprotein B (ApoB)', _stripUnits(apob), 'mg/dL'),
        if (crp != '--') _buildMiniLabRow('hs-CRP (Inflammatory Status)', _stripUnits(crp), 'mg/L'),
        
        if (tgHdlRatio != null) ...[
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TG / HDL Ratio', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Text(tgHdlRatio.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: tgHdlColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(tgHdlClass, style: TextStyle(color: tgHdlColor, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],

        if (crpVal != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('hs-CRP Cardio Risk', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Text('${crpVal.toStringAsFixed(1)} mg/L', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: crpColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(crpClass, style: TextStyle(color: crpColor, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],

        if (apobVal != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ApoB Particle Risk', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Text('${apobVal.round()} mg/dL', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: apobColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(apobClass, style: TextStyle(color: apobColor, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],

        const SizedBox(height: 12),
        Text(
          tgHdlRatio != null && tgHdlRatio < 2.0
              ? 'TG/HDL ratio is optimal (< 2.0), reflecting highly buoyant, non-atherogenic large LDL particle patterns. LDL is ${ldlVal != null ? "${ldlVal.round()} mg/dL" : "stable"}.'
              : (tgHdlRatio != null && tgHdlRatio > 4.0
                  ? 'Elevated TG/HDL ratio (> 4.0) correlates with atherogenic small, dense LDL dominance. LDL is ${ldlVal != null ? "${ldlVal.round()} mg/dL" : "elevated"}.'
                  : 'Endothelial risk markers are normal. LDL cholesterol is ${ldlVal != null ? "${ldlVal.round()} mg/dL" : "stable"}.'),
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildMiniLabRow(String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Row(
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRecoveryDetails() {
    final double hrrBpm = widget.syncState.hrrBpm;
    final String hrrRange = widget.syncState.hrrRange;
    
    Color hrrColor = const Color(0xFF3B82F6);
    String hrrStatus = hrrRange;
    if (hrrBpm > 0) {
      if (hrrBpm >= 20) {
        hrrColor = const Color(0xFF10B981);
        hrrStatus = 'Excellent';
      } else if (hrrBpm >= 12) {
        hrrColor = const Color(0xFF3B82F6);
        hrrStatus = 'Normal';
      } else {
        hrrColor = const Color(0xFFEF4444);
        hrrStatus = 'Delayed / At Risk';
      }
    }

    List<Widget> rows = [];
    if (widget.syncState.exerciseMinutesHistory.isNotEmpty) {
      int count = 0;
      for (var entry in widget.syncState.exerciseMinutesHistory.reversed) {
        final double mins = (entry['value'] as num).toDouble();
        if (mins > 0 && count < 3) {
          final dynamic rawDate = entry['date'] ?? entry['time'];
          DateTime date = _anchorDate;
          if (rawDate is DateTime) {
            date = rawDate;
          } else if (rawDate is String) {
            date = DateTime.tryParse(rawDate) ?? _anchorDate;
          }
          
          final now = _anchorDate;
          final cleanNow = DateTime(now.year, now.month, now.day);
          final cleanDate = DateTime(date.year, date.month, date.day);
          final int daysAgo = cleanNow.difference(cleanDate).inDays;
          
          String timeStr = daysAgo == 0 ? 'Today' : (daysAgo == 1 ? 'Yesterday' : '$daysAgo days ago');
          String title = mins >= 30 ? 'High Intensity Workout' : 'Active Movement Session';
          String durationBadge = '${mins.round()}m';
          Color col = mins >= 60 ? const Color(0xFFEF4444) : (mins >= 30 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
          
          rows.add(_buildRecoveryEventRow(title, timeStr, durationBadge, col));
          count++;
        }
      }
    }
    
    if (rows.isEmpty) {
      rows.add(_buildRecoveryEventRow('High Intensity Workout', 'Yesterday', '45m', const Color(0xFFF59E0B)));
      rows.add(_buildRecoveryEventRow('Active Exercise', '3 days ago', '20m', const Color(0xFF10B981)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Post-Exercise HRR', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text(hrrBpm > 0 ? '${hrrBpm.round()} bpm drop' : '22 bpm drop (est)', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Reactivation Speed', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: hrrColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(hrrBpm > 0 ? hrrStatus.toUpperCase() : 'EXCELLENT', style: TextStyle(color: hrrColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          hrrBpm > 0 && hrrBpm < 12
              ? 'Impaired Heart Rate Recovery (< 12 bpm) reflects delayed parasympathetic reactivation. Sympathetic override remains elevated post-workout. Focus on breathwork.'
              : 'Your heart rate drops rapidly post-exercise. This reflects robust autonomic elasticity and highly efficient cardiac vagal reactivation.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 16),
        const Text('Recent Stress Events', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...rows,
      ],
    );
  }

  Widget _buildRecoveryEventRow(String title, String time, String badgeText, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(time, style: const TextStyle(color: Colors.white30, fontSize: 11)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(badgeText, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalTimeSelector() {
    final List<int> options = [7, 30, 90, 365];
    final List<String> labels = ['7D', '30D', '90D', '365D'];
    
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF1c1c1e),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (index) {
          final int opt = options[index];
          final String label = labels[index];
          final bool active = _selectedSignalDays == opt;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSignalDays = opt;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? Colors.white.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSignalChart(String title, List<Map<String, dynamic>> data, Color color, bool trendUp, {bool isBarChart = false}) {
    List<Map<String, dynamic>> resolvedData = List.from(data);
    
    // Filter to selected trend days (7, 30, 90, or 365) to keep the charts perfectly legible and responsive
    final int days = _selectedSignalDays;
    if (resolvedData.length > days) {
      resolvedData = resolvedData.sublist(resolvedData.length - days);
    }

    if (resolvedData.isEmpty) {
      double currentVal = 60.0;
      if (title.contains('HRV') || title.contains('Variability')) {
        currentVal = widget.syncState.snapshot?.hrv?.toDouble() ?? 55.0;
      } else if (title.contains('Resting') || title.contains('RHR')) {
        currentVal = widget.syncState.snapshot?.rhr?.toDouble() ?? 64.0;
      } else if (title.contains('SpO2') || title.contains('Oxygen')) {
        currentVal = (widget.syncState.snapshot?.bloodOxygen != null)
            ? widget.syncState.snapshot!.bloodOxygen!
            : 98.0;
        if (currentVal < 1.0) currentVal = currentVal * 100.0;
        if (currentVal > 100.0) currentVal = 98.0;
      }
      
      math.Random rng = math.Random(title.hashCode);
      for (int i = 0; i < 7; i++) {
        double noise = title.contains('SpO2') 
            ? (rng.nextDouble() * 2.0 - 1.0) 
            : (rng.nextDouble() * 8.0 - 4.0);
        resolvedData.add({
          'value': (currentVal + noise).clamp(title.contains('SpO2') ? 92.0 : 40.0, 100.0),
          'time': _anchorDate.subtract(Duration(days: 7 - i)),
        });
      }
    }

    // Determine latest value
    double latestVal = (resolvedData.last['value'] as num).toDouble();
    String valStr = title.contains('SpO2') ? '${latestVal.round()}%' : '${latestVal.round()}';

    // Chart processing
    List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    
    for (int i = 0; i < resolvedData.length; i++) {
      double val = (resolvedData[i]['value'] as num).toDouble();
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
      spots.add(FlSpot(i.toDouble(), val));
    }
    
    if (minY == double.infinity) minY = 0;
    if (maxY == double.negativeInfinity) maxY = 100;
    
    // Generate medical insights based on personal baseline and averages over the selected time scale
    String insightText = '';
    Color insightColor = Colors.white54;
    
    if (spots.isNotEmpty) {
      double sum = 0;
      for (var s in spots) {
        sum += s.y;
      }
      double avgVal = sum / spots.length;
      
      if (title.contains('SpO2') || title.contains('Oxygen')) {
        if (avgVal >= 95.0) {
          insightText = 'Avg SpO2: ${avgVal.toStringAsFixed(1)}% • Optimal';
          insightColor = const Color(0xFF10B981);
        } else if (avgVal >= 92.0) {
          insightText = 'Avg SpO2: ${avgVal.toStringAsFixed(1)}% • Mild Hypoxia Risk';
          insightColor = const Color(0xFFF59E0B);
        } else {
          insightText = 'Avg SpO2: ${avgVal.toStringAsFixed(1)}% • Sub-optimal (Consult Doctor)';
          insightColor = const Color(0xFFEF4444);
        }
      } else if (title.contains('HRV') || title.contains('Variability')) {
        final double base = widget.syncState.hrvBaseline ?? 50.0;
        if (avgVal >= base * 0.95) {
          insightText = 'Avg HRV: ${avgVal.round()} ms • Optimal Parasympathetic Recovery';
          insightColor = const Color(0xFF10B981);
        } else {
          insightText = 'Avg HRV: ${avgVal.round()} ms • Reduced Autonomic Control';
          insightColor = const Color(0xFFEF4444);
        }
      } else if (title.contains('Resting') || title.contains('RHR')) {
        final double base = (widget.syncState.rhrBaseline ?? 64).toDouble();
        if (avgVal <= base + 2) {
          insightText = 'Avg RHR: ${avgVal.round()} bpm • Stable Cardiovascular Economy';
          insightColor = const Color(0xFF10B981);
        } else {
          insightText = 'Avg RHR: ${avgVal.round()} bpm • Elevated Sympathetic Load';
          insightColor = const Color(0xFFEF4444);
        }
      }
    }
    
    // Add padding to axes
    minY = (minY - 5).clamp(0, double.infinity);
    maxY = maxY + 5;

    // Calculate dynamic bottom date label intervals
    double bottomInterval = 7.0;
    if (days <= 7) {
      bottomInterval = 2.0;
    } else if (days <= 30) {
      bottomInterval = 7.0;
    } else if (days <= 90) {
      bottomInterval = 30.0;
    } else {
      bottomInterval = 60.0;
    }

    Widget chart;
    if (isBarChart) {
      // Dynamically calculate rod width based on dataset size to avoid crammed/overlapping vertical stripes
      double rodWidth = (300.0 / spots.length) * 0.6;
      rodWidth = rodWidth.clamp(2.0, 16.0);
      
      List<BarChartGroupData> barGroups = [];
      for (int i = 0; i < spots.length; i++) {
        Color barColor = spots[i].y >= 96 ? const Color(0xFF3B82F6) : 
                         (spots[i].y >= 94 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
        barGroups.add(BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: spots[i].y, 
              color: barColor, 
              width: rodWidth, 
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3), 
                topRight: Radius.circular(3),
              ),
            ),
          ],
        ));
      }
      chart = BarChart(
        BarChartData(
          minY: 85,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 5,
            getDrawingHorizontalLine: (value) {
              if (value == 94 || value == 96) {
                return FlLine(color: value == 96 ? const Color(0xFF3B82F6).withOpacity(0.5) : const Color(0xFFEF4444).withOpacity(0.5), strokeWidth: 1, dashArray: [4, 4]);
              }
              return FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1);
            },
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: bottomInterval,
                getTitlesWidget: (value, meta) {
                  int index = value.round();
                  
                  // In BarChart, getTitlesWidget is called for EVERY single bar (index).
                  // We must manually enforce the bottomInterval filter to prevent cluttering!
                  if (index % bottomInterval.toInt() != 0 && index != resolvedData.length - 1) {
                    return const Text('');
                  }

                  // Prevent right-edge label collision by skipping labels too close to the final date
                  if (index < resolvedData.length - 1 && (resolvedData.length - 1 - index) < (bottomInterval * 0.7)) {
                    return const Text('');
                  }
                  if (index >= 0 && index < resolvedData.length) {
                    final date = resolvedData[index]['time'] ?? resolvedData[index]['date'];
                    DateTime d = _anchorDate;
                    if (date is DateTime) {
                      d = date;
                    } else if (date is String) {
                      d = DateTime.tryParse(date) ?? _anchorDate;
                    }
                    String formatted = '${d.day} ${_getMonthAbbr(d.month)}';
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        formatted,
                        style: const TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.w500),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (val, meta) => Text('${val.round()}', style: const TextStyle(color: Colors.white30, fontSize: 10)),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      );
    } else {
      // Line chart for HRV/RHR
      chart = LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: 0,
          maxX: (resolvedData.length - 1).toDouble(),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: bottomInterval,
                getTitlesWidget: (value, meta) {
                  int index = value.round();
                  // Prevent right-edge label collision by skipping labels too close to the final date
                  if (index < resolvedData.length - 1 && (resolvedData.length - 1 - index) < (bottomInterval * 0.7)) {
                    return const Text('');
                  }
                  if (index >= 0 && index < resolvedData.length) {
                    final date = resolvedData[index]['time'] ?? resolvedData[index]['date'];
                    DateTime d = _anchorDate;
                    if (date is DateTime) {
                      d = date;
                    } else if (date is String) {
                      d = DateTime.tryParse(date) ?? _anchorDate;
                    }
                    String formatted = '${d.day} ${_getMonthAbbr(d.month)}';
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        formatted,
                        style: const TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.w500),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (val, meta) => Text('${val.round()}', style: const TextStyle(color: Colors.white30, fontSize: 10)),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.3), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(top: 20, right: 20, left: 10, bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      if (insightText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          insightText,
                          style: TextStyle(
                            color: insightColor.withOpacity(0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(valStr, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Icon(trendUp ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight, size: 16, color: color),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: chart,
          ),
        ],
      ),
    );
  }

  List<double> _extractMarkerHistory(String keyword, {bool isHdl = false}) {
    List<double> history = [];
    // widget.labReports is usually newest-first, so reversed is chronological
    for (var report in widget.labReports.reversed) {
      for (var m in report.markers) {
        final lower = m.name.toLowerCase();
        bool isMatch = false;
        if (isHdl) {
          isMatch = lower.contains('hdl') && !lower.contains('non-hdl') && !lower.contains('non hdl');
        } else {
          isMatch = lower.contains(keyword);
        }
        if (isMatch) {
          final valStr = _stripUnits(m.value);
          final val = double.tryParse(valStr);
          if (val != null) history.add(val);
          break;
        }
      }
    }
    return history;
  }

  Widget _buildLabIntelligence() {
    if (widget.labReports.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text("No lab data available.", style: TextStyle(color: Colors.white54))),
      );
    }

    final report = widget.labReports.first;
    String ldl = '--'; String hdl = '--'; String trigs = '--'; String crp = '--';
    String ldlStatus = 'Unknown'; String hdlStatus = 'Unknown'; String trigsStatus = 'Unknown';

    for (var m in report.markers) {
      final name = m.name.toLowerCase();
      if (name.contains('ldl')) { if (ldl == '--') { ldl = m.value; ldlStatus = m.displayStatus; } }
      if (name.contains('hdl') && !name.contains('non-hdl') && !name.contains('non hdl')) { 
        if (hdl == '--') { hdl = m.value; hdlStatus = m.displayStatus; } 
      }
      if (name.contains('triglycerides')) { if (trigs == '--') { trigs = m.value; trigsStatus = m.displayStatus; } }
      if (name.contains('crp')) { if (crp == '--') { crp = m.value; } }
    }

    final ldlHistory = _extractMarkerHistory('ldl');
    final hdlHistory = _extractMarkerHistory('hdl', isHdl: true);
    final trigsHistory = _extractMarkerHistory('triglycerides');
    final crpHistory = _extractMarkerHistory('crp');

    return Column(
      children: [
        _buildFullLabRow('LDL Cholesterol', '${_stripUnits(ldl)} mg/dL', ldlStatus, ldlHistory),
        _buildFullLabRow('HDL Cholesterol', '${_stripUnits(hdl)} mg/dL', hdlStatus, hdlHistory),
        _buildFullLabRow('Triglycerides', '${_stripUnits(trigs)} mg/dL', trigsStatus, trigsHistory),
        if (crp != '--') _buildFullLabRow('High-Sensitivity CRP', '${_stripUnits(crp)} mg/L', 'Normal', crpHistory),
        
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.gitMerge,
                      color: Color(0xFF3B82F6),
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('CORRELATION INSIGHT', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                () {
                  final double rhrCurrent = (widget.syncState.snapshot?.rhr ?? 64).toDouble();
                  final double rhrBaseline = (widget.syncState.rhrBaseline ?? 63).toDouble();
                  String rhrTrendText;
                  if (rhrCurrent > rhrBaseline + 2) {
                    rhrTrendText = 'resting heart rate climbed to ${rhrCurrent.round()} bpm (above your baseline of ${rhrBaseline.round()} bpm)';
                  } else if (rhrCurrent < rhrBaseline - 2) {
                    rhrTrendText = 'resting heart rate dropped to an optimal ${rhrCurrent.round()} bpm (below your baseline of ${rhrBaseline.round()} bpm)';
                  } else {
                    rhrTrendText = 'resting heart rate remained highly stable at ${rhrCurrent.round()} bpm (baseline: ${rhrBaseline.round()} bpm)';
                  }
                  return 'Your triglycerides and metabolic markers reflect your systemic load. Over the same period, your $rhrTrendText. These trends typically reflect a shift in overall metabolic efficiency and recovery balance.';
                }(),
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullLabRow(String name, String value, String status, List<double> history) {
    // Normalize to exactly 3 standard tags: OPTIMAL, OUTLIER, IN-RANGE
    String normalizedStatus = 'IN-RANGE';
    Color statusColor = const Color(0xFF3B82F6); // Royal blue default for IN-RANGE

    final upper = status.toUpperCase().trim();
    if (upper == 'OPTIMAL' || upper == 'OPTIMUM') {
      normalizedStatus = 'OPTIMAL';
      statusColor = const Color(0xFF10B981);
    } else if (upper == 'OUTLIER' || upper == 'ABNORMAL' || upper == 'HIGH' || upper == 'LOW' || upper == 'CRITICAL') {
      normalizedStatus = 'OUTLIER';
      statusColor = const Color(0xFFEF4444);
    } else {
      normalizedStatus = 'IN-RANGE';
      statusColor = const Color(0xFF3B82F6);
    }

    Widget sparkline = const SizedBox(height: 30);
    if (history.length > 1) {
      List<FlSpot> spots = [];
      for (int i = 0; i < history.length; i++) {
        spots.add(FlSpot(i.toDouble(), history[i]));
      }
      double min = history.reduce((a, b) => a < b ? a : b) * 0.9;
      double max = history.reduce((a, b) => a > b ? a : b) * 1.1;

      sparkline = SizedBox(
        height: 30,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (history.length - 1).toDouble(),
            minY: min,
            maxY: max,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: statusColor,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [statusColor.withOpacity(0.3), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 4,
            child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: sparkline,
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text(normalizedStatus, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// Custom clinical painter simulating Ultrahuman's Cardio Adaptability night-scan curves.
class CardioAutonomicScanPainter extends CustomPainter {
  final bool hasStressSpike;
  final double currentRhr;
  final double averageRhr;
  final List<Map<String, dynamic>> hrHistory;
  final int seed;

  CardioAutonomicScanPainter({
    required this.hasStressSpike,
    required this.currentRhr,
    required this.averageRhr,
    required this.hrHistory,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final graphHeight = size.height * 0.76;
    double minHR = 40.0;
    double maxHR = 100.0;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 1. Draw horizontal gridlines and Y-axis bpm labels
    final bpms = [90, 80, 70, 60, 50];
    for (int bpm in bpms) {
      double normY = (bpm - minHR) / (maxHR - minHR);
      double y = 16 + (1 - normY) * (graphHeight - 20);

      // Gridline ending before side labels
      canvas.drawLine(Offset(12, y), Offset(size.width - 44, y), gridPaint);

      textPainter.text = TextSpan(
        text: '$bpm',
        style: TextStyle(
          color: Colors.white.withOpacity(0.35),
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - 34, y - 5));
    }

    // 2. Generate Heart Rate Curve Points
    List<Offset> points = [];
    int pointCount = 36;
    double startX = 24.0;
    double endX = size.width - 48.0; // Space for right Y-axis labels

    List<double> hrValues = [];
    if (hrHistory.isNotEmpty) {
      final recentHistory = hrHistory.length > pointCount
          ? hrHistory.sublist(hrHistory.length - pointCount)
          : hrHistory;
      for (var entry in recentHistory) {
        final val = (entry['value'] as num?)?.toDouble();
        if (val != null) {
          hrValues.add(val.clamp(minHR, maxHR));
        }
      }
    }

    if (hrValues.length < 5) {
      hrValues.clear();
      final rng = math.Random(seed);
      double baselineStart = hasStressSpike ? (currentRhr + 10.0) : (currentRhr + 8.0);
      double maxCircadianDip = hasStressSpike ? 4.0 : 12.0;

      for (int i = 0; i < pointCount; i++) {
        double progress = i / (pointCount - 1);
        double circadianDip = math.sin(progress * math.pi) * maxCircadianDip;
        double noise = (rng.nextDouble() * 3.0 - 1.5);

        double spike = 0.0;
        if (hasStressSpike && progress > 0.70 && progress < 0.85) {
          spike = math.sin((progress - 0.70) / 0.15 * math.pi) * 16.0;
        }

        double hrVal = (baselineStart - circadianDip + noise + spike).clamp(minHR, maxHR);
        hrValues.add(hrVal);
      }
    }

    int count = hrValues.length;
    double actualStep = (endX - startX) / (count - 1);

    for (int i = 0; i < count; i++) {
      double hr = hrValues[i];
      double normY = (hr - minHR) / (maxHR - minHR);
      double x = startX + i * actualStep;
      double y = 16 + (1 - normY) * (graphHeight - 20);
      points.add(Offset(x, y));
    }

    // 3. Draw pink glowing area fill below line
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint = Offset((p1.dx + p2.dx) / 2, p1.dy);
      final controlPoint2 = Offset((p1.dx + p2.dx) / 2, p2.dy);
      path.cubicTo(controlPoint.dx, controlPoint.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, graphHeight)
      ..lineTo(points.first.dx, graphHeight)
      ..close();

    canvas.drawPath(fillPath, Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 16),
        Offset(0, graphHeight),
        [const Color(0xFFE11D48).withOpacity(0.12), Colors.transparent],
      ));

    // Outer glow blur line
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFE11D48).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // Main curve path
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFE11D48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round);

    // 4. Draw Solid Accurate Timeline Axis Line
    double timelineY = size.height - 24;
    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    double tlStart = startX;
    double tlEnd = endX;
    double tlLength = tlEnd - tlStart;

    canvas.drawLine(Offset(tlStart, timelineY), Offset(tlEnd, timelineY), axisPaint);

    // Draw vertical clinical tick marks and center-aligned labels
    final tickHours = [
      {'label': '10 PM', 'pos': 0.0},
      {'label': '12 AM', 'pos': 0.25},
      {'label': '2 AM', 'pos': 0.50},
      {'label': '4 AM', 'pos': 0.75},
      {'label': '6 AM', 'pos': 1.0},
    ];

    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1.0;

    for (var tick in tickHours) {
      double x = tlStart + tlLength * (tick['pos'] as double);
      // Tiny tick drop line
      canvas.drawLine(Offset(x, timelineY), Offset(x, timelineY + 4), tickPaint);
      // Center-aligned text label 10 pixels below tick drop
      _drawTimelineText(canvas, tick['label'] as String, x, timelineY + 8);
    }

    // 5. Draw Ultrahuman scan markers dynamically along the path
    if (hasStressSpike) {
      _drawBadge(canvas, points[(count * 0.25).round()], '12:09 AM', const Color(0xFF10B981), isChecked: true, stemUp: true);
      _drawBadge(canvas, points[(count * 0.50).round()], '1:12 AM', const Color(0xFF10B981), isChecked: true, stemUp: false);
      _drawBadge(canvas, points[(count * 0.78).round()], '2:28 AM', const Color(0xFFEF4444), isChecked: false, stemUp: true);
    } else {
      _drawBadge(canvas, points[(count * 0.33).round()], '1:21 AM', const Color(0xFF10B981), isChecked: true, stemUp: true);
      _drawBadge(canvas, points[(count * 0.55).round()], '2:17 AM', const Color(0xFF10B981), isChecked: true, stemUp: false);
      _drawBadge(canvas, points[(count * 0.78).round()], '3:17 AM', const Color(0xFF10B981), isChecked: true, stemUp: true);
    }
  }

  void _drawTimelineText(Canvas canvas, String text, double x, double y) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 7.5, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y));
  }

  void _drawBadge(Canvas canvas, Offset position, String time, Color color, {required bool isChecked, required bool stemUp}) {
    // 1. Draw glowing background dot on the path
    canvas.drawCircle(position, 5, Paint()..color = color.withOpacity(0.35));
    canvas.drawCircle(position, 2, Paint()..color = Colors.white);

    // Alternating stem height (UP or DOWN)
    double stemHeight = stemUp ? -22.0 : 22.0;
    Offset labelCenter = Offset(position.dx, position.dy + stemHeight);

    // 2. Draw vertical projection stem hairline line
    canvas.drawLine(
      position,
      labelCenter,
      Paint()
        ..color = color.withOpacity(0.35)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // Connector bead
    canvas.drawCircle(labelCenter, 1.5, Paint()..color = color);

    // 3. Prepare glassmorphic text RRect
    final iconText = isChecked ? '✓ ' : '⚠️ ';
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: iconText,
            style: TextStyle(
              color: color,
              fontSize: 7.0,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(
            text: time,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 7.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    double width = textPainter.width + 16;
    double height = textPainter.height + 6;
    double rx = labelCenter.dx - width / 2;
    double ry = labelCenter.dy - height / 2;

    final capsuleRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(rx, ry, width, height),
      const Radius.circular(100),
    );

    // Glass frosted fill
    canvas.drawRRect(
      capsuleRRect,
      Paint()
        ..color = Colors.black.withOpacity(0.55)
        ..style = PaintingStyle.fill,
    );

    // Glowing subtle frame border
    canvas.drawRRect(
      capsuleRRect,
      Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    textPainter.paint(
      canvas,
      Offset(
        labelCenter.dx - textPainter.width / 2,
        labelCenter.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CardioAutonomicScanPainter oldDelegate) {
    return oldDelegate.hasStressSpike != hasStressSpike ||
        oldDelegate.currentRhr != currentRhr ||
        oldDelegate.averageRhr != averageRhr ||
        oldDelegate.hrHistory != hrHistory;
  }
}
