import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../config/supabase_config.dart';
import '../../data/food_images.dart';
import '../../models/food_log.dart';
import '../../widgets/tc025/tc025_widgets.dart';

/// Provider for Food Logs
final foodLogsProvider = FutureProvider.autoDispose<List<FoodLog>>((ref) async {
  final client = SupabaseConfig.client;
  if (client == null) return [];

  final userId = SupabaseConfig.currentUser?.id;
  if (userId == null) return [];

  final response = await client
      .from('food_logs')
      .select()
      .eq('patient_id', userId)
      .order('logged_at', ascending: false);

  return (response as List).map((e) => FoodLog.fromJson(e)).toList();
});

/// Redesigned Lens History Screen
class LensHistoryScreen extends ConsumerWidget {
  const LensHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(foodLogsProvider);
    final c = Theme.of(context).extension<ZyndioColors>()!;

    return ZyndioDetailScaffold(
      title: 'Meals',
      onBack: () => context.pop(),
      body: RefreshIndicator(
        color: c.brandPrimary,
        backgroundColor: c.bgSurface,
        onRefresh: () async => ref.refresh(foodLogsProvider),
        child: logsAsync.when(
          loading: () =>
              Center(child: CircularProgressIndicator(color: c.brandPrimary)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Error: $e',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 15,
                  color: c.statusCritical,
                ),
              ),
            ),
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                children: const [
                  ZyndioStateCard(
                    icon: LucideIcons.utensilsCrossed,
                    title: 'No meals logged yet',
                    body: 'Use Lens to scan your first meal!',
                  ),
                ],
              );
            }

            // Group logs by date
            final grouped = _groupByDate(logs);

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final dateKey = grouped.keys.elementAt(index);
                final dateLogs = grouped[dateKey]!;
                return _buildDateSection(context, dateKey, dateLogs,
                    first: index == 0);
              },
            );
          },
        ),
      ),
    );
  }

  Map<String, List<FoodLog>> _groupByDate(List<FoodLog> logs) {
    final Map<String, List<FoodLog>> grouped = {};
    for (final log in logs) {
      final key = _formatDateHeader(log.loggedAt);
      grouped.putIfAbsent(key, () => []).add(log);
    }
    return grouped;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDay = DateTime(date.year, date.month, date.day);

    if (logDay == today) return 'Today';
    if (logDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  Widget _buildDateSection(
      BuildContext context, String dateHeader, List<FoodLog> logs,
      {bool first = false}) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZyndioSectionLabel(dateHeader),
          ...logs.map((log) => _buildCompactCard(context, log)),
        ],
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context, FoodLog log) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final timeStr = DateFormat('h:mm a').format(log.loggedAt);
    final foodName = _extractFoodName(log.analysis);
    final macros = _extractMacrosSummary(log.analysis);
    final score = log.analysis['score'] ?? 0;
    final scoreColor = score >= 80
        ? c.statusSuccess
        : (score >= 50 ? c.statusWarning : c.statusCritical);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => context.push('/meal-detail', extra: log),
        child: ZyndioCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: log.imagePath != null && log.imagePath!.isNotEmpty
                        ? Consumer(
                            builder: (context, ref, _) {
                              final url = ref.watch(foodImageUrlProvider(log.imagePath!)).value ?? '';
                              if (url.isEmpty) return _imagePlaceholder(context);
                              return Image.network(
                                url,
                                width: 68,
                                height: 68,
                                fit: BoxFit.cover,
                                cacheWidth: 136,
                                cacheHeight: 136,
                                errorBuilder: (ctx, e, s) => _imagePlaceholder(ctx),
                              );
                            },
                          )
                        : _imagePlaceholder(context),
                  ),
                  if (score > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.bgSurface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$score',
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            color: scoreColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foodName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 16,
                        height: 22 / 16,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      macros,
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 13,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Time & Chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(LucideIcons.chevronRight, size: 18, color: c.textTertiary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: c.bgSunken,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(LucideIcons.image, color: c.textTertiary, size: 24),
    );
  }

  String _extractFoodName(Map<String, dynamic> json) {
    // Try common keys
    if (json['foods'] is List && (json['foods'] as List).isNotEmpty) {
      final first = json['foods'][0];
      return first['name'] ?? 'Analyzed Meal';
    }
    return json['food_name'] ?? json['dish_name'] ?? json['description'] ?? 'Analyzed Meal';
  }

  String _extractMacrosSummary(Map<String, dynamic> json) {
    final macros = json['macros'] ?? json;

    // Check root for calories first (new format), then fallback
    final calories = json['calories'] ?? macros['calories'] ?? macros['total_calories'];
    final protein = macros['protein'] ?? macros['protein_g'];

    if (calories == null && protein == null) return 'Tap for details';

    final buffer = StringBuffer();
    if (calories != null) buffer.write('$calories kcal');
    if (calories != null && protein != null) buffer.write('  •  ');
    if (protein != null) buffer.write('${protein}g protein');
    return buffer.toString();
  }
}
