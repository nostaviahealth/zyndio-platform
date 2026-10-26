import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/activity_goals_provider.dart';

class ActivityGoalsScreen extends ConsumerStatefulWidget {
  const ActivityGoalsScreen({super.key});

  @override
  ConsumerState<ActivityGoalsScreen> createState() => _ActivityGoalsScreenState();
}

class _ActivityGoalsScreenState extends ConsumerState<ActivityGoalsScreen> {
  // Local state to hold temporary edits before saving, optional, 
  // but using real-time sync with provider is snappier here.
  
  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(activityGoalsProvider);
    final notifier = ref.read(activityGoalsProvider.notifier);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: context.nc.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Activity Goals',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.nc.textPrimary,
            ),
          ),
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: context.nc.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personalize your daily targets.',
                style: TextStyle(
                  fontSize: 14,
                  color: BrandColors.slate500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              _buildGoalSlider(
                title: "Move",
                icon: LucideIcons.flame,
                color: const Color(0xFFF43F5E),
                value: goals.moveGoal,
                min: 100,
                max: 2000,
                divisions: 38, // Every 50 kcal
                unit: "kcal",
                onChanged: (val) {
                  notifier.updateGoals(move: val);
                  HapticFeedback.selectionClick();
                },
              ),
              const SizedBox(height: 24),

              _buildGoalSlider(
                title: "Training",
                icon: LucideIcons.activity,
                color: const Color(0xFFF97316),
                value: goals.exerciseGoal.toDouble(),
                min: 10,
                max: 180,
                divisions: 34, // Every 5 min
                unit: "min",
                onChanged: (val) {
                  notifier.updateGoals(exercise: val.toInt());
                  HapticFeedback.selectionClick();
                },
              ),
              const SizedBox(height: 24),

              _buildGoalSlider(
                title: "Steps",
                icon: LucideIcons.footprints,
                color: const Color(0xFF10B981),
                value: goals.stepsGoal.toDouble(),
                min: 1000,
                max: 30000,
                divisions: 29, // Every 1000 steps
                unit: "steps",
                onChanged: (val) {
                  notifier.updateGoals(steps: val.toInt());
                  HapticFeedback.selectionClick();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalSlider({
    required String title,
    required IconData icon,
    required Color color,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            offset: const Offset(0, 8),
            blurRadius: 24,
          )
        ],
        border: Border.all(color: context.nc.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.nc.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                "${value.toInt()} $unit",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.1),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${min.toInt()}", style: const TextStyle(fontSize: 11, color: BrandColors.slate400, fontWeight: FontWeight.w500)),
              Text("${max.toInt()}", style: const TextStyle(fontSize: 11, color: BrandColors.slate400, fontWeight: FontWeight.w500)),
            ],
          )
        ],
      ),
    );
  }
}
