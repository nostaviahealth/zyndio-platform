import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../config/supabase_config.dart';
import '../../models/food_log.dart';
import '../../models/food_analysis.dart';
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
      .eq('user_id', userId)
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
                        ? Image.network(
                            _getPublicUrl(log.imagePath!),
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                            cacheWidth: 136,
                            cacheHeight: 136,
                            errorBuilder: (c, e, s) => _imagePlaceholder(),
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

  void _showDetailSheet(BuildContext context, FoodLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _FoodLogDetailView(log: log, scrollController: scrollController, getPublicUrl: _getPublicUrl),
        ),
      ),
    );
  }

  String _getPublicUrl(String path) {
    if (path.startsWith('http')) return path;
    final client = SupabaseConfig.client;
    if (client == null) return '';
    return client.storage.from('food-images').getPublicUrl(path);
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

Color _impactColor(String impact) {
  switch (impact.toLowerCase()) {
    case 'positive': return BrandColors.emerald500;
    case 'negative': return BrandColors.red500;
    default: return BrandColors.amber500;
  }
}

IconData _impactIcon(String impact) {
  switch (impact.toLowerCase()) {
    case 'positive': return LucideIcons.trendingUp;
    case 'negative': return LucideIcons.trendingDown;
    default: return LucideIcons.minus;
  }
}

/// Detail View for a single food log (shown in bottom sheet) — V2 FULL
class _FoodLogDetailView extends StatelessWidget {
  final FoodLog log;
  final ScrollController scrollController;
  final String Function(String) getPublicUrl;

  const _FoodLogDetailView({required this.log, required this.scrollController, required this.getPublicUrl});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d • h:mm a').format(log.loggedAt);
    
    // Parse the full FoodAnalysis from stored JSON
    final FoodAnalysis data = FoodAnalysis.fromJson(log.analysis);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: BrandColors.slate200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Date Header
        Text(
          dateStr,
          style: const TextStyle(fontSize: 13, color: BrandColors.slate500),
        ),
        const SizedBox(height: 4),
        Text(
          log.mealType?.toUpperCase() ?? 'MEAL',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: BrandColors.dark,
          ),
        ),
        const SizedBox(height: 16),

        // Image
        if (log.imagePath != null && log.imagePath!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              getPublicUrl(log.imagePath!),
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: 800,
              cacheHeight: 800,
              errorBuilder: (c, e, s) => Container(
                height: 220,
                color: BrandColors.slate100,
                child: const Center(child: Icon(LucideIcons.imageOff, size: 48, color: BrandColors.slate300)),
              ),
            ),
          ),
        const SizedBox(height: 20),

        // ── Hero Score ────────────────────────────────────────────────────
        if (data.score > 0)
          Center(
            child: Column(
              children: [
                _ScoreRingLight(score: data.score),
                const SizedBox(height: 4),
                const Text('ZYNDIO SCORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: BrandColors.slate400, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Text(
                  data.foodName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BrandColors.dark),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${data.calories} kcal',
                  style: const TextStyle(fontSize: 14, color: BrandColors.slate500),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        const SizedBox(height: 24),

        _LightIntelligenceInsight(insight: data.intelligenceInsight),
        
        const SizedBox(height: 24),

        // ── Macros ────────────────────────────────────────────────────────
        _buildMacrosCard(data),
        const SizedBox(height: 16),

        // ── Detected Foods ────────────────────────────────────────────────
        if (data.ingredients.isNotEmpty) ...[
          _sectionTitle('DETECTED FOODS'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.ingredients.map((f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: BrandColors.slate100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                f.amount.isNotEmpty ? '${f.name} (${f.amount})' : f.name,
                style: const TextStyle(fontSize: 13, color: BrandColors.slate700),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // ── Circadian Match ───────────────────────────────────────────────
        if (data.circadianMatch.match != 'Unknown') ...[
          _sectionTitle('CIRCADIAN ALIGNMENT'),
          const SizedBox(height: 10),
          _LightCircadianCard(circadian: data.circadianMatch),
          const SizedBox(height: 20),
        ],

        // ── Bio-Hack Tip ──────────────────────────────────────────────────
        if (data.bioHack.tip.isNotEmpty) ...[
          _sectionTitle('OPTIMIZATION TIP'),
          const SizedBox(height: 10),
          _LightBioHackCard(bioHack: data.bioHack),
          const SizedBox(height: 20),
        ],

        // ── Hormonal Impact ───────────────────────────────────────────────
        if (data.hormonalImpact.insulin.response != 'Unknown') ...[
          _sectionTitle('HORMONAL IMPACT'),
          const SizedBox(height: 10),
          _LightHormoneRow(hormone: data.hormonalImpact.insulin, icon: LucideIcons.activity),
          const SizedBox(height: 8),
          _LightHormoneRow(hormone: data.hormonalImpact.leptin, icon: LucideIcons.shield),
          const SizedBox(height: 8),
          _LightHormoneRow(hormone: data.hormonalImpact.ghrelin, icon: LucideIcons.flame),
          const SizedBox(height: 20),
        ],

        // ── Metabolic Simulation ──────────────────────────────────────────
        _sectionTitle('METABOLIC SIMULATION'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BrandColors.slate50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BrandColors.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LightMetabolicChip(label: 'Digestion', value: data.metabolicImpact.digestionTime),
                  const SizedBox(width: 10),
                  _LightMetabolicChip(label: 'Energy Curve', value: data.metabolicImpact.energyCurve),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Bioavailability ───────────────────────────────────────────────
        if (data.bioavailability.absorptionScore > 0 || data.bioavailability.tips.isNotEmpty) ...[
          _sectionTitle('ABSORPTION & PREP'),
          const SizedBox(height: 10),
          _LightBioavailabilityCard(bioavailability: data.bioavailability),
          const SizedBox(height: 20),
        ],

        // ── UPF Processing ────────────────────────────────────────────────
        if (data.upfAnalysis.level != 'Unknown') ...[
          _sectionTitle('PROCESSING SCORE'),
          const SizedBox(height: 10),
          _LightUPFCard(upf: data.upfAnalysis),
          const SizedBox(height: 20),
        ],

        // ── Bio-Impact Analysis ───────────────────────────────────────────
        if (data.bioImpact.isNotEmpty) ...[
          _sectionTitle('HEALTH INSIGHTS'),
          const SizedBox(height: 10),
          ...data.bioImpact.map((b) => _buildBioImpactCard(b)),
          const SizedBox(height: 20),
        ],

        // ── Toxin Radar ───────────────────────────────────────────────────
        if (data.toxins.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: BrandColors.red500.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BrandColors.red500.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.shieldAlert, color: BrandColors.red500, size: 16),
                const SizedBox(width: 10),
                const Text(
                  'TOXIN RADAR',
                  style: TextStyle(color: BrandColors.red500, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2),
                ),
                const Spacer(),
                Text(
                  '${data.toxins.length} threats',
                  style: const TextStyle(color: BrandColors.red500, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...data.toxins.map((t) => _buildToxinCard(t)),
          const SizedBox(height: 20),
        ],

        // ── Longevity Impact ──────────────────────────────────────────────
        if (data.longevityImpact.longevityScore > 0) ...[
          _sectionTitle('LONGEVITY & CELLULAR AGING'),
          const SizedBox(height: 10),
          _LightLongevityCard(longevity: data.longevityImpact),
          const SizedBox(height: 20),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BrandColors.slate400, letterSpacing: 1.5),
    );
  }

  Widget _buildMacrosCard(FoodAnalysis data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandColors.emerald50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _macroItem('Calories', '${data.calories}', 'kcal', LucideIcons.flame, BrandColors.orange500),
          _macroItem('Protein', '${data.macros.protein}', 'g', LucideIcons.beef, BrandColors.red500),
          _macroItem('Carbs', '${data.macros.carbs}', 'g', LucideIcons.wheat, const Color(0xFFD97706)),
          _macroItem('Fat', '${data.macros.fat}', 'g', LucideIcons.droplet, BrandColors.blue500),
        ],
      ),
    );
  }

  Widget _macroItem(String label, String value, String unit, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BrandColors.dark)),
        Text('$label ($unit)', style: const TextStyle(fontSize: 10, color: BrandColors.slate500)),
      ],
    );
  }

  Widget _buildBioImpactCard(BioImpactItem item) {
    final color = _impactColor(item.impact);
    final icon = _impactIcon(item.impact);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                const SizedBox(height: 4),
                Text(item.description, style: const TextStyle(fontSize: 12, color: BrandColors.slate600, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToxinCard(Toxin toxin) {
    Color color;
    switch (toxin.severity.toLowerCase()) {
      case 'high':
        color = BrandColors.red500;
        break;
      case 'medium':
        color = BrandColors.orange500;
        break;
      default:
        color = BrandColors.amber500;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              toxin.severity.toUpperCase(),
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(toxin.name, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(toxin.details, style: const TextStyle(color: BrandColors.slate500, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIGHT-MODE V2 WIDGETS (for saved meal detail sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreRingLight extends StatelessWidget {
  final int score;
  const _ScoreRingLight({required this.score});

  Color _scoreColor() {
    if (score >= 80) return BrandColors.emerald500;
    if (score >= 50) return BrandColors.amber500;
    return BrandColors.red500;
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor();
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 6,
              backgroundColor: BrandColors.slate200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LightCircadianCard extends StatelessWidget {
  final CircadianMatch circadian;
  const _LightCircadianCard({required this.circadian});

  Color _matchColor() {
    switch (circadian.match.toLowerCase()) {
      case 'excellent': return BrandColors.emerald500;
      case 'good': return const Color(0xFF0891B2);
      case 'fair': return BrandColors.amber500;
      default: return BrandColors.red500;
    }
  }

  IconData _timeIcon() {
    switch (circadian.mealTime.toLowerCase()) {
      case 'morning': return LucideIcons.sunrise;
      case 'afternoon': return LucideIcons.sun;
      case 'evening': return LucideIcons.sunset;
      default: return LucideIcons.moon;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _matchColor();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_timeIcon(), color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                '${circadian.mealTime} • Circadian Match',
                style: TextStyle(color: BrandColors.slate600, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${circadian.matchScore}%',
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: circadian.matchScore / 100,
              backgroundColor: BrandColors.slate200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            circadian.reason,
            style: const TextStyle(color: BrandColors.slate600, fontSize: 12, height: 1.4),
          ),
          if (circadian.recommendation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.lightbulb, color: BrandColors.amber500, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    circadian.recommendation,
                    style: TextStyle(color: BrandColors.amber500.withOpacity(0.9), fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LightBioHackCard extends StatelessWidget {
  final BioHack bioHack;
  const _LightBioHackCard({required this.bioHack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BrandColors.emerald500.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.emerald500.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: BrandColors.emerald500.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.zap, color: BrandColors.emerald500, size: 14),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'BIO-HACK THIS MEAL',
                  style: TextStyle(color: BrandColors.emerald500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ),
              if (bioHack.potencyPercent > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BrandColors.emerald500.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${bioHack.potencyPercent}%',
                    style: const TextStyle(color: BrandColors.emerald500, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bioHack.tip,
            style: const TextStyle(color: BrandColors.dark, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            bioHack.mechanism,
            style: const TextStyle(color: BrandColors.slate500, fontSize: 12, height: 1.4),
          ),
          if (bioHack.timing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(LucideIcons.clock, color: BrandColors.slate400, size: 12),
                const SizedBox(width: 6),
                Text(
                  bioHack.timing,
                  style: const TextStyle(color: BrandColors.slate500, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LightHormoneRow extends StatelessWidget {
  final HormoneReading hormone;
  final IconData icon;
  const _LightHormoneRow({required this.hormone, required this.icon});

  Color _impactColor() {
    switch (hormone.impact.toLowerCase()) {
      case 'positive': return BrandColors.emerald500;
      case 'negative': return BrandColors.red500;
      default: return BrandColors.amber500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _impactColor();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrandColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.slate200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(hormone.name, style: const TextStyle(color: BrandColors.dark, fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hormone.response,
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (hormone.detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    hormone.detail,
                    style: const TextStyle(color: BrandColors.slate500, fontSize: 11, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LightMetabolicChip extends StatelessWidget {
  final String label;
  final String value;
  const _LightMetabolicChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: BrandColors.slate400, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: BrandColors.dark, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _LightBioavailabilityCard extends StatelessWidget {
  final Bioavailability bioavailability;
  const _LightBioavailabilityCard({required this.bioavailability});

  @override
  Widget build(BuildContext context) {
    final score = bioavailability.absorptionScore;
    final Color color;
    if (score >= 80) {
      color = BrandColors.emerald500;
    } else if (score >= 50) {
      color = BrandColors.amber500;
    } else {
      color = BrandColors.red500;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score Bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Absorption Score', style: TextStyle(color: BrandColors.slate600, fontSize: 13)),
                  Text('$score%', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: BrandColors.slate200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
        // Tips
        ...bioavailability.tips.map((tip) {
          final tipColor = tip.impact == 'positive' ? BrandColors.emerald500 : BrandColors.red500;
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BrandColors.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BrandColors.slate200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  tip.impact == 'positive' ? LucideIcons.checkCircle : LucideIcons.alertCircle,
                  size: 14,
                  color: tipColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tip.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tipColor)),
                      if (tip.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(tip.description, style: const TextStyle(fontSize: 11, color: BrandColors.slate500, height: 1.4)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _LightUPFCard extends StatelessWidget {
  final UPFAnalysis upf;
  const _LightUPFCard({required this.upf});

  Color _levelColor() {
    switch (upf.score) {
      case <= 2: return BrandColors.emerald500;
      case <= 5: return BrandColors.amber500;
      default: return BrandColors.red500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor();
    final barValue = (upf.score / 10.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.testTube2, color: color, size: 14),
                  const SizedBox(width: 8),
                  const Text('Processing Level', style: TextStyle(color: BrandColors.slate600, fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  upf.level,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barValue,
              backgroundColor: BrandColors.slate200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            upf.verdict,
            style: const TextStyle(color: BrandColors.slate600, fontSize: 12, height: 1.4),
          ),
          if (upf.additives.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: upf.additives.map((additive) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BrandColors.red500.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: BrandColors.red500.withOpacity(0.2)),
                ),
                child: Text(
                  additive,
                  style: const TextStyle(color: BrandColors.red500, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _LightLongevityCard extends StatelessWidget {
  final LongevityImpact longevity;
  const _LightLongevityCard({required this.longevity});

  Color _pathwayColor(String effect) {
    final lower = effect.toLowerCase();
    if (lower.contains('activating') || lower.contains('anti-inflammatory')) {
      return BrandColors.emerald500;
    }
    if (lower.contains('suppressing') || lower.contains('pro-inflammatory')) {
      return BrandColors.red500;
    }
    return BrandColors.amber500;
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = longevity.longevityScore >= 60
        ? BrandColors.emerald500
        : (longevity.longevityScore >= 30 ? BrandColors.amber500 : BrandColors.red500);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.dna, color: BrandColors.slate600, size: 16),
              const SizedBox(width: 8),
              const Text('Longevity Score', style: TextStyle(color: BrandColors.slate600, fontSize: 13)),
              const Spacer(),
              Text(
                '${longevity.longevityScore}/100',
                style: TextStyle(color: scoreColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Pathway chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pathwayChip('Sirtuin', longevity.sirtuinEffect),
              _pathwayChip('mTOR', longevity.mTorEffect),
              _pathwayChip('Inflammation', longevity.inflammationEffect),
            ],
          ),
          if (longevity.longevitySummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              longevity.longevitySummary,
              style: const TextStyle(color: BrandColors.slate600, fontSize: 12, height: 1.4),
            ),
          ],
          if (longevity.longevityCredit != 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  longevity.longevityCredit > 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                  size: 14,
                  color: longevity.longevityCredit > 0 ? BrandColors.emerald500 : BrandColors.red500,
                ),
                const SizedBox(width: 6),
                Text(
                  '${longevity.longevityCredit > 0 ? '+' : ''}${longevity.longevityCredit} Longevity Credit',
                  style: TextStyle(
                    color: longevity.longevityCredit > 0 ? BrandColors.emerald500 : BrandColors.red500,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pathwayChip(String label, String effect) {
    final color = _pathwayColor(effect);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BrandColors.dark)),
          const SizedBox(width: 6),
          Text(effect, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _LightIntelligenceInsight extends StatefulWidget {
  final String insight;
  const _LightIntelligenceInsight({required this.insight});

  @override
  State<_LightIntelligenceInsight> createState() => _LightIntelligenceInsightState();
}

class _LightIntelligenceInsightState extends State<_LightIntelligenceInsight> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.insight.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BrandColors.slate200),
          boxShadow: [
            BoxShadow(
              color: BrandColors.slate400.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'INTELLIGENCE INSIGHT',
                  style: TextStyle(
                    color: BrandColors.slate400,
                    fontSize: 10,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  color: BrandColors.slate300,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Text(
                widget.insight,
                maxLines: _isExpanded ? null : 2,
                overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BrandColors.dark,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
