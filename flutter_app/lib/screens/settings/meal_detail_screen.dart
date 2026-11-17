import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../data/food_images.dart';
import '../../models/food_log.dart';
import '../../models/food_analysis.dart';
import '../../utils/share_canvas_util.dart';
import '../../providers/lens_provider.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import '../lens/widgets/lens_shared_widgets.dart';
import './widgets/meal_story_card.dart';

/// Detail view for a saved meal (opened from Food log) — the same analysis
/// sections as Lens results, on the shared Zyndio detail scaffold.
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
    final c = context.zc;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.bgSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Delete Meal?", style: ZyndioType.title3.copyWith(color: c.textPrimary)),
        content: Text(
          "This will permanently remove this meal and its biological analysis from your log.",
          style: ZyndioType.subhead.copyWith(color: c.textSecondary, height: 22 / 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Cancel", style: TextStyle(color: c.textSecondary)),
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
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text("Meal removed from log", style: TextStyle(color: c.bgSurface)),
                    backgroundColor: c.statusCritical,
                  ),
                );
                this.context.pop(); // Go back to history
              } else {
                setState(() => _isDeleting = false);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text("Failed to remove meal", style: TextStyle(color: c.bgSurface)),
                    backgroundColor: c.statusCritical,
                  ),
                );
              }
            },
            child: Text(
              "Delete",
              style: TextStyle(color: c.statusCritical, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final data = FoodAnalysis.fromJson(widget.log.analysis);
    final hasImage = widget.log.imagePath != null && widget.log.imagePath!.isNotEmpty;
    final imageUrl = hasImage ? ref.watch(foodImageUrlProvider(widget.log.imagePath!)).value ?? '' : '';

    return Stack(
      children: [
        ZyndioDetailScaffold(
          title: "Meal Analysis",
          onBack: () => context.pop(),
          trailing: ZyndioCircleButton(
            icon: LucideIcons.share2,
            label: 'Share',
            onTap: () => _shareAsStory(data),
          ),
          body: Stack(
            children: [
              // ── Hidden Component for Sharing (Instagram Story 9:16) ──────
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

              // ── Scrollable Content ─────────────────────────────────
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  child: _buildContent(context, data, imageUrl),
                ),
              ),
            ],
          ),
        ),

        // ── Sharing Overlay ──────────────────────────────────────
        if (_isSharing)
          Positioned.fill(
            child: Material(
              color: c.bgCanvas.withValues(alpha: 0.85),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ZyndioCard(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: c.brandPrimary),
                        const SizedBox(height: 20),
                        Text(
                          'Generating your story...',
                          textAlign: TextAlign.center,
                          style: ZyndioType.headline.copyWith(color: c.textPrimary),
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
  }

  Widget _photo(BuildContext context, String imageUrl) {
    final c = context.zc;
    Widget placeholder() => Container(
          color: c.bgSunken,
          alignment: Alignment.center,
          child: Icon(LucideIcons.image, color: c.textTertiary, size: 32),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: imageUrl.isEmpty
            ? placeholder()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (ctx, e, s) => placeholder(),
              ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, FoodAnalysis data, String imageUrl) {
    final c = context.zc;
    final hasImage = widget.log.imagePath != null && widget.log.imagePath!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasImage) ...[
          _photo(context, imageUrl),
          const SizedBox(height: 16),
        ],

        // ── Hero: Score + Food Name ──────────────────────────────────
        ZyndioCard(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          child: Column(
            children: [
              LensScoreRing(score: data.score),
              const SizedBox(height: 8),
              Text(
                "ZYNDIO SCORE",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  color: c.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                data.foodName,
                style: ZyndioType.title2.copyWith(color: c.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                "${data.calories} kcal",
                textAlign: TextAlign.center,
                style: ZyndioType.subhead.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Intelligence Insight: Personalised Analysis ──────────────────
        LensIntelligenceInsight(insight: data.intelligenceInsight),
        if (data.intelligenceInsight.isNotEmpty) const SizedBox(height: 24) else const SizedBox(height: 8),

        // ── Macros ───────────────────────────────────────────────────
        LensSectionTitle(title: "MACRONUTRIENTS", icon: LucideIcons.barChart2),
        const SizedBox(height: 10),
        ZyndioCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          child: Column(
            children: [
              LensMacroBar(label: "Protein", amount: data.macros.protein, color: ZyndioTint.blue.colors.last),
              LensMacroBar(label: "Carbs", amount: data.macros.carbs, color: ZyndioTint.amber.colors.last),
              LensMacroBar(label: "Fat", amount: data.macros.fat, color: ZyndioTint.green.colors.last),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Circadian Match ──────────────────────────────────────────
        if (data.circadianMatch.match != 'Unknown') ...[
          LensSectionTitle(title: "CIRCADIAN ALIGNMENT", icon: LucideIcons.clock),
          const SizedBox(height: 10),
          LensCircadianCard(circadian: data.circadianMatch),
          const SizedBox(height: 24),
        ],

        // ── Bio-Hack Tip ─────────────────────────────────────────────
        if (data.bioHack.tip.isNotEmpty) ...[
          LensSectionTitle(title: "OPTIMIZATION TIP", icon: LucideIcons.zap),
          const SizedBox(height: 10),
          LensBioHackCard(bioHack: data.bioHack),
          const SizedBox(height: 24),
        ],

        // ── Hormonal Impact ──────────────────────────────────────────
        if (data.hormonalImpact.insulin.response != 'Unknown') ...[
          LensSectionTitle(title: "HORMONAL IMPACT", icon: LucideIcons.activity),
          const SizedBox(height: 10),
          LensHormonalCard(hormonal: data.hormonalImpact),
          const SizedBox(height: 24),
        ],

        // ── Metabolic Simulation ─────────────────────────────────────
        LensSectionTitle(title: "METABOLIC SIMULATION", icon: LucideIcons.trendingUp),
        const SizedBox(height: 10),
        ZyndioCard(
          padding: const EdgeInsets.all(16),
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LensMetabolicCurveWidget(energyCurve: data.metabolicImpact.energyCurve),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: LensMetabolicCard(label: "Digestion Time", value: data.metabolicImpact.digestionTime)),
                  const SizedBox(width: 10),
                  Expanded(child: LensMetabolicCard(label: "Energy Curve", value: data.metabolicImpact.energyCurve)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Bioavailability ──────────────────────────────────────────
        if (data.bioavailability.absorptionScore > 0 || data.bioavailability.tips.isNotEmpty) ...[
          LensSectionTitle(title: "ABSORPTION & PREP", icon: LucideIcons.microscope),
          const SizedBox(height: 10),
          LensBioavailabilityCard(bioavailability: data.bioavailability),
          const SizedBox(height: 24),
        ],

        // ── UPF Processing ───────────────────────────────────────────
        if (data.upfAnalysis.level != 'Unknown') ...[
          LensSectionTitle(title: "PROCESSING SCORE", icon: LucideIcons.testTube2),
          const SizedBox(height: 10),
          LensUPFCard(upf: data.upfAnalysis),
          const SizedBox(height: 24),
        ],

        // ── Bio Impact ───────────────────────────────────────────────
        LensSectionTitle(title: "BIO-IMPACT ANALYSIS", icon: LucideIcons.heartPulse),
        const SizedBox(height: 10),
        ...data.bioImpact.map((item) => LensBioImpactCard(item: item)),
        const SizedBox(height: 24),

        // ── Toxin Radar ──────────────────────────────────────────────
        if (data.toxins.isNotEmpty) ...[
          LensToxinRadarHeader(count: data.toxins.length),
          const SizedBox(height: 8),
          ...data.toxins.map((t) => LensToxinItem(toxin: t)),
          const SizedBox(height: 24),
        ],

        // ── Longevity Impact ─────────────────────────────────────────
        if (data.longevityImpact.longevityScore > 0) ...[
          LensSectionTitle(title: "LONGEVITY & CELLULAR AGING", icon: LucideIcons.dna),
          const SizedBox(height: 10),
          LensLongevityCard(longevity: data.longevityImpact),
          const SizedBox(height: 24),
        ],

        // ── Remove from Log Button ───────────────────────────────────
        Center(
          child: TextButton.icon(
            onPressed: _isDeleting ? null : () => _showDeleteConfirmation(context),
            style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: _isDeleting
                ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.statusCritical))
                : Icon(LucideIcons.trash2, color: c.statusCritical, size: 16),
            label: Text(
              _isDeleting ? "Deleting..." : "Remove from Log",
              style: TextStyle(
                fontFamily: ZyndioType.family,
                color: c.statusCritical,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // ── Footer ───────────────────────────────────────────────────
        const SizedBox(height: 16),
        Text(
          'Powered by Zyndio Lens\nFood photos are processed securely and not stored by AI providers.',
          textAlign: TextAlign.center,
          style: ZyndioType.footnote.copyWith(color: c.textTertiary),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
