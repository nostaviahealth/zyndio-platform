import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/daily_rhythm.dart';
import '../providers/rhythm_provider.dart';
import '../providers/blueprint_provider.dart';
import '../providers/protocol_provider.dart';
import '../providers/wearable_sync_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/questionnaire_provider.dart';
import '../providers/purchase_provider.dart';
import '../screens/settings/paywall_screen.dart';
import 'loading_skeleton.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import 'blueprint_calendar.dart';
import 'intelligence_glow_wrapper.dart';

class RhythmCard extends ConsumerStatefulWidget {
  const RhythmCard({super.key});

  @override
  ConsumerState<RhythmCard> createState() => _RhythmCardState();
}

class _RhythmCardState extends ConsumerState<RhythmCard> {
  String? _expandedCategory;

  void _toggleExpand(String category) {
    setState(() {
      if (_expandedCategory == category) {
        _expandedCategory = null;
      } else {
        _expandedCategory = category;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Watch the state
    final rhythmState = ref.watch(dailyRhythmProvider);
    final rhythmAsync = rhythmState.rhythm;
    final wearableState = ref.watch(wearableSyncProvider);
    final wearable = wearableState.value?.snapshot;
    final profileAsync = ref.watch(patientProfileProvider);
    final profile = profileAsync.value;
    final questionnaire = ref.watch(questionnaireProvider);
    final isPlus = ref.watch(purchaseProvider).isPlus;

    return rhythmAsync.when(
      data: (rhythm) {
        if (rhythm == null) return const SizedBox.shrink();

        // Group tasks by category
        final lifestyleTasks = rhythm.tasks.where((t) => t.category.toLowerCase() == 'lifestyle').toList();
        final dietTasks = rhythm.tasks.where((t) => t.category.toLowerCase() == 'diet').toList();
        final fitnessTasks = rhythm.tasks.where((t) => t.category.toLowerCase() == 'fitness').toList();
        final supplementTasks = rhythm.tasks.where((t) => t.category.toLowerCase() == 'supplement').toList();
        
        // Profile is "incomplete" if BOTH the local questionnaire isn't finished AND the server hasn't calculated bioAge
        final bool isProfileIncomplete = (profile?.age == null || profile?.bioAge == null) && !questionnaire.isComplete;

        return Column(
          children: [
            // Longevity Profile Completion Prompt (Urgent)
            if (isProfileIncomplete)
               Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _LongevityPromptCard(
                  onTap: () => context.push('/questionnaire'),
                ),
              ),

            // Blueprint Calendar (if active)
            Consumer(builder: (context, ref, _) {
              final bpState = ref.watch(blueprintProvider);
              
              if (bpState.blueprint != null) {
                return Column(
                  children: [
                    BlueprintCalendar(),
                    const SizedBox(height: 16),
                  ],
                );
              }
              
              if (bpState.isLoading) {
                return Column(
                  children: [
                    const SkeletonCard(height: 140),
                    const SizedBox(height: 16),
                  ],
                );
              }

              if (bpState.error != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.cloudOff, color: Color(0xFFEF4444), size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                bpState.error!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                             final selectedId = ref.read(protocolProvider).selectedProtocolId;
                             if (selectedId != null) {
                               ref.read(blueprintProvider.notifier).fetchBlueprint(selectedId);
                             }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Retry Sync',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return const SizedBox.shrink();
            }),

            // SINGLE PARENT CONSOLIDATED INTELLIGENCE ADAPT CARD
            IntelligenceGlowWrapper(
              borderRadius: 32,
              blurSigma: 25,
              active: rhythmState.isAdjusting,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF4C1D95), Color(0xFF120E2E)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: context.nc.isDark ? 20 : 0,
                      sigmaY: context.nc.isDark ? 20 : 0,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Title & Action Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'DAILY BLUEPRINT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withOpacity(0.85),
                                  letterSpacing: 2,
                                ),
                              ),
                              _buildAdaptTriggers(context, ref, rhythmState, isPlus),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(color: Colors.white.withOpacity(0.08), height: 1, thickness: 1),
                          const SizedBox(height: 10),

                          // 2. Categories
                          _buildCategoryItem(
                            context,
                            title: "Lifestyle",
                            subtitle: "Circadian essentials",
                            icon: LucideIcons.sun,
                            color: BrandColors.orange500,
                            tasks: lifestyleTasks,
                            isExpanded: _expandedCategory == 'lifestyle',
                            onTap: () => _toggleExpand('lifestyle'),
                          ),
                          _buildCategoryDivider(),
                          _buildCategoryItem(
                            context,
                            title: "Diet",
                            subtitle: "Nutritional windows",
                            icon: LucideIcons.utensils,
                            color: BrandColors.emerald500,
                            tasks: dietTasks,
                            isExpanded: _expandedCategory == 'diet',
                            onTap: () => _toggleExpand('diet'),
                          ),
                          _buildCategoryDivider(),
                          _buildCategoryItem(
                            context,
                            title: "Fitness",
                            subtitle: "Movement & activity",
                            icon: LucideIcons.zap,
                            color: BrandColors.blue500,
                            tasks: fitnessTasks,
                            isExpanded: _expandedCategory == 'fitness',
                            onTap: () => _toggleExpand('fitness'),
                          ),
                          _buildCategoryDivider(),
                          _buildCategoryItem(
                            context,
                            title: "Supplements",
                            subtitle: "Protocol optimization",
                            icon: LucideIcons.pill,
                            color: BrandColors.purple500,
                            tasks: supplementTasks,
                            isExpanded: _expandedCategory == 'supplement',
                            onTap: () => _toggleExpand('supplement'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const _RhythmSkeleton(),
      error: (err, stack) {
         return Container(
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
           child: Text("Rhythm Sync Error: $err", style: const TextStyle(color: Colors.red)),
         );
      },
    );
  }

  Widget _buildCategoryDivider() {
    return Divider(
      color: Colors.white.withOpacity(0.06),
      height: 8,
      thickness: 1,
    );
  }

  Widget _buildAdaptTriggers(
    BuildContext context,
    WidgetRef ref,
    RhythmState rhythmState,
    bool isPlus,
  ) {
    final isAdjusting = rhythmState.isAdjusting;
    final isAdjusted = rhythmState.isAdjusted;

    if (isAdjusting) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation(Color(0xFFA855F7)),
        ),
      );
    }

    if (isAdjusted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Adapted',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
        ],
      );
    }

    // Adjust Manual button
    return GestureDetector(
      onTap: () async {
        if (isPlus) {
          HapticFeedback.heavyImpact();
          try {
            await ref.read(dailyRhythmProvider.notifier).intelligenceAdjust();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.toString().replaceAll('Exception: ', '')),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF1E293B),
                ),
              );
            }
          }
        } else {
          HapticFeedback.lightImpact();
          PaywallScreen.show(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
        ),
        child: const Text(
          'Adjust',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<RhythmTask> tasks,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final completedCount = tasks.where((i) => i.isCompleted).length;
    final totalCount = tasks.length;
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (tasks.isNotEmpty) onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: isExpanded ? Colors.white.withOpacity(0.05) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                // Category circular icon (High contrast and premium)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.22),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.35), width: 1.5),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tasks.isEmpty
                            ? 'No tasks for today'
                            : (isExpanded ? 'Tap to close' : subtitle),
                        style: TextStyle(
                          fontSize: 11,
                          color: tasks.isEmpty
                              ? Colors.white.withOpacity(0.35)
                              : Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Progress or Check or Chevron
                if (completedCount == totalCount && totalCount > 0)
                  Icon(LucideIcons.checkCircle2, color: color, size: 20)
                else if (!isExpanded && tasks.isNotEmpty)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3.0,
                      backgroundColor: Colors.white.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                else if (tasks.isNotEmpty)
                  Icon(LucideIcons.chevronUp, color: Colors.white.withOpacity(0.6), size: 18),
              ],
            ),
          ),
        ),
        // Expanded task list
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Column(
                    children: tasks.map((item) {
                      return _TaskRow(task: item, color: color);
                    }).toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}


