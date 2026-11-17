import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/activity_goals_provider.dart';
import '../../widgets/tc025/tc025_widgets.dart';

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

    return ZyndioDetailScaffold(
      title: 'Activity Goals',
      subtitle: 'Personalize your daily targets.',
      onBack: () => context.pop(),
      children: [
        _buildGoalSlider(
          title: "Move",
          icon: LucideIcons.flame,
          tint: ZyndioTint.rose,
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
        const SizedBox(height: 16),

        _buildGoalSlider(
          title: "Training",
          icon: LucideIcons.activity,
          tint: ZyndioTint.amber,
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
        const SizedBox(height: 16),

        _buildGoalSlider(
          title: "Steps",
          icon: LucideIcons.footprints,
          tint: ZyndioTint.green,
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
    );
  }

  Widget _buildGoalSlider({
    required String title,
    required IconData icon,
    required ZyndioTint tint,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final rangeStyle = TextStyle(
      fontFamily: ZyndioType.family,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: c.textTertiary,
      fontFeatures: ZyndioType.tabular,
    );
    return ZyndioCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ZyndioIconTile(icon: icon, tint: tint, size: 40),
              const SizedBox(width: 14),
              Text(
                title,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                "${value.toInt()} $unit",
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  fontFeatures: ZyndioType.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: c.brandPrimary,
              inactiveTrackColor: c.bgSunken,
              thumbColor: c.brandPrimary,
              overlayColor: c.brandPrimary.withValues(alpha: 0.12),
              activeTickMarkColor: Colors.transparent,
              inactiveTickMarkColor: Colors.transparent,
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
              Text("${min.toInt()}", style: rangeStyle),
              Text("${max.toInt()}", style: rangeStyle),
            ],
          )
        ],
      ),
    );
  }
}
