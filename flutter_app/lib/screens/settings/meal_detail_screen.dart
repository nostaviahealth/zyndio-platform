import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../config/supabase_config.dart';
import '../../models/food_log.dart';
import '../../models/food_analysis.dart';
import '../../utils/share_canvas_util.dart';
import '../../providers/lens_provider.dart';
import '../lens/widgets/lens_shared_widgets.dart';
import './widgets/meal_story_card.dart';

/// Full-screen dark-themed detail view for a saved meal — identical to Lens results.
class MealDetailScreen extends ConsumerStatefulWidget {
  final FoodLog log;

  const MealDetailScreen({super.key, required this.log});

  @override
  ConsumerState<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends ConsumerState<MealDetailScreen> {
  bool _isSharing = false;
  bool _isDeleting = false;
  final GlobalKey _shareKey = GlobalKey();

  String _getPublicUrl(String path) {
    if (path.startsWith('http')) return path;
    final client = SupabaseConfig.client;
    if (client == null) return '';
    return client.storage.from('food-images').getPublicUrl(path);
  }

  Future<void> _shareAsStory(FoodAnalysis data) async {
    HapticFeedback.mediumImpact();
    setState(() => _isSharing = true);

    try {
      // Allow the off-screen RepaintBoundary to stabilize
      await Future.delayed(const Duration(milliseconds: 150));
      
      if (!mounted) return;

      await ShareCanvasUtil.captureWithKeyAndShare(
        context: context,
        key: _shareKey,
        label: data.foodName,
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Meal?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "This will permanently remove this meal and its biological analysis from your log.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // close dialog
              
              setState(() => _isDeleting = true);
              HapticFeedback.heavyImpact();

              final success = await ref.read(lensScanProvider.notifier).deleteMealLog(
                id: widget.log.id,
                imagePath: widget.log.imagePath,
              );
              
              if (!mounted) return;
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Meal removed from log"), backgroundColor: BrandColors.red500),
                );
                context.pop(); // Go back to history
              } else {
                setState(() => _isDeleting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to remove meal"), backgroundColor: BrandColors.red500),
                );
              }
            },
            child: const Text("Delete", style: TextStyle(color: BrandColors.red500, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = FoodAnalysis.fromJson(widget.log.analysis);
    final hasImage = widget.log.imagePath != null && widget.log.imagePath!.isNotEmpty;
    final imageUrl = hasImage ? _getPublicUrl(widget.log.imagePath!) : '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Hidden Component for Sharing (Instagram Story 9:16) ──────────
          // We render this off-screen so ShareCanvasUtil can capture it.
          Positioned(
            left: -5000, // Absolute off-screen positioning
            child: RepaintBoundary(
              key: _shareKey,
              child: SizedBox(
                width: 450, // Logical width that captures well for Story ratio
                child: MealStoryCard(
                  log: widget.log,
                  data: data,
                  imageUrl: imageUrl,
                ),
              ),
            ),
          ),

          // ── Background Image + Blur ──────────────────────────────
          if (hasImage) ...[
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.black),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                ),
              ),
            ),
          ],

          // ── Scrollable Content ───────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, data),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: _buildContent(data),
                  ),
                ),
              ],
            ),
          ),

          // ── Sharing Overlay ──────────────────────────────────────
          if (_isSharing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: BrandColors.emerald500),
                      const SizedBox(height: 20),
                      Text(
                        'Generating your story...',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FoodAnalysis data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 22),
            ),
          ),
          const Text(
            "Meal Analysis",
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          // Share Button
          GestureDetector(
            onTap: () => _shareAsStory(data),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BrandColors.emerald500.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.share2, color: BrandColors.emerald500, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(FoodAnalysis data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero: Score + Food Name ──────────────────────────────────
        Center(
          child: Column(
            children: [
              LensScoreRing(score: data.score),
              const SizedBox(height: 6),
              const Text(
                "ZYNDIO SCORE",
                style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                data.foodName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                "${data.calories} kcal",
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Intelligence Insight: Personalised Analysis ──────────────────
        LensIntelligenceInsight(insight: data.intelligenceInsight),
        const SizedBox(height: 24),

        // ── Macros ───────────────────────────────────────────────────
        LensSectionTitle(title: "MACRONUTRIENTS", icon: LucideIcons.barChart2),
        const SizedBox(height: 10),
        LensMacroBar(label: "Protein", amount: data.macros.protein, color: BrandColors.blue500),
        LensMacroBar(label: "Carbs", amount: data.macros.carbs, color: BrandColors.orange500),
        LensMacroBar(label: "Fat", amount: data.macros.fat, color: BrandColors.emerald500),
        const SizedBox(height: 20),

        // ── Circadian Match ──────────────────────────────────────────
        if (data.circadianMatch.match != 'Unknown') ...[
          LensSectionTitle(title: "CIRCADIAN ALIGNMENT", icon: LucideIcons.clock),
          const SizedBox(height: 10),
          LensCircadianCard(circadian: data.circadianMatch),
          const SizedBox(height: 20),
        ],

        // ── Bio-Hack Tip ─────────────────────────────────────────────
        if (data.bioHack.tip.isNotEmpty) ...[
          LensSectionTitle(title: "OPTIMIZATION TIP", icon: LucideIcons.zap),
          const SizedBox(height: 10),
          LensBioHackCard(bioHack: data.bioHack),
          const SizedBox(height: 20),
        ],

        // ── Hormonal Impact ──────────────────────────────────────────
        if (data.hormonalImpact.insulin.response != 'Unknown') ...[
          LensSectionTitle(title: "HORMONAL IMPACT", icon: LucideIcons.activity),
          const SizedBox(height: 10),
          LensHormonalCard(hormonal: data.hormonalImpact),
          const SizedBox(height: 20),
        ],

        // ── Metabolic Simulation ─────────────────────────────────────
        LensSectionTitle(title: "METABOLIC SIMULATION", icon: LucideIcons.trendingUp),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LensMetabolicCurveWidget(energyCurve: data.metabolicImpact.energyCurve),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: LensMetabolicCard(label: "Digestion Time", value: data.metabolicImpact.digestionTime)),
                  const SizedBox(width: 10),
                  Expanded(child: LensMetabolicCard(label: "Energy Curve", value: data.metabolicImpact.energyCurve)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Bioavailability ──────────────────────────────────────────
        if (data.bioavailability.absorptionScore > 0 || data.bioavailability.tips.isNotEmpty) ...[
          LensSectionTitle(title: "ABSORPTION & PREP", icon: LucideIcons.microscope),
          const SizedBox(height: 10),
          LensBioavailabilityCard(bioavailability: data.bioavailability),
          const SizedBox(height: 20),
        ],

        // ── UPF Processing ───────────────────────────────────────────
        if (data.upfAnalysis.level != 'Unknown') ...[
          LensSectionTitle(title: "PROCESSING SCORE", icon: LucideIcons.testTube2),
          const SizedBox(height: 10),
          LensUPFCard(upf: data.upfAnalysis),
          const SizedBox(height: 20),
        ],

        // ── Bio Impact ───────────────────────────────────────────────
        LensSectionTitle(title: "BIO-IMPACT ANALYSIS", icon: LucideIcons.heartPulse),
        const SizedBox(height: 10),
        ...data.bioImpact.map((item) => LensBioImpactCard(item: item)),
        const SizedBox(height: 20),

        // ── Toxin Radar ──────────────────────────────────────────────
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
                  "TOXIN RADAR",
                  style: TextStyle(
                    color: BrandColors.red500,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  "${data.toxins.length} threats",
                  style: const TextStyle(color: BrandColors.red500, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...data.toxins.map((t) => LensToxinItem(toxin: t)),
          const SizedBox(height: 20),
        ],

        // ── Longevity Impact ─────────────────────────────────────────
        if (data.longevityImpact.longevityScore > 0) ...[
          LensSectionTitle(title: "LONGEVITY & CELLULAR AGING", icon: LucideIcons.dna),
          const SizedBox(height: 10),
          LensLongevityCard(longevity: data.longevityImpact),
          const SizedBox(height: 20),
        ],

        // ── Remove from Log Button ───────────────────────────────────
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: _isDeleting ? null : () => _showDeleteConfirmation(context),
            icon: _isDeleting 
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.red500))
              : const Icon(LucideIcons.trash2, color: BrandColors.red500, size: 16),
            label: Text(
              _isDeleting ? "Deleting..." : "Remove from Log",
              style: const TextStyle(color: BrandColors.red500, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // ── Footer ───────────────────────────────────────────────────
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Powered by Zyndio Lens\nFood photos are processed securely and not stored by AI providers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.3),
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
