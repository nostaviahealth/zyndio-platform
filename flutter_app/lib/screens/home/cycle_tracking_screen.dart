import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/cycle_provider.dart';
import '../../models/menstrual_log.dart';
import '../../widgets/intelligence_glow_wrapper.dart';
import '../../providers/patient_provider.dart';
import 'package:intl/intl.dart';

class CycleTrackingScreen extends ConsumerWidget {
  const CycleTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycleState = ref.watch(cycleIntelligenceProvider);

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: context.nc.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Cycle Intelligence',
          style: TextStyle(
            color: context.nc.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(LucideIcons.settings2, color: context.nc.textPrimary),
            onPressed: () => _showCycleSettings(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: cycleState.isLoading && cycleState.logs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    // Phase Orb
                    Center(
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: _getPhaseColors(cycleState.currentPhase),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _getPhaseColors(cycleState.currentPhase)[0].withOpacity(0.3),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Day ${cycleState.currentDayOfCycle}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cycleState.currentPhase.name.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 120),
                    
                    // Insights Card
                    IntelligenceGlowWrapper(
                      borderRadius: 24,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: context.nc.cardSurface.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: context.nc.cardBorder.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'intelligence insights'.toUpperCase(),
                                  style: TextStyle(
                                    color: context.nc.textTertiary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _getPhaseDescription(cycleState.currentPhase),
                                  style: TextStyle(
                                    color: context.nc.textPrimary,
                                    fontSize: 15,
                                    height: 1.6,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Log Action Button
                    const SizedBox(height: 24),
                    if (cycleState.logs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Center(
                          child: Text(
                            'Period started on ${DateFormat('MMMM d').format(cycleState.logs.first.startDate)}',
                            style: TextStyle(
                              color: context.nc.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    
                    if (cycleState.logs.isNotEmpty && DateTime.now().difference(cycleState.logs.first.startDate).inDays < 20) ...[
                      GestureDetector(
                        onTap: () async {
                          final latestLog = cycleState.logs.first;
                          final date = await showDatePicker(
                            context: context,
                            initialDate: latestLog.startDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 60)),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            ref.read(cycleIntelligenceProvider.notifier).logPeriodStart(date);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            color: context.nc.primary,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: context.nc.primary.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Edit Period Start',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: context.nc.cardSurface,
                              title: const Text('Delete Entry?'),
                              content: const Text('This will remove the current period log and reset your cycle intelligence context.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Cancel', style: TextStyle(color: context.nc.textSecondary)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref.read(cycleIntelligenceProvider.notifier).deleteLatestLog();
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text(
                          'Delete Entry',
                          style: TextStyle(
                            color: context.nc.textTertiary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 60)),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            ref.read(cycleIntelligenceProvider.notifier).logPeriodStart(date);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            color: context.nc.primary,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: context.nc.primary.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Log Period Start',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
    );
  }

  List<Color> _getPhaseColors(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return [const Color(0xFFE11D48), const Color(0xFF9F1239)]; // Rose/Crimson
      case CyclePhase.follicular:
        return [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]; // Blue
      case CyclePhase.ovulatory:
        return [const Color(0xFF10B981), const Color(0xFF047857)]; // Emerald
      case CyclePhase.luteal:
        return [const Color(0xFFF59E0B), const Color(0xFFB45309)]; // Amber
      case CyclePhase.unknown:
        return [const Color(0xFF6B7280), const Color(0xFF374151)]; // Gray
    }
  }

  String _getPhaseDescription(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return 'Resting heart rate might be slightly elevated. Focus on recovery and gentle movement. AI expects lower HRV during this reset. (Source: PMID 32661332)';
      case CyclePhase.follicular:
        return 'Estrogen is rising. Your body is highly resilient to stress. This is your window for high-intensity training. (Source: PMID 31102044)';
      case CyclePhase.ovulatory:
        return 'Energy and strength are at their peak. You are primed for PRs, but watch for ligament laxity risk. (Source: PMID 23878233)';
      case CyclePhase.luteal:
        return 'Progesterone is dominant. Core temperature rises and HRV naturally drops. Increase protein intake. (Source: PMID 33810146)';
      case CyclePhase.unknown:
        return 'Log your period to unlock AI-driven insights tailored to your hormonal rhythm.';
    }
  }

  void _showCycleSettings(BuildContext context, WidgetRef ref) {
    final profile = ref.read(patientProfileProvider).value;
    final currentLength = int.tryParse(profile?.questionnaireData?['cycle_length']?.toString() ?? '28') ?? 28;
    final controller = TextEditingController(text: currentLength.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.nc.cardSurface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: context.nc.cardBorder.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cycle Settings',
                    style: TextStyle(
                      color: context.nc.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Average Cycle Length (20-45 Days)',
                    style: TextStyle(
                      color: context.nc.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: context.nc.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. 28',
                      hintStyle: TextStyle(color: context.nc.textTertiary),
                      fillColor: context.nc.cardSurface.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.nc.cardBorder.withValues(alpha: 0.2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: context.nc.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final newLength = int.tryParse(controller.text);
                          if (newLength == null || newLength < 20 || newLength > 45) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid cycle length between 20 and 45 days.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          
                          final currentData = Map<String, dynamic>.from(profile?.questionnaireData ?? {});
                          currentData['cycle_length'] = newLength;
                          await ref.read(patientProfileProvider.notifier).updateQuestionnaire(currentData);
                          await ref.read(cycleIntelligenceProvider.notifier).fetchLogs();
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.nc.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
