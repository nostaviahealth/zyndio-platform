import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/patient_provider.dart';
import '../../providers/lab_analysis_provider.dart';
import '../../providers/lab_reports_provider.dart';
import './lab_report_verification_screen.dart';

class LabReportUploadScreen extends ConsumerStatefulWidget {
  const LabReportUploadScreen({super.key});

  @override
  ConsumerState<LabReportUploadScreen> createState() =>
      _LabReportUploadScreenState();
}

class _LabReportUploadScreenState
    extends ConsumerState<LabReportUploadScreen>
    with TickerProviderStateMixin {
  PlatformFile? _selectedFile;

  // Pulse animation for the "brain" icon during analysis
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final filePickerResult = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (filePickerResult != null) {
        setState(() => _selectedFile = filePickerResult.files.first);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _startAnalysis() async {
    if (_selectedFile == null) return;
    final profile = ref.read(patientProfileProvider).value;
    if (profile == null) return;

    HapticFeedback.mediumImpact();
    await ref.read(labAnalysisProvider.notifier).startAnalysis(
          filePath: _selectedFile!.path!,
          fileName: _selectedFile!.name,
          profileId: profile.id,
        );
  }

  void _minimize() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Analysis running in background. Check Labs when done.'),
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analysisState = ref.watch(labAnalysisProvider);

    // React to completion — navigate to verification
    ref.listen<LabAnalysisState>(labAnalysisProvider, (_, next) {
      if (next.status == LabAnalysisStatus.completed && next.result != null) {
        final profile = ref.read(patientProfileProvider).value;
        if (profile == null || !mounted) return;
        
        // 🔥 CRITICAL: We stop calling consumeResult() here to prevent the UI from resetting 
        // to "Select File" while the navigation is still transitioning. 
        // Logic moved to the end of verification screen.
        
        ref.invalidate(labReportsProvider);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LabReportVerificationScreen(
              filePath: _selectedFile?.path ?? next.result!['title'] ?? '',
              fileName: _selectedFile?.name ?? next.result!['title'] ?? '',
              profileId: profile.id,
              extractedData: next.result!,
            ),
          ),
        );
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: BrandColors.dark,
        body: Stack(
          children: [
            // Background mesh/gradient
            // ── Clean Ambient Background ──
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      const Color(0xFF4F46E5).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // ── Navigation (Back Button) ──
                  _buildNavigationBar(analysisState),

                  const SizedBox(height: 48),

                  // ── Title ──
                  _buildTitle(),

                  // ── Description ──
                  _buildDescription(analysisState),

                  const SizedBox(height: 40),

                  Expanded(
                    child: Stack(
                      children: [
                        // ── Interaction Area (Centered Orb) ──
                        if (!analysisState.isRunning && analysisState.status != LabAnalysisStatus.completed)
                          Center(child: _buildIntelligenceOrb()),

                        // ── Completed State ──
                        if (analysisState.status == LabAnalysisStatus.completed)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: _buildSuccessCard(analysisState),
                            ),
                          ),

                        // ── Progress View ──
                        if (analysisState.isRunning)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: _buildProgressView(analysisState),
                            ),
                          ),

                        // ── Errors ──
                        if (analysisState.status == LabAnalysisStatus.error)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: _buildErrorCard(analysisState),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Bottom Action Area ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!analysisState.isRunning && analysisState.status != LabAnalysisStatus.completed)
                          _buildAnalyzeButton(analysisState),
                        
                        if (analysisState.status == LabAnalysisStatus.completed) ...[
                          _buildViewResultsButton(analysisState),
                          const SizedBox(height: 12),
                          _buildStartNewButton(),
                        ],

                        if (analysisState.isRunning)
                          _buildMinimizeButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────
  Widget _buildNavigationBar(LabAnalysisState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (!state.isRunning)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                ),
                child: const Icon(LucideIcons.arrowLeft, size: 20, color: Colors.white),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        'Lab Intelligence',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildDescription(LabAnalysisState state) {
    String text = 'Upload your lab report to generate deep physiological insights.';
    if (state.isRunning) {
      text = 'Zyndio AI is processing your clinical data to build your biological future.';
    } else if (state.status == LabAnalysisStatus.completed) {
      text = 'Your clinical biomarkers have been successfully extracted.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          color: Colors.white.withValues(alpha: 0.4),
          fontWeight: FontWeight.w500,
          height: 1.4,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // SUCCESS / COMPLETED STATE
  // ─────────────────────────────────────
  Widget _buildSuccessCard(LabAnalysisState state) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BrandColors.emerald500.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BrandColors.emerald500.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.checkCircle2,
                size: 32, color: BrandColors.emerald500),
          ),
          const SizedBox(height: 24),
          const Text(
            'Analysis Successfully Completed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.result?['title'] ?? 'Full Biomarker Report',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'We’ve extracted blood markers from your report. Please verify and confirm them to update your health dashboard.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.4),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewResultsButton(LabAnalysisState state) {
    return GestureDetector(
      onTap: () {
        final profile = ref.read(patientProfileProvider).value;
        if (profile == null || state.result == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LabReportVerificationScreen(
              filePath: state.pendingFilePath ?? state.result!['title'] ?? '',
              fileName: state.pendingFileName ?? state.result!['title'] ?? '',
              profileId: profile.id,
              extractedData: state.result!,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [BrandColors.emerald500, Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: BrandColors.emerald500.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Text(
          'View & Verify Results',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildStartNewButton() {
    return GestureDetector(
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('Discard Result?', style: TextStyle(color: Colors.white)),
            content: const Text('This will clear the current analysis. You can upload a new report after this.', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: BrandColors.slate400))),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Discard', style: TextStyle(color: BrandColors.red400)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          ref.read(labAnalysisProvider.notifier).dismiss();
        }
      },
      child: Container(
        width: double.infinity,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: const Text(
          'Discard — Start New Analysis',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: BrandColors.slate400,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // INTELLIGENCE ORB (The Interaction Center)
  // ─────────────────────────────────────
  Widget _buildIntelligenceOrb() {
    return GestureDetector(
      onTap: _pickFile,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
          
          // Static Glass Border
          Container(
            width: 256,
            height: 256,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
          ),

          // The Glass Orb
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: (_selectedFile != null ? BrandColors.emerald500 : const Color(0xFF4F46E5)).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _selectedFile != null ? LucideIcons.check : LucideIcons.filePlus,
                          color: _selectedFile != null ? BrandColors.emerald500 : const Color(0xFFA855F7),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _selectedFile != null ? 'Report Selected' : 'Select Report',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (_selectedFile != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _selectedFile!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────
  // ANALYZE BUTTON
  // ─────────────────────────────────────
  Widget _buildAnalyzeButton(LabAnalysisState state) {
    final isReady = _selectedFile != null;
    return GestureDetector(
      onTap: isReady ? _startAnalysis : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: isReady 
              ? const LinearGradient(
                  colors: [BrandColors.emerald500, Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isReady 
              ? null 
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: isReady ? null : Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: isReady
              ? [
                  BoxShadow(
                    color: BrandColors.emerald500.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Text(
          'Analyze Report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isReady ? Colors.white : Colors.white.withValues(alpha: 0.2),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // LIVE PROGRESS VIEW
  // ─────────────────────────────────────
  Widget _buildProgressView(LabAnalysisState state) {
    return Column(
      children: [
        // Stage stepper
        _buildStageStepper(state),

        const SizedBox(height: 24),

        // Animated Progress Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      state.statusMessage,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(state.progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: state.progress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  builder: (ctx, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 12,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(BrandColors.emerald500),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (state.totalChunks > 0) ...[
                const SizedBox(height: 12),
                Text(
                  state.status == LabAnalysisStatus.preparingPdf
                      ? 'Structuring data for Scanners...'
                      : 'Analyzing batch ${state.currentChunk} of ${state.totalChunks}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────
  // STAGE STEPPER — 3 explicit stages
  // ─────────────────────────────────────
  Widget _buildStageStepper(LabAnalysisState state) {
    const stages = [
      _StageData(
        icon: LucideIcons.fileSearch,
        title: 'Document Check',
        subtitle: 'Converting pages to images',
      ),
      _StageData(
        icon: LucideIcons.brain,
        title: 'AI Vision Analysis',
        subtitle: 'Extracting data from each page',
      ),
      _StageData(
        icon: LucideIcons.dna,
        title: 'Bio-marker Mapping',
        subtitle: 'Classifying & organizing results',
      ),
    ];

    int activeIndex;
    switch (state.status) {
      case LabAnalysisStatus.preparingPdf:
        activeIndex = 0;
        break;
      case LabAnalysisStatus.analyzing:
        activeIndex = 1;
        break;
      case LabAnalysisStatus.finalizing:
        activeIndex = 2;
        break;
      default:
        activeIndex = 0;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: List.generate(stages.length, (i) {
          final isDone = i < activeIndex;
          final isActive = i == activeIndex;
          return _StageRow(
            data: stages[i],
            isDone: isDone,
            isActive: isActive,
            showDivider: i < stages.length - 1,
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────
  // MINIMIZE BUTTON
  // ─────────────────────────────────────
  Widget _buildMinimizeButton() {
    return GestureDetector(
      onTap: _minimize,
      child: Container(
        width: double.infinity,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.arrowDownToLine,
                size: 18, color: Colors.white.withValues(alpha: 0.5)),
            SizedBox(width: 10),
            Text(
              'Minimize — Continue in Background',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // ERROR CARD
  // ─────────────────────────────────────
  Widget _buildErrorCard(LabAnalysisState state) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BrandColors.red500.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.red500.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.alertTriangle, size: 28, color: Color(0xFFEF4444)),
          const SizedBox(height: 12),
          const Text(
            'Analysis Failed',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: BrandColors.red400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.errorMessage ?? 'Something went wrong. Please try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: BrandColors.red400.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              ref.read(labAnalysisProvider.notifier).reset();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: BrandColors.red500,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: BrandColors.red500.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────
// STAGE DATA MODEL
// ─────────────────────────────────────
class _StageData {
  final IconData icon;
  final String title;
  final String subtitle;
  const _StageData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

// ─────────────────────────────────────
// STAGE ROW WIDGET
// ─────────────────────────────────────
class _StageRow extends StatelessWidget {
  final _StageData data;
  final bool isDone;
  final bool isActive;
  final bool showDivider;

  const _StageRow({
    required this.data,
    required this.isDone,
    required this.isActive,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconBg = isDone
        ? BrandColors.emerald500
        : isActive
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.03);

    final Color iconColor = isDone
        ? Colors.white
        : isActive
            ? Colors.white
            : Colors.white.withValues(alpha: 0.2);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              // Icon bubble
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: isDone
                    ? const Icon(LucideIcons.check,
                        size: 20, color: Colors.white)
                    : Icon(data.icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 16),
              // Labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isActive || isDone
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isActive || isDone
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                        letterSpacing: -0.2,
                      ),
                      child: Text(data.title),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.3),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Status indicator
              if (isActive)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    strokeCap: StrokeCap.round,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else if (isDone)
                const Icon(LucideIcons.checkCircle2,
                    size: 18, color: BrandColors.emerald500),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.05), indent: 60),
      ],
    );
  }
}
