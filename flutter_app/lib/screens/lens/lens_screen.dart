import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
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
  void _preWarmEdgeFunction() {
    ref.read(azureOpenAIServiceProvider).callAzureAPI([
      {"role": "system", "content": "ping"},
      {"role": "user", "content": "hi"},
    ]).catchError((_) => null);
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
              "Describe Meal",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "Tell us what you're eating for an instant biological analysis.",
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: "e.g., '2 eggs, avocado toast and black coffee'",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: BrandColors.emerald500, width: 1.5),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    Navigator.pop(context); // Close sheet
                    ref.read(lensScanProvider.notifier).reset();
                    ref.read(lensScanProvider.notifier).startTextAnalysis(text);
                    context.pop(); // Close LensScreen
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.emerald500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  "ANALYZE MEAL",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
              ),
            ),
          ],
        ),
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

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      body: Stack(
        children: [
          // ── Hidden Component for Sharing (Instagram Story 9:16) ──────────
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

          // Background: food photo or transparent
          Positioned.fill(
            child: scanState.image != null
                ? Image.file(scanState.image!, fit: BoxFit.cover)
                : Container(color: context.nc.isDark ? Colors.transparent : Colors.black),
          ),

          // Backdrop blur + dark overlay
          if (scanState.image != null)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: scanState.hasAnalysis ? 24 : 5,
                  sigmaY: scanState.hasAnalysis ? 24 : 5,
                ),
                child: Container(
                  color: Colors.black.withOpacity(scanState.hasAnalysis ? 0.85 : 0.4),
                ),
              ),
            ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(scanState),
                Expanded(child: _buildBody(scanState)),
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

  Widget _buildHeader(LensScanState scanState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
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

          // Title
          Text(
            scanState.hasAnalysis ? "Meal Analysis" : "Food Intelligence",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),

          // Share button
          if (scanState.hasAnalysis)
            GestureDetector(
              onTap: _shareResult,
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

  Widget _buildBody(LensScanState scanState) {
    if (scanState.phase == LensScanPhase.idle) return _buildCameraView();
    if (scanState.isAnalyzing) return _buildLoadingView(scanState);
    if (scanState.hasFailed) return _buildErrorView(scanState);
    if (scanState.hasAnalysis) return _buildResultsView(scanState);
    return const SizedBox.shrink();
  }

  // ─── Camera / Landing View ────────────────────────────────────────────────

  Widget _buildCameraView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                BrandColors.emerald500.withOpacity(0.2),
                Colors.transparent,
              ],
            ),
          ),
          child: const Icon(LucideIcons.scan, color: BrandColors.emerald500, size: 64),
        ),
        const SizedBox(height: 24),
        const Text(
          "Log Your Meal",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Get an instant deep-science breakdown\nof everything on your plate",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),

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

        const SizedBox(height: 56),

        // Action Buttons
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPickButton(
                  icon: LucideIcons.image,
                  label: "Gallery",
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
                const SizedBox(width: 32),

                // Main camera button
                GestureDetector(
                  onTap: () => _pickImage(ImageSource.camera),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.25), width: 8),
                      boxShadow: [
                        BoxShadow(color: Colors.white.withOpacity(0.25), blurRadius: 24),
                        BoxShadow(color: BrandColors.emerald500.withOpacity(0.15), blurRadius: 40),
                      ],
                    ),
                    child: const Icon(LucideIcons.camera, color: Colors.black, size: 36),
                  ),
                ),
                const SizedBox(width: 32),
                
                _buildPickButton(
                  icon: LucideIcons.mic,
                  label: "Voice",
                  onTap: _showVoiceLogDialog,
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildPickButton(
              icon: LucideIcons.edit3,
              label: "Describe Food",
              onTap: _showDescribeFoodDialog,
            ),
          ],
        ),
      ],
    );
  }

  Widget _featurePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.5), size: 12),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildPickButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Loading View ─────────────────────────────────────────────────────────

  Widget _buildLoadingView(LensScanState scanState) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: BrandColors.emerald500.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: BrandColors.emerald500.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: BrandColors.emerald500,
                strokeWidth: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _loadingMessages[scanState.loadingMessageIndex],
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            scanState.loadingMessageIndex < 2 
              ? "Using multi-spectral computer vision..." 
              : "Cross-referencing biomarker datasets...",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ─── Error View ───────────────────────────────────────────────────────────

  Widget _buildErrorView(LensScanState scanState) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: BrandColors.red500.withOpacity(0.3), width: 1),
            ),
            child: const Center(
              child: Icon(LucideIcons.alertTriangle, color: BrandColors.red500, size: 36),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            scanState.errorMessage ?? 'Analysis failed.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => ref.read(lensScanProvider.notifier).retry(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: BrandColors.emerald500,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Retry",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _reset,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Text(
                    "New Scan",
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Results View ─────────────────────────────────────────────────────────

  Widget _buildResultsView(LensScanState scanState) {
    final data = scanState.analysis!;
    final wearable = ref.watch(wearableStateProvider).value;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Hero: Score + Food Name ──────────────────────────────────────
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
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _showCorrectionDialog(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: BrandColors.emerald500.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: BrandColors.emerald500.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: BrandColors.emerald500.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.edit3, size: 12, color: BrandColors.emerald500),
                        const SizedBox(width: 8),
                        const Text(
                          "Not what you're eating?",
                          style: TextStyle(
                            color: BrandColors.emerald500,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "${data.calories} kcal",
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Intelligence Insight: Personalised Analysis ──────────────────
          LensIntelligenceInsight(insight: data.intelligenceInsight),
          const SizedBox(height: 24),

          // ── Wearable Bio-Data Banner ─────────────────────────────────────
          if (wearable != null && (wearable.recoveryScore > 0 || wearable.stressScore > 0 || wearable.sleepHours > 0)) ...[
            LensBioDataBanner(
              recoveryScore: wearable.recoveryScore,
              stressScore: wearable.stressScore,
              sleepHours: wearable.sleepHours,
              hrv: wearable.hrv,
            ),
            const SizedBox(height: 20),
          ],

          // ── Macros ───────────────────────────────────────────────────────
          LensSectionTitle(title: "MACRONUTRIENTS", icon: LucideIcons.barChart2),
          const SizedBox(height: 10),
          LensMacroBar(label: "Protein", amount: data.macros.protein, color: BrandColors.blue500),
          LensMacroBar(label: "Carbs", amount: data.macros.carbs, color: BrandColors.orange500),
          LensMacroBar(label: "Fat", amount: data.macros.fat, color: BrandColors.emerald500),
          const SizedBox(height: 20),

          // ── Deep Analysis Loading Banner ───────────────────────────────
          if (scanState.isDeepLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    BrandColors.emerald500.withOpacity(0.08),
                    const Color(0xFF1E1B4B).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BrandColors.emerald500.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BrandColors.emerald500.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Deep biological analysis loading...",
                      style: TextStyle(color: BrandColors.emerald500.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500),
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
            const SizedBox(height: 20),
          ],

          // ── Bio-Hack Tip ─────────────────────────────────────────────────
          if (data.bioHack.tip.isNotEmpty) ...[
            LensSectionTitle(title: "OPTIMIZATION TIP", icon: LucideIcons.zap),
            const SizedBox(height: 10),
            LensBioHackCard(bioHack: data.bioHack),
            const SizedBox(height: 20),
          ],

          // ── Hormonal Impact ──────────────────────────────────────────────
          if (data.hormonalImpact.insulin.response != 'Unknown') ...[
            LensSectionTitle(title: "HORMONAL IMPACT", icon: LucideIcons.activity),
            const SizedBox(height: 10),
            LensHormonalCard(hormonal: data.hormonalImpact),
            const SizedBox(height: 20),
          ],

          // ── Predictive Metabolic Animation ───────────────────────────────
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
                LensMetabolicCurveWidget(
                  energyCurve: data.metabolicImpact.energyCurve,
                ),
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

          // ── Bioavailability ──────────────────────────────────────────────
          if (data.bioavailability.absorptionScore > 0 || data.bioavailability.tips.isNotEmpty) ...[
            LensSectionTitle(title: "ABSORPTION & PREP", icon: LucideIcons.microscope),
            const SizedBox(height: 10),
            LensBioavailabilityCard(bioavailability: data.bioavailability),
            const SizedBox(height: 20),
          ],

          // ── UPF Processing ───────────────────────────────────────────────
          if (data.upfAnalysis.level != 'Unknown') ...[
            LensSectionTitle(title: "PROCESSING SCORE", icon: LucideIcons.testTube2),
            const SizedBox(height: 10),
            LensUPFCard(upf: data.upfAnalysis),
            const SizedBox(height: 20),
          ],

          // ── Bio Impact ───────────────────────────────────────────────────
          LensSectionTitle(title: "BIO-IMPACT ANALYSIS", icon: LucideIcons.heartPulse),
          const SizedBox(height: 10),
          ...data.bioImpact.map((item) => LensBioImpactCard(item: item)),
          const SizedBox(height: 20),

          // ── Toxin Radar ──────────────────────────────────────────────────
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

          // ── Longevity Impact ─────────────────────────────────────────────
          if (data.longevityImpact.longevityScore > 0) ...[
            LensSectionTitle(title: "LONGEVITY & CELLULAR AGING", icon: LucideIcons.dna),
            const SizedBox(height: 10),
            LensLongevityCard(longevity: data.longevityImpact),
            const SizedBox(height: 20),
          ],

          // ── Auto-Saved Indicator ─────────────────────────────────────────
          if (scanState.isComplete)
            SizedBox(
              width: double.infinity,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.checkCircle, color: BrandColors.emerald500.withOpacity(0.8), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "Saved to Food Log",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (scanState.isDeepLoading)
            SizedBox(
              width: double.infinity,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Saving to Food Log...",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
          const SizedBox(height: 16),
          // New Scan Button at the bottom
          if (scanState.hasAnalysis)
            Column(
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _reset,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.camera, color: Colors.white70, size: 18),
                          const SizedBox(width: 10),
                          const Text(
                            "Start New Scan",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: scanState.isDeleting ? null : () => _showDeleteConfirmation(context, ref),
                    icon: scanState.isDeleting 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.red500))
                      : const Icon(LucideIcons.trash2, color: BrandColors.red500, size: 16),
                    label: Text(
                      scanState.isDeleting ? "Deleting..." : "Remove from Log",
                      style: const TextStyle(color: BrandColors.red500, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Powered by Food Intelligence\nFood photos are processed securely and not stored by AI providers.',
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
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Meal?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "This will permanently remove this meal and its biological analysis from your log.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(lensScanProvider.notifier).deleteCurrentMeal();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Meal removed from log"), backgroundColor: BrandColors.red500),
                );
              }
            },
            child: const Text("Delete", style: TextStyle(color: BrandColors.red500, fontWeight: FontWeight.bold)),
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
              "Correct Food",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "Tell us what's actually in the photo for a more accurate analysis.",
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: "e.g., 'Quinoa salad with grilled chicken'",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: BrandColors.emerald500, width: 1.5),
                ),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  final correction = controller.text.trim();
                  if (correction.isNotEmpty) {
                    Navigator.pop(context);
                    ref.read(lensScanProvider.notifier).rescanWithCorrection(correction);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.emerald500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  "RE-ANALYZE MEAL",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