// ═══════════════════════════════════════════════════════════════════
//  RHYTHM CATEGORY CARD (Unchanged from original)
// ═══════════════════════════════════════════════════════════════════

class _RhythmCategoryCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<RhythmTask> items; // Use real model

  const _RhythmCategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  State<_RhythmCategoryCard> createState() => _RhythmCategoryCardState();
}

class _RhythmCategoryCardState extends State<_RhythmCategoryCard> with SingleTickerProviderStateMixin {
  bool isExpanded = false;

  void toggleExpand() {
    setState(() {
      isExpanded = !isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
        // Show it but just with "No tasks"
    }

    final completedCount = widget.items.where((i) => i.isCompleted).length;
    final totalCount = widget.items.length;
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;
    final allDone = totalCount > 0 && completedCount == totalCount;

    return Column(
      children: [
        // 1. The Header Card (Actionable)
        GestureDetector(
          onTap: () {
             if (widget.items.isNotEmpty) toggleExpand();
          }, 
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Bottom Stack Shadow Layers (Visible only when COLLAPSED and has items)
              if (!isExpanded && widget.items.isNotEmpty) ...[
                Positioned(
                  top: 10, left: 24, right: 24, bottom: -10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: widget.color.withOpacity(0.08)),
                    ),
                  ),
                ),
                Positioned(
                  top: 5, left: 12, right: 12, bottom: -5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          widget.color.withOpacity(0.1),
                          const Color(0xFF0F172A).withOpacity(0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: widget.color.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10, offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Main Header Card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.color.withOpacity(0.15),
                      const Color(0xFF0F172A).withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: allDone ? widget.color.withOpacity(0.5) : widget.color.withOpacity(0.12), 
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: context.nc.isDark ? 20 : 0,
                      sigmaY: context.nc.isDark ? 20 : 0,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(widget.icon, color: widget.color, size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.items.isEmpty 
                                      ? 'No tasks for today' 
                                      : (isExpanded ? 'Tap to close' : widget.subtitle),
                                  style: TextStyle(fontSize: 12, color: widget.items.isEmpty ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.5)),
                                ),
                              ],
                            ),
                          ),
                          if (!isExpanded && widget.items.isNotEmpty)
                            SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 3,
                                backgroundColor: widget.color.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                              ),
                            )
                          else if (widget.items.isNotEmpty)
                            Icon(LucideIcons.chevronUp, color: Colors.white.withOpacity(0.6), size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. The Expanded "Card Stack" Content
        AnimatedSize(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          alignment: Alignment.topCenter,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 12), 
                  child: Column(
                    children: widget.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8), 
                        child: _TaskRow(task: item, color: widget.color),
                      );
                    }).toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _TaskRow extends ConsumerWidget {
  final RhythmTask task;
  final Color color;
  
  const _TaskRow({required this.task, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: task.isCompleted 
                    ? color.withOpacity(0.4) 
                    : Colors.white.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  ref.read(dailyRhythmProvider.notifier).toggleTask(task.id);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Custom Checkbox
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: task.isCompleted ? color : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: task.isCompleted ? color : Colors.white.withOpacity(0.28),
                            width: 2,
                          ),
                        ),
                        child: task.isCompleted 
                            ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      // Text Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: task.isCompleted ? Colors.white.withOpacity(0.3) : Colors.white,
                                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                decorationColor: Colors.white.withOpacity(0.3),
                              ),
                              child: Text(task.title),
                            ),
                            if (task.detail != null && task.detail!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  task.detail!,
                                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.65)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Time badge
                      if (task.time != null && task.time!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            task.time!,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.7)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LongevityPromptCard extends StatelessWidget {
  final VoidCallback onTap;

  const _LongevityPromptCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: context.nc.cardSurface,
          boxShadow: [
            BoxShadow(
              color: context.nc.shadowColor,
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: context.nc.isDark ? context.nc.cardBorder : BrandColors.orange100,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Stack(
              children: [
              // Subtle Warm Glow/Background Element (More compact)
              Positioned(
                top: -15,
                right: -15,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BrandColors.orange500.withOpacity(0.08),
                    ),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Urgent Tag (More compact)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: BrandColors.orange500,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'URGENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Small icon arrow (More compact)
                        Icon(LucideIcons.arrowRight, color: context.nc.iconSubtle, size: 16),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete Longevity Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.nc.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Unlock your biological age and personalized health story by completing your profile.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.nc.textSecondary,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class _RhythmSkeleton extends StatelessWidget {
  const _RhythmSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          
          // Activity/Status row skeleton (Matches intelligence_adjust_card)
          Row(
            children: [
              Expanded(child: const SkeletonCard(height: 110, child: Center(child: SkeletonLine(width: 60, height: 12)))),
              const SizedBox(width: 12),
              Expanded(child: const SkeletonCard(height: 110, child: Center(child: SkeletonLine(width: 60, height: 12)))),
            ],
          ),
          const SizedBox(height: 24),
          
          // Category cards skeleton (Lifestyle, Diet, etc.)
          const SkeletonCategoryCard(),
          const SkeletonCategoryCard(),
          const SkeletonCategoryCard(),
          const SkeletonCategoryCard(),
          
          const SizedBox(height: 12),
          
          // Task items skeleton (if it were expanded)
          ...List.generate(2, (index) => const SkeletonTaskRow()),
        ],
      ),
    );
  }
}

