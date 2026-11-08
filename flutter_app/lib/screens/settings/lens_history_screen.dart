import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../config/supabase_config.dart';
import '../../data/food_images.dart';
import '../../models/food_log.dart';
import '../../widgets/app_card.dart';

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

    return Scaffold(
      backgroundColor: BrandColors.background,
      appBar: AppBar(
        title: const Text('Meals'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(foodLogsProvider),
        child: logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: BrandColors.emerald500)),
          error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: BrandColors.red500))),
          data: (logs) {
            if (logs.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Column(
                      children: [
                        Icon(LucideIcons.utensilsCrossed, size: 48, color: BrandColors.slate300),
                        SizedBox(height: 16),
                        Text('No meals logged yet', style: TextStyle(color: BrandColors.slate500)),
                        SizedBox(height: 8),
                        Text('Use Lens to scan your first meal!', style: TextStyle(color: BrandColors.slate400, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Group logs by date
            final grouped = _groupByDate(logs);

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final dateKey = grouped.keys.elementAt(index);
                final dateLogs = grouped[dateKey]!;
                return _buildDateSection(context, dateKey, dateLogs);
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

  Widget _buildDateSection(BuildContext context, String dateHeader, List<FoodLog> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            dateHeader.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: BrandColors.slate400,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...logs.map((log) => _buildCompactCard(context, log)),
      ],
    );
  }

  Widget _buildCompactCard(BuildContext context, FoodLog log) {
    final timeStr = DateFormat('h:mm a').format(log.loggedAt);
    final foodName = _extractFoodName(log.analysis);
    final macros = _extractMacrosSummary(log.analysis);
    final score = log.analysis['score'] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => context.push('/meal-detail', extra: log),
        child: AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: log.imagePath != null && log.imagePath!.isNotEmpty
                        ? Consumer(
                            builder: (context, ref, _) {
                              final url = ref.watch(foodImageUrlProvider(log.imagePath!)).value ?? '';
                              if (url.isEmpty) return _imagePlaceholder();
                              return Image.network(
                                url,
                                width: 68,
                                height: 68,
                                fit: BoxFit.cover,
                                cacheWidth: 136,
                                cacheHeight: 136,
                                errorBuilder: (c, e, s) => _imagePlaceholder(),
                              );
                            },
                          )
                        : _imagePlaceholder(),
                  ),
                  if (score > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: (score >= 80 ? BrandColors.emerald500 : (score >= 50 ? BrandColors.amber500 : BrandColors.red500)).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 2),
                          ],
                        ),
                        child: Text(
                          '$score',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: BrandColors.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      macros,
                      style: const TextStyle(fontSize: 12, color: BrandColors.slate500),
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
                    style: const TextStyle(fontSize: 11, color: BrandColors.slate400),
                  ),
                  const SizedBox(height: 8),
                  const Icon(LucideIcons.chevronRight, size: 18, color: BrandColors.slate300),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: BrandColors.slate100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(LucideIcons.image, color: BrandColors.slate300, size: 24),
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
