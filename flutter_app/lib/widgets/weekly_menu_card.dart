import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/theme.dart';
import '../models/meal_plan.dart';
import '../providers/chat_provider.dart';
import 'macro_gauge.dart';
import 'tc025/tc025_widgets.dart';

/// Macro colours, shared with [MacroGauge]'s bar segments.
final Color _proteinColor = ZyndioTint.green.colors.last;
final Color _carbsColor = ZyndioTint.blue.colors.last;
final Color _fatsColor = ZyndioTint.amber.colors.last;

class WeeklyMenuCard extends StatefulWidget {
  final MealPlan plan;

  const WeeklyMenuCard({super.key, required this.plan});

  @override
  State<WeeklyMenuCard> createState() => _WeeklyMenuCardState();
}

class _WeeklyMenuCardState extends State<WeeklyMenuCard> {
  int _selectedDayIndex = 0;
  late MealPlan _currentPlan;

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.plan;
  }

  @override
  void didUpdateWidget(WeeklyMenuCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan != widget.plan) {
      _currentPlan = widget.plan;
    }
  }

  void _updateLocalPlan(MealPlan newPlan) {
    setState(() {
      _currentPlan = newPlan;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final dayPlan = _currentPlan.weeklyPlan.isNotEmpty
        ? _currentPlan.weeklyPlan.length > _selectedDayIndex
            ? _currentPlan.weeklyPlan[_selectedDayIndex]
            : _currentPlan.weeklyPlan[0]
        : null;

    if (dayPlan == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day selector: horizontal pills sized by their content, so large
        // accessibility text grows them instead of clipping.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0;
                  index < widget.plan.weeklyPlan.length;
                  index++) ...[
                if (index > 0) const SizedBox(width: 10),
                _DayChip(
                  day: widget.plan.weeklyPlan[index],
                  isSelected: index == _selectedDayIndex,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedDayIndex = index);
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Meals List
        ...List.generate(dayPlan.meals.length, (i) => _MealCard(
          plan: _currentPlan,
          meal: dayPlan.meals[i],
          dayIndex: _selectedDayIndex,
          mealIndex: i,
          onPlanUpdated: _updateLocalPlan,
        )),

        if (dayPlan.meals.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40.0),
            child: Center(
              child: Column(
                children: [
                  Icon(LucideIcons.utensils, size: 40, color: c.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    "No meals planned for this day",
                    textAlign: TextAlign.center,
                    style: ZyndioType.subhead.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final DayPlan day;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayChip({
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final z = context.z25;
    final fg = isSelected ? Colors.white : c.textPrimary;
    final selectedDecoration = BoxDecoration(
      gradient: ZyndioGradients.segmentActive,
      borderRadius: BorderRadius.circular(20),
    );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        constraints: const BoxConstraints(minWidth: 60),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: isSelected
            ? selectedDecoration
            : zyndioCard(context, radius: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              day.day.substring(0, 3).toUpperCase(),
              style: TextStyle(
                fontFamily: ZyndioType.family,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.85)
                    : z.segmentText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              day.date.split('-').last,
              style: TextStyle(
                fontFamily: ZyndioType.family,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                fontFeatures: ZyndioType.tabular,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealCard extends ConsumerWidget {
  final MealPlan plan;
  final Meal meal;
  final int dayIndex;
  final int mealIndex;
  final Function(MealPlan) onPlanUpdated;

  const _MealCard({
    required this.plan,
    required this.meal,
    required this.dayIndex,
    required this.mealIndex,
    required this.onPlanUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.zc;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ZyndioCard(
        padding: const EdgeInsets.all(20),
        radius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    meal.time,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: c.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildSwapButton(context, ref),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              meal.name,
              style: ZyndioType.title2.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              meal.desc,
              style: ZyndioType.subhead.copyWith(
                height: 22 / 15,
                color: c.textSecondary,
              ),
            ),

            if (meal.clinicalRationale != null) ...[
              const SizedBox(height: 16),
              _ExpandableInsight(text: meal.clinicalRationale!),
            ],

            const SizedBox(height: 20),

            // Metabolic Well
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.bgSunken,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MacroGauge(
                    protein: _parseMacro(meal.protein),
                    carbs: _parseMacro(meal.carbs),
                    fats: _parseMacro(meal.fats),
                    height: 10,
                  ),
                  const SizedBox(height: 16),
                  // Wrap: the three stats share a line when they fit and
                  // flow onto the next with large text on a small phone.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _CompactStat(label: "PROTEIN", value: meal.protein, color: _proteinColor),
                      _CompactStat(label: "CARBS", value: meal.carbs, color: _carbsColor),
                      _CompactStat(label: "FATS", value: meal.fats, color: _fatsColor),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSwapButton(BuildContext context, WidgetRef ref) {
    final c = context.zc;
    final z = context.z25;
    final chatState = ref.watch(chatProvider);
    final isLoading = chatState.isLoading &&
                      chatState.swappingDayIndex == dayIndex &&
                      chatState.swappingMealIndex == mealIndex;
    final fg = isLoading ? c.brandOnSubtle : z.badgeNeutralText;

    return GestureDetector(
      onTap: () {
        if (chatState.isLoading) return;
        HapticFeedback.heavyImpact();
        _showSwapSuggestions(context, ref);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isLoading ? c.brandSubtle : z.badgeNeutralBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: c.brandPrimary),
              )
            else
              Icon(LucideIcons.refreshCcw, size: 14, color: fg),
            const SizedBox(width: 8),
            Text(
              isLoading ? "SWAPPING..." : "SWAP",
              style: TextStyle(
                fontFamily: ZyndioType.family,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSwapSuggestions(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final c = context.zc;
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: c.bgSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: dark
                ? Border(top: BorderSide(color: c.borderSubtle))
                : null,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 12,
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Swap Meal",
                  style: ZyndioType.title2.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  "Any preferences for the replacement of '${meal.name}'?",
                  style: ZyndioType.subhead.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: ZyndioType.callout.copyWith(color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: "e.g., 'Make it high protein', 'I'm out of eggs', 'Something light'",
                    hintStyle: TextStyle(color: c.textTertiary),
                    hintMaxLines: 3,
                    filled: true,
                    fillColor: c.bgSunken,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: c.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: c.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: c.brandPrimary, width: 1.5),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                ZyndioGradientButton(
                  label: "GENERATE SWAP",
                  trailingArrow: false,
                  onTap: () async {
                    final suggestion = controller.text;
                    Navigator.pop(context);

                    // Start the swap
                    final newPlan = await ref.read(chatProvider.notifier).swapMealInPlace(
                      dayIndex: dayIndex,
                      mealIndex: mealIndex,
                      currentPlan: plan,
                      suggestion: suggestion,
                    );

                    if (newPlan != null) {
                      HapticFeedback.mediumImpact();
                      onPlanUpdated(newPlan);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _parseMacro(String value) {
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CompactStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.textTertiary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: ZyndioType.family,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
            fontFeatures: ZyndioType.tabular,
          ),
        ),
      ],
    );
  }
}

class _ExpandableInsight extends StatefulWidget {
  final String text;
  const _ExpandableInsight({required this.text});

  @override
  State<_ExpandableInsight> createState() => _ExpandableInsightState();
}

class _ExpandableInsightState extends State<_ExpandableInsight> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final bodyStyle = ZyndioType.footnote.copyWith(
      height: 20 / 13,
      color: c.textSecondary,
    );
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _isExpanded = !_isExpanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.statusSuccessSubtle,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.sparkles, size: 14, color: c.statusSuccess),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "INTELLIGENCE INSIGHT",
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.statusSuccess,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 16,
                  color: c.statusSuccess,
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: bodyStyle,
                ),
              ),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.text,
                  style: bodyStyle,
                ),
              ),
              crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }
}
