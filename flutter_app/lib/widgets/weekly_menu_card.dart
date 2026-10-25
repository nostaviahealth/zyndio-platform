import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/meal_plan.dart';
import '../config/theme.dart';
import '../providers/chat_provider.dart';
import 'macro_gauge.dart';

import 'dart:ui' as ui;

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
    final dayPlan = _currentPlan.weeklyPlan.isNotEmpty 
        ? _currentPlan.weeklyPlan.length > _selectedDayIndex 
            ? _currentPlan.weeklyPlan[_selectedDayIndex] 
            : _currentPlan.weeklyPlan[0]
        : null;

    if (dayPlan == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Day Selector
        SizedBox(
          height: 84,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.plan.weeklyPlan.length,
            separatorBuilder: (c, i) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final d = widget.plan.weeklyPlan[index];
              final isSelected = index == _selectedDayIndex;
              final accentColor = const Color(0xFF10B981); // Emerald

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedDayIndex = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 68,
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? accentColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.2),
                        blurRadius: 15,
                        spreadRadius: -5,
                      )
                    ] : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            d.day.substring(0, 3).toUpperCase(),
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.w900,
                              color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.4),
                              letterSpacing: 1.0,
                            )
                          ),
                          const SizedBox(height: 6),
                          Text(
                            d.date.split('-').last,
                            style: TextStyle(
                              fontSize: 22, 
                              fontWeight: FontWeight.w900,
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
                              letterSpacing: -0.5,
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 40),

        // Meals List
        ...List.generate(dayPlan.meals.length, (i) => _MealCard(
          plan: _currentPlan,
          meal: dayPlan.meals[i],
          dayIndex: _selectedDayIndex,
          mealIndex: i,
          onPlanUpdated: _updateLocalPlan,
        )),

        if (dayPlan.meals.isEmpty)
           const Padding(
             padding: EdgeInsets.all(40.0),
             child: Center(
               child: Column(
                 children: [
                   Icon(LucideIcons.utensils, size: 40, color: Colors.white24),
                   SizedBox(height: 16),
                   Text("No meals planned for this day", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w600)),
                 ],
               ),
             ),
           )
      ],
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
    final accentColor = const Color(0xFF3B82F6); // Blue for meals

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: 0.05),
                  Colors.transparent,
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
                      meal.time, 
                      style: const TextStyle(
                        fontSize: 13, 
                        fontWeight: FontWeight.w900, 
                        color: Colors.white38,
                        letterSpacing: 1.5,
                      )
                    ),
                    _buildSwapButton(context, ref),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  meal.name, 
                  style: const TextStyle(
                    fontSize: 26, 
                    fontWeight: FontWeight.w900, 
                    color: Colors.white, 
                    letterSpacing: -0.5,
                    height: 1.1,
                  )
                ),
                const SizedBox(height: 12),
                Text(
                  meal.desc, 
                  style: TextStyle(
                    fontSize: 15, 
                    color: Colors.white.withValues(alpha: 0.5), 
                    height: 1.5,
                    letterSpacing: -0.2,
                    fontWeight: FontWeight.w500,
                  )
                ),

                if (meal.clinicalRationale != null) ...[
                  const SizedBox(height: 24),
                  _ExpandableInsight(text: meal.clinicalRationale!),
                ],
                
                const SizedBox(height: 32),
                
                // Metabolic Well
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      MacroGauge(
                        protein: _parseMacro(meal.protein), 
                        carbs: _parseMacro(meal.carbs), 
                        fats: _parseMacro(meal.fats),
                        height: 10,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _CompactStat(label: "PROTEIN", value: meal.protein, color: const Color(0xFF10B981)),
                          _CompactStat(label: "CARBS", value: meal.carbs, color: const Color(0xFF3B82F6)),
                          _CompactStat(label: "FATS", value: meal.fats, color: const Color(0xFFF59E0B)),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwapButton(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    final isLoading = chatState.isLoading && 
                      chatState.swappingDayIndex == dayIndex && 
                      chatState.swappingMealIndex == mealIndex;

    return GestureDetector(
      onTap: () {
        if (chatState.isLoading) return;
        HapticFeedback.heavyImpact();
        _showSwapSuggestions(context, ref);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isLoading ? const Color(0xFF3B82F6).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isLoading ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 12, 
                  height: 12, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6))
                ),
              )
            else
              const Icon(LucideIcons.refreshCcw, size: 14, color: Colors.white70),
            const SizedBox(width: 8),
            Text(
              isLoading ? "SWAPPING..." : "SWAP", 
              style: TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.w900, 
                color: isLoading ? const Color(0xFF3B82F6) : Colors.white,
                letterSpacing: 0.5,
              )
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
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Swap Meal",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "Any preferences for the replacement of '${meal.name}'?",
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: "e.g., 'Make it high protein', 'I'm out of eggs', 'Something light'",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  "GENERATE SWAP",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
              ),
            ),
          ],
        ),
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4)],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.3),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _isExpanded = !_isExpanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.sparkles, size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 10),
                    Text(
                      "INTELLIGENCE INSIGHT",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 14,
                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  widget.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.6),
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
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
