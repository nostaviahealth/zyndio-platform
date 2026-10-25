import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';
import '../../../models/food_analysis.dart';
import 'lens_shared_widgets.dart';

/// A standalone, plug-and-play UI Dashboard for Food Intelligence.
/// Clients can embed this widget anywhere in their app.
class BrandFoodAnalysisDashboard extends StatelessWidget {
  final FoodAnalysis analysis;
  final String? imageUrl;
  final VoidCallback? onBack;
  final VoidCallback? onShare;

  const BrandFoodAnalysisDashboard({
    super.key,
    required this.analysis,
    this.imageUrl,
    this.onBack,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Background Image + Blur
          if (imageUrl != null && imageUrl!.isNotEmpty) ...[
            Positioned.fill(
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.black),
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.85)),
            ),
          ],
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 22),
              ),
            )
          else
            const SizedBox(width: 42),

          const Text(
            "Meal Analysis",
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          
          if (onShare != null)
            GestureDetector(
              onTap: onShare,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BrandColors.emerald500.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.share2, color: BrandColors.emerald500, size: 20),
              ),
            )
          else
            const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              LensScoreRing(score: analysis.score),
              const SizedBox(height: 6),
              const Text(
                "ZYNDIO SCORE",
                style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                analysis.foodName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                "${analysis.calories} kcal",
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        LensIntelligenceInsight(insight: analysis.intelligenceInsight),
        const SizedBox(height: 24),

        LensSectionTitle(title: "MACRONUTRIENTS", icon: LucideIcons.barChart2),
        const SizedBox(height: 10),
        LensMacroBar(label: "Protein", amount: analysis.macros.protein, color: BrandColors.blue500),
        LensMacroBar(label: "Carbs", amount: analysis.macros.carbs, color: BrandColors.orange500),
        LensMacroBar(label: "Fat", amount: analysis.macros.fat, color: BrandColors.emerald500),
        const SizedBox(height: 20),

        if (analysis.circadianMatch.match != 'Unknown') ...[
          LensSectionTitle(title: "CIRCADIAN ALIGNMENT", icon: LucideIcons.clock),
          const SizedBox(height: 10),
          LensCircadianCard(circadian: analysis.circadianMatch),
          const SizedBox(height: 20),
        ],

        if (analysis.bioHack.tip.isNotEmpty) ...[
          LensSectionTitle(title: "OPTIMIZATION TIP", icon: LucideIcons.zap),
          const SizedBox(height: 10),
          LensBioHackCard(bioHack: analysis.bioHack),
          const SizedBox(height: 20),
        ],

        if (analysis.hormonalImpact.insulin.response != 'Unknown') ...[
          LensSectionTitle(title: "HORMONAL IMPACT", icon: LucideIcons.activity),
          const SizedBox(height: 10),
          LensHormonalCard(hormonal: analysis.hormonalImpact),
          const SizedBox(height: 20),
        ],

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
              LensMetabolicCurveWidget(energyCurve: analysis.metabolicImpact.energyCurve),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: LensMetabolicCard(label: "Digestion Time", value: analysis.metabolicImpact.digestionTime)),
                  const SizedBox(width: 10),
                  Expanded(child: LensMetabolicCard(label: "Energy Curve", value: analysis.metabolicImpact.energyCurve)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (analysis.bioavailability.absorptionScore > 0 || analysis.bioavailability.tips.isNotEmpty) ...[
          LensSectionTitle(title: "ABSORPTION & PREP", icon: LucideIcons.microscope),
          const SizedBox(height: 10),
          LensBioavailabilityCard(bioavailability: analysis.bioavailability),
          const SizedBox(height: 20),
        ],

        if (analysis.upfAnalysis.level != 'Unknown') ...[
          LensSectionTitle(title: "PROCESSING SCORE", icon: LucideIcons.testTube2),
          const SizedBox(height: 10),
          LensUPFCard(upf: analysis.upfAnalysis),
          const SizedBox(height: 20),
        ],

        LensSectionTitle(title: "BIO-IMPACT ANALYSIS", icon: LucideIcons.heartPulse),
        const SizedBox(height: 10),
        ...analysis.bioImpact.map((item) => LensBioImpactCard(item: item)),
        const SizedBox(height: 20),

        if (analysis.toxins.isNotEmpty) ...[
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
                  "${analysis.toxins.length} threats",
                  style: const TextStyle(color: BrandColors.red500, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...analysis.toxins.map((t) => LensToxinItem(toxin: t)),
          const SizedBox(height: 20),
        ],

        if (analysis.longevityImpact.longevityScore > 0) ...[
          LensSectionTitle(title: "LONGEVITY & CELLULAR AGING", icon: LucideIcons.dna),
          const SizedBox(height: 10),
          LensLongevityCard(longevity: analysis.longevityImpact),
          const SizedBox(height: 20),
        ],

        const SizedBox(height: 24),
        Center(
          child: Text(
            'Powered by Zyndio Intelligence',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.3),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
