import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../models/meal_plan.dart';
import '../../widgets/weekly_menu_card.dart';
import '../../providers/chat_provider.dart';
import '../../providers/patient_provider.dart';
import '../../data/meal_repository.dart';

/// Full-screen bottom sheet to preview an AI-generated meal plan.
/// Live-syncs with the ChatProvider to reflect real-time swaps and optimizations.
class MealPlanCanvas extends ConsumerWidget {
  final MealPlan plan; // Initial plan
  final VoidCallback onClose;
  final VoidCallback onSave;

  const MealPlanCanvas({
    super.key,
    required this.plan,
    required this.onClose,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    
    // Always resolve the LATEST meal plan from history to ensure sync during swaps
    MealPlan activePlan = plan;
    try {
      final latestMealMsg = chatState.messages.lastWhere((m) => m.mealPlan != null);
      activePlan = latestMealMsg.mealPlan!;
    } catch (_) {
      // Fallback to initial plan if history is cleared
    }

    // Calculate total daily calories
    int totalDailyCalories = 0;
    if (activePlan.weeklyPlan.isNotEmpty) {
      int sum = 0;
      for (final day in activePlan.weeklyPlan) {
        for (final meal in day.meals) {
          sum += meal.calories;
        }
      }
      totalDailyCalories = (sum / activePlan.weeklyPlan.length).round();
    }

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Container(
        decoration: BoxDecoration(
          color: context.nc.scaffoldBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // --- AURORA BACKDROP ---
            Positioned(
              top: -100,
              right: -50,
              child: _AuroraBlob(color: const Color(0xFFF59E0B), size: 300, opacity: 0.12),
            ),
            Positioned(
              top: 200,
              left: -100,
              child: _AuroraBlob(color: const Color(0xFFA855F7), size: 400, opacity: 0.08),
            ),

            Column(
              children: [
                // Drag Handle
                Container(
                  height: 32,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.nc.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      _buildHeader(context, activePlan),
                      _buildSummaryBadges(context, totalDailyCalories),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                          child: WeeklyMenuCard(plan: activePlan),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Bar
                _buildBottomBar(context, ref, activePlan),
              ],
            ),

            // --- LOADING OVERLAY (METABOLIC RE-OPTIMIZATION) ---
            if (chatState.isLoading)
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      color: context.nc.cardSurface.withOpacity(0.6),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 3, 
                              color: context.nc.primary,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "RE-OPTIMIZING PROTOCOL",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: context.nc.textPrimary,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Matching metabolic markers and goals...",
                              style: TextStyle(
                                fontSize: 14,
                                color: context.nc.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, MealPlan plan) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.nc.cardSurface.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.sparkles, size: 10, color: const Color(0xFF3B82F6)),
                      const SizedBox(width: 6),
                      Text(
                        "INTELLIGENCE GENERATED",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF3B82F6),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.nc.cardSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.nc.cardBorder),
                    ),
                    child: Icon(LucideIcons.x, size: 18, color: context.nc.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              plan.name,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: context.nc.textPrimary,
                letterSpacing: -1.2,
                height: 1.0,
                fontFamily: 'SF Pro Display',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "A 7-day metabolic protocol optimized for your biological markers.",
              style: TextStyle(
                fontSize: 16,
                color: context.nc.textSecondary,
                letterSpacing: -0.3,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBadges(BuildContext context, int avgCalories) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Row(
          children: [
            _badge(context, LucideIcons.flame, "$avgCalories kcal", const Color(0xFFF59E0B)),
            const SizedBox(width: 12),
            _badge(context, LucideIcons.calendar, "7 Days", const Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.nc.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, WidgetRef ref, MealPlan activePlan) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        border: Border(top: BorderSide(color: context.nc.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              color: context.nc.inputFill,
              onPressed: onClose,
              borderRadius: BorderRadius.circular(12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.x, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text("Discard", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 16)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              color: const Color(0xFF10B981),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final profile = ref.read(patientProfileProvider).value;
                if (profile != null) {
                  try {
                    await MealRepository.saveGeneratedPlan(profile.id, activePlan);
                    onSave(); // Close it after saving
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.save, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text("Save Menu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _AuroraBlob({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(0),
          ],
        ),
      ),
      child: ImageFiltered(
        imageFilter: ColorFilter.mode(color.withOpacity(opacity), BlendMode.srcATop),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
