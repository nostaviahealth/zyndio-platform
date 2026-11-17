import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import './widgets/lens_shared_widgets.dart';
import '../../providers/intelligence_provider.dart';
import '../../providers/lens_provider.dart';
import '../../utils/share_canvas_util.dart';
import '../../providers/usage_limit_provider.dart';
import '../settings/paywall_screen.dart';
import '../../models/food_log.dart';
import '../../data/food_images.dart';
import '../settings/widgets/meal_story_card.dart';
import 'package:flutter/services.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import '../../widgets/voice_log_dialog.dart';
import '../../services/azure_openai_service.dart';

class LensScreen extends ConsumerStatefulWidget {
  const LensScreen({super.key});

  @override
  ConsumerState<LensScreen> createState() => _LensScreenState();
}

class _LensScreenState extends ConsumerState<LensScreen> {
  final ImagePicker _picker = ImagePicker();
  Timer? _loadingTimer;
  final GlobalKey _shareKey = GlobalKey();
  bool _isSharing = false;

  final List<String> _loadingMessages = [
    "Identifying Your Meal...",
    "Scanning Ingredients...",
    "Estimating Macros...",
  ];

  @override
  void initState() {
    super.initState();
    // Pre-warm the Edge Function to prevent cold-start latency on first scan.
    _preWarmEdgeFunction();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  /// Fires a minimal, non-blocking request to warm the Deno runtime.
  /// Best effort: a missing backend (offline, tests) must never break the
  /// screen, so synchronous failures are swallowed too.
  void _preWarmEdgeFunction() {
    try {
      ref.read(azureOpenAIServiceProvider).callAzureAPI([
        {"role": "system", "content": "ping"},
        {"role": "user", "content": "hi"},
      ]).catchError((_) => null);
    } catch (e) {
      debugPrint('Lens pre-warm skipped: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    // Check usage limits
    final canScan = ref.read(canScanLensProvider);
    if (!canScan) {
      PaywallScreen.show(context);
      return;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (pickedFile != null && mounted) {
        // 1. Delegate the entire pipeline to the global provider
        ref.read(lensScanProvider.notifier).startAnalysis(File(pickedFile.path));

        // 2. Immediately pop back to the Home/Main shell
        context.pop();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _showDescribeFoodDialog() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LensInputSheet(
        title: "Describe Meal",
        subtitle: "Tell us what you're eating for an instant biological analysis.",
        hintText: "e.g., '2 eggs, avocado toast and black coffee'",
        buttonLabel: "ANALYZE MEAL",
        controller: controller,
        maxLines: 3,
        onSubmit: () {
          final text = controller.text.trim();
          if (text.isNotEmpty) {
            Navigator.pop(context); // Close sheet
            ref.read(lensScanProvider.notifier).reset();
            ref.read(lensScanProvider.notifier).startTextAnalysis(text);
            context.pop(); // Close LensScreen
          }
        },
      ),
    );
  }

  void _showVoiceLogDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VoiceLogDialog(
        onResult: (text) {
          Navigator.pop(context);
          ref.read(lensScanProvider.notifier).reset();
          ref.read(lensScanProvider.notifier).startTextAnalysis(text);
          context.pop(); // Close LensScreen
        },
      ),
    );
  }

  void _reset() {
    ref.read(lensScanProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the global scan state — this is the ONLY state source now
    final scanState = ref.watch(lensScanProvider);
    final c = context.zc;

    return Stack(
      children: [
        ZyndioDetailScaffold(
          title: scanState.hasAnalysis ? "Meal Analysis" : "Food Intelligence",
          onBack: () => context.pop(),
          trailing: scanState.hasAnalysis
              ? ZyndioCircleButton(
                  icon: LucideIcons.share2,
                  label: 'Share',
                  onTap: _shareResult,
                )
              : null,
          body: Stack(
            children: [
              // ── Hidden Component for Sharing (Instagram Story 9:16) ──────
              if (scanState.hasAnalysis)
                Positioned(
                  left: -5000, // Absolute off-screen positioning
                  child: RepaintBoundary(
                    key: _shareKey,
                    child: SizedBox(
                      width: 450, // Logical width that captures well for Story ratio
                      child: MealStoryCard(
                        log: FoodLog(
                          id: 'temp',
                          userId: 'temp',
                          imagePath: scanState.uploadedFilePath,
                          analysis: scanState.analysis!.toJson(),
                          loggedAt: scanState.scanTime ?? DateTime.now(),
                        ),
                        data: scanState.analysis!,
                        imageUrl: ref.watch(foodImageUrlProvider(scanState.uploadedFilePath ?? '')).value ?? '',
                      ),
                    ),
                  ),
                ),

              // Main content
              Positioned.fill(child: _buildBody(scanState)),
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

  Widget _buildBody(LensScanState scanState) {
    if (scanState.phase == LensScanPhase.idle) return _buildCameraView();
    if (scanState.isAnalyzing) return _buildLoadingView(scanState);
    if (scanState.hasFailed) return _buildErrorView(scanState);
    if (scanState.hasAnalysis) return _buildResultsView(scanState);
    return const SizedBox.shrink();
  }

  /// Centres [child] when it fits and scrolls it when it does not (small
  /// phones, large accessibility text).
  Widget _centeredScroll(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 36).clamp(0.0, double.infinity),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  /// The captured meal photo in a rounded frame, when there is one.
  Widget _photo(File image, {double? height}) {
    final c = context.zc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Image.file(
          image,
          fit: BoxFit.cover,
          errorBuilder: (ctx, e, s) => Container(
            color: c.bgSunken,
            alignment: Alignment.center,
            child: Icon(LucideIcons.image, color: c.textTertiary, size: 32),
          ),
        ),
      ),
    );
  }

  // ─── Camera / Landing View ────────────────────────────────────────────────

  Widget _buildCameraView() {
    final c = context.zc;
    return _centeredScroll(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ZyndioIconTile(glyph: ZyndioGlyph.bowl, tint: ZyndioTint.green, size: 88),
          const SizedBox(height: 24),
          Text(
            "Log Your Meal",
            textAlign: TextAlign.center,
            style: ZyndioType.title1.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            "Get an instant deep-science breakdown\nof everything on your plate",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              color: c.textSecondary,
              fontSize: 15,
              height: 22 / 15,
            ),
          ),
          const SizedBox(height: 18),

          // Feature pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _featurePill(LucideIcons.dna, "Longevity"),
              _featurePill(LucideIcons.activity, "Hormones"),
              _featurePill(LucideIcons.zap, "Bio-Hacks"),
              _featurePill(LucideIcons.moon, "Circadian"),
            ],
          ),

          const SizedBox(height: 40),

          // Action Buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildPickButton(
                  icon: LucideIcons.image,
                  label: "Gallery",
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 12),

              // Main camera button
              GestureDetector(
                onTap: () => _pickImage(ImageSource.camera),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: ZyndioGradients.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.bgSurface, width: 5),
                    boxShadow: [
                      BoxShadow(
                        color: ZyndioTint.violet.colors.last.withValues(alpha: 0.30),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(LucideIcons.camera, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: _buildPickButton(
                  icon: LucideIcons.mic,
                  label: "Voice",
                  onTap: _showVoiceLogDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ZyndioOutlineButton(
            icon: LucideIcons.edit3,
            label: "Describe Food",
            onTap: _showDescribeFoodDialog,
          ),
        ],
      ),
    );
  }

  Widget _featurePill(IconData icon, String label) {
    return ZyndioPill(label, tone: ZyndioPillTone.brand, icon: icon);
  }

  Widget _buildPickButton({required IconData icon, required String label, required VoidCallback onTap}) {
    final c = context.zc;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: zyndioCard(context, radius: 28),
            child: Icon(icon, color: c.textPrimary, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              color: c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Loading View ─────────────────────────────────────────────────────────

  Widget _buildLoadingView(LensScanState scanState) {
    final c = context.zc;
    return _centeredScroll(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (scanState.image != null) ...[
            _photo(scanState.image!, height: 180),
            const SizedBox(height: 28),
          ],
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.brandSubtle,
            ),
            child: Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: c.brandPrimary,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _loadingMessages[scanState.loadingMessageIndex],
            textAlign: TextAlign.center,
            style: ZyndioType.title3.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            scanState.loadingMessageIndex < 2
                ? "Using multi-spectral computer vision..."
                : "Cross-referencing biomarker datasets...",
            textAlign: TextAlign.center,
            style: ZyndioType.subhead.copyWith(color: c.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─── Error View ───────────────────────────────────────────────────────────

  Widget _buildErrorView(LensScanState scanState) {
    final c = context.zc;
    return _centeredScroll(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.statusCriticalSubtle,
            ),
            child: Center(
              child: Icon(LucideIcons.alertTriangle, color: c.statusCritical, size: 36),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            scanState.errorMessage ?? 'Analysis failed.',
            textAlign: TextAlign.center,
            style: ZyndioType.callout.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 24),
          ZyndioGradientButton(
            label: "Retry",
            trailingArrow: false,
            onTap: () => ref.read(lensScanProvider.notifier).retry(),
          ),
          const SizedBox(height: 10),
          ZyndioOutlineButton(label: "New Scan", onTap: _reset),
        ],
      ),
    );
  }

  // ─── Results View ─────────────────────────────────────────────────────────

  Widget _buildResultsView(LensScanState scanState) {
    final c = context.zc;
    final data = scanState.analysis!;
    final wearable = ref.watch(wearableStateProvider).value;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (scanState.image != null) ...[
            _photo(scanState.image!, height: 200),
            const SizedBox(height: 16),
          ],

          // ── Hero: Score + Food Name ──────────────────────────────────────
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
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _showCorrectionDialog(context, ref),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.brandSubtle,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.edit3, size: 14, color: c.brandOnSubtle),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Not what you're eating?",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: ZyndioType.family,
                              color: c.brandOnSubtle,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "${data.calories} kcal",
                  textAlign: TextAlign.center,
                  style: ZyndioType.subhead.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Intelligence Insight: Personalised Analysis ──────────────────
          LensIntelligenceInsight(insight: data.intelligenceInsight),
          if (data.intelligenceInsight.isNotEmpty) const SizedBox(height: 24) else const SizedBox(height: 8),

          // ── Wearable Bio-Data Banner ─────────────────────────────────────
          if (wearable != null && (wearable.recoveryScore > 0 || wearable.stressScore > 0 || wearable.sleepHours > 0)) ...[
            LensBioDataBanner(
              recoveryScore: wearable.recoveryScore,
              stressScore: wearable.stressScore,
              sleepHours: wearable.sleepHours,
              hrv: wearable.hrv,
            ),
            const SizedBox(height: 24),
          ],

          // ── Macros ───────────────────────────────────────────────────────
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

          // ── Deep Analysis Loading Banner ───────────────────────────────
          if (scanState.isDeepLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: c.brandSubtle,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.brandOnSubtle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Deep biological analysis loading...",
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        color: c.brandOnSubtle,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Circadian Match ──────────────────────────────────────────────
          if (data.circadianMatch.match != 'Unknown') ...[
            LensSectionTitle(title: "CIRCADIAN ALIGNMENT", icon: LucideIcons.clock),
            const SizedBox(height: 10),
            LensCircadianCard(circadian: data.circadianMatch),
            const SizedBox(height: 24),
          ],

          // ── Bio-Hack Tip ─────────────────────────────────────────────────
          if (data.bioHack.tip.isNotEmpty) ...[
            LensSectionTitle(title: "OPTIMIZATION TIP", icon: LucideIcons.zap),
            const SizedBox(height: 10),
            LensBioHackCard(bioHack: data.bioHack),
            const SizedBox(height: 24),
          ],

          // ── Hormonal Impact ──────────────────────────────────────────────
          if (data.hormonalImpact.insulin.response != 'Unknown') ...[
            LensSectionTitle(title: "HORMONAL IMPACT", icon: LucideIcons.activity),
            const SizedBox(height: 10),
            LensHormonalCard(hormonal: data.hormonalImpact),
            const SizedBox(height: 24),
          ],

          // ── Predictive Metabolic Animation ───────────────────────────────
          LensSectionTitle(title: "METABOLIC SIMULATION", icon: LucideIcons.trendingUp),
          const SizedBox(height: 10),
          ZyndioCard(
            padding: const EdgeInsets.all(16),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LensMetabolicCurveWidget(
                  energyCurve: data.metabolicImpact.energyCurve,
                ),
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

          // ── Bioavailability ──────────────────────────────────────────────
          if (data.bioavailability.absorptionScore > 0 || data.bioavailability.tips.isNotEmpty) ...[
            LensSectionTitle(title: "ABSORPTION & PREP", icon: LucideIcons.microscope),
            const SizedBox(height: 10),
            LensBioavailabilityCard(bioavailability: data.bioavailability),
            const SizedBox(height: 24),
          ],

          // ── UPF Processing ───────────────────────────────────────────────
          if (data.upfAnalysis.level != 'Unknown') ...[
            LensSectionTitle(title: "PROCESSING SCORE", icon: LucideIcons.testTube2),
            const SizedBox(height: 10),
            LensUPFCard(upf: data.upfAnalysis),
            const SizedBox(height: 24),
          ],

          // ── Bio Impact ───────────────────────────────────────────────────
          LensSectionTitle(title: "BIO-IMPACT ANALYSIS", icon: LucideIcons.heartPulse),
          const SizedBox(height: 10),
          ...data.bioImpact.map((item) => LensBioImpactCard(item: item)),
          const SizedBox(height: 24),

          // ── Toxin Radar ──────────────────────────────────────────────────
          if (data.toxins.isNotEmpty) ...[
            LensToxinRadarHeader(count: data.toxins.length),
            const SizedBox(height: 8),
            ...data.toxins.map((t) => LensToxinItem(toxin: t)),
            const SizedBox(height: 24),
          ],

          // ── Longevity Impact ─────────────────────────────────────────────
          if (data.longevityImpact.longevityScore > 0) ...[
            LensSectionTitle(title: "LONGEVITY & CELLULAR AGING", icon: LucideIcons.dna),
            const SizedBox(height: 10),
            LensLongevityCard(longevity: data.longevityImpact),
            const SizedBox(height: 24),
          ],

          // ── Auto-Saved Indicator ─────────────────────────────────────────
          if (scanState.isComplete)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: c.statusSuccessSubtle,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.checkCircle, color: c.statusSuccess, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Saved to Food Log",
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.statusSuccess,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (scanState.isDeepLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: c.bgSunken,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Saving to Food Log...",
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
          // New Scan Button at the bottom
          if (scanState.hasAnalysis)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ZyndioOutlineButton(
                  icon: LucideIcons.camera,
                  label: "Start New Scan",
                  onTap: _reset,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: scanState.isDeleting ? null : () => _showDeleteConfirmation(context, ref),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                    icon: scanState.isDeleting
                      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.statusCritical))
                      : Icon(LucideIcons.trash2, color: c.statusCritical, size: 16),
                    label: Text(
                      scanState.isDeleting ? "Deleting..." : "Remove from Log",
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        color: c.statusCritical,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Text(
            'Powered by Food Intelligence\nFood photos are processed securely and not stored by AI providers.',
            textAlign: TextAlign.center,
            style: ZyndioType.footnote.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    final c = context.zc;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(lensScanProvider.notifier).deleteCurrentMeal();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Meal removed from log", style: TextStyle(color: c.bgSurface)),
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

  Future<void> _shareResult() async {
    final scanState = ref.read(lensScanProvider);
    if (!scanState.hasAnalysis) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSharing = true);

    try {
      // Allow the off-screen RepaintBoundary to stabilize
      await Future.delayed(const Duration(milliseconds: 150));

      if (!mounted) return;

      await ShareCanvasUtil.captureWithKeyAndShare(
        context: context,
        key: _shareKey,
        label: scanState.analysis!.foodName,
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _showCorrectionDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LensInputSheet(
        title: "Correct Food",
        subtitle: "Tell us what's actually in the photo for a more accurate analysis.",
        hintText: "e.g., 'Quinoa salad with grilled chicken'",
        buttonLabel: "RE-ANALYZE MEAL",
        controller: controller,
        maxLines: 1,
        onSubmit: () {
          final correction = controller.text.trim();
          if (correction.isNotEmpty) {
            Navigator.pop(context);
            ref.read(lensScanProvider.notifier).rescanWithCorrection(correction);
          }
        },
      ),
    );
  }
}

/// Bottom sheet with a title, a free-text field and one primary action
/// (Describe Meal, Correct Food). Scrolls above the keyboard on small phones.
class _LensInputSheet extends StatelessWidget {
  const _LensInputSheet({
    required this.title,
    required this.subtitle,
    required this.hintText,
    required this.buttonLabel,
    required this.controller,
    required this.maxLines,
    required this.onSubmit,
  });

  final String title;
  final String subtitle;
  final String hintText;
  final String buttonLabel;
  final TextEditingController controller;
  final int maxLines;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: dark ? Border.all(color: c.borderSubtle) : null,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 12,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                title,
                style: ZyndioType.title2.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: ZyndioType.subhead.copyWith(color: c.textSecondary, height: 22 / 15),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                autofocus: true,
                style: ZyndioType.callout.copyWith(color: c.textPrimary),
                decoration: InputDecoration(hintText: hintText),
                maxLines: maxLines,
              ),
              const SizedBox(height: 24),
              ZyndioGradientButton(
                label: buttonLabel,
                trailingArrow: false,
                onTap: onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
