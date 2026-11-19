import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/patient_provider.dart';
import '../../providers/lab_analysis_provider.dart';
import '../../providers/lab_reports_provider.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import './lab_report_submitted_screen.dart';

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

    // React to completion — show what happened to the report (APP-05: it is
    // already filed and read on the server; there is nothing to verify).
    ref.listen<LabAnalysisState>(labAnalysisProvider, (_, next) {
      if (next.status == LabAnalysisStatus.completed && next.submission != null) {
        if (!mounted) return;
        ref.invalidate(labReportsProvider);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LabReportSubmittedScreen(submission: next.submission!),
          ),
        );
      }
    });


    final c = Theme.of(context).extension<ZyndioColors>()!;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.z25.screenBg,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header (close button hidden while analysis runs) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: _buildHeader(analysisState, c),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    // ── Drop zone ──
                    if (!analysisState.isRunning &&
                        analysisState.status != LabAnalysisStatus.completed)
                      _buildDropZone(c),

                    // ── Completed State ──
                    if (analysisState.status == LabAnalysisStatus.completed)
                      _buildSuccessCard(analysisState, c),

                    // ── Progress View ──
                    if (analysisState.isRunning)
                      _buildProgressView(analysisState, c),

                    // ── Errors ──
                    if (analysisState.status == LabAnalysisStatus.error)
                      _buildErrorCard(analysisState, c),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Bottom Action Area ──
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!analysisState.isRunning &&
                    analysisState.status != LabAnalysisStatus.completed)
                  _buildAnalyzeButton(analysisState),
                if (analysisState.status == LabAnalysisStatus.completed) ...[
                  _buildViewResultsButton(analysisState),
                  const SizedBox(height: 12),
                  _buildStartNewButton(c),
                ],
                if (analysisState.isRunning) _buildMinimizeButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────
  Widget _buildHeader(LabAnalysisState state, ZyndioColors c) {
    const title = 'Lab Intelligence';
    final description = _description(state);
    if (!state.isRunning) {
      return ZyndioBackHeader(
        title: title,
        subtitle: description,
        backIcon: LucideIcons.x,
        onBack: () => Navigator.pop(context),
      );
    }
    // While the analysis runs there is no close button (minimise instead).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 24,
                  height: 30 / 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: c.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: TextStyle(
            fontFamily: ZyndioType.family,
            fontSize: 15,
            height: 22 / 15,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }

  String _description(LabAnalysisState state) {
    String text = 'Upload your lab report to generate deep physiological insights.';
    if (state.isRunning) {
      text = 'Zyndio AI is processing your clinical data to build your biological future.';
    } else if (state.status == LabAnalysisStatus.completed) {
      text = 'Your clinical biomarkers have been successfully extracted.';
    }
    return text;
  }

  // ─────────────────────────────────────
  // SUCCESS / COMPLETED STATE
  // ─────────────────────────────────────
  Widget _buildSuccessCard(LabAnalysisState state, ZyndioColors c) {
    return ZyndioCard(
      radius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.statusSuccessSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.checkCircle2,
                size: 32, color: c.statusSuccess),
          ),
          const SizedBox(height: 20),
          Text(
            'Analysis Successfully Completed',
            textAlign: TextAlign.center,
            style: ZyndioType.title3.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.result?['title'] ?? 'Full Biomarker Report',
            textAlign: TextAlign.center,
            style: ZyndioType.subhead.copyWith(
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'We’ve extracted blood markers from your report. Please verify and confirm them to update your health dashboard.',
            textAlign: TextAlign.center,
            style: ZyndioType.footnote.copyWith(
              height: 1.5,
              color: c.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewResultsButton(LabAnalysisState state) {
    return ZyndioGradientButton(
      label: 'View Results',
      onTap: () {
        if (state.submission == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LabReportSubmittedScreen(submission: state.submission!),
          ),
        );
      },
    );
  }

  Widget _buildStartNewButton(ZyndioColors c) {
    return ZyndioOutlineButton(
      label: 'Discard — Start New Analysis',
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: c.bgSurface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: Text('Discard Result?',
                style: ZyndioType.headline.copyWith(color: c.textPrimary)),
            content: Text(
                'This will clear the current analysis. You can upload a new report after this.',
                style: ZyndioType.subhead.copyWith(color: c.textSecondary)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel',
                      style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary))),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Discard',
                    style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontWeight: FontWeight.w600,
                        color: c.statusCritical)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          ref.read(labAnalysisProvider.notifier).dismiss();
        }
      },
    );
  }

  // ─────────────────────────────────────
  // DROP ZONE (The Interaction Center)
  // ─────────────────────────────────────
  Widget _buildDropZone(ZyndioColors c) {
    final selected = _selectedFile != null;
    return Container(
      decoration: zyndioCard(context),
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: selected ? c.brandPrimary : c.borderStrong,
          radius: 24,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              constraints: const BoxConstraints(minHeight: 240),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ZyndioIconTile(
                    icon: selected ? LucideIcons.check : LucideIcons.filePlus,
                    tint: selected ? ZyndioTint.green : ZyndioTint.blue,
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    selected ? 'Report Selected' : 'Select Report',
                    textAlign: TextAlign.center,
                    style: ZyndioType.headline.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: c.textPrimary,
                    ),
                  ),
                  if (selected)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _selectedFile!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZyndioType.footnote.copyWith(
                          fontWeight: FontWeight.w500,
                          color: c.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // ANALYZE BUTTON
  // ─────────────────────────────────────
  Widget _buildAnalyzeButton(LabAnalysisState state) {
    final isReady = _selectedFile != null;
    return ZyndioGradientButton(
      label: 'Analyze Report',
      onTap: isReady ? _startAnalysis : null,
    );
  }

  // ─────────────────────────────────────
  // LIVE PROGRESS VIEW
  // ─────────────────────────────────────
  Widget _buildProgressView(LabAnalysisState state, ZyndioColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stage stepper
        _buildStageStepper(state),

        const SizedBox(height: 12),

        // Animated Progress Bar
        ZyndioCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      state.statusMessage,
                      style: ZyndioType.subhead.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(state.progress * 100).round()}%',
                    style: ZyndioType.subhead.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: ZyndioType.tabular,
                      color: c.brandPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: state.progress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  builder: (ctx, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: c.bgSunken,
                    valueColor: AlwaysStoppedAnimation<Color>(c.brandPrimary),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (state.totalChunks > 0) ...[
                const SizedBox(height: 12),
                Text(
                  state.status == LabAnalysisStatus.preparingPdf
                      ? 'Structuring data for Scanners...'
                      : 'Analyzing batch ${state.currentChunk} of ${state.totalChunks}',
                  style: ZyndioType.footnote.copyWith(
                    fontWeight: FontWeight.w500,
                    color: c.textTertiary,
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

    return ZyndioCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
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
    return ZyndioOutlineButton(
      icon: LucideIcons.arrowDownToLine,
      label: 'Minimize — Continue in Background',
      onTap: _minimize,
    );
  }

  // ─────────────────────────────────────
  // ERROR CARD
  // ─────────────────────────────────────
  Widget _buildErrorCard(LabAnalysisState state, ZyndioColors c) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.statusCriticalSubtle,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.alertTriangle, size: 28, color: c.statusCritical),
          const SizedBox(height: 12),
          Text(
            'Analysis Failed',
            style: ZyndioType.headline.copyWith(
              fontWeight: FontWeight.w700,
              color: c.statusCritical,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.errorMessage ?? 'Something went wrong. Please try again.',
            textAlign: TextAlign.center,
            style: ZyndioType.footnote.copyWith(
              height: 1.4,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              ref.read(labAnalysisProvider.notifier).reset();
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              backgroundColor: c.bgSurface,
              foregroundColor: c.statusCritical,
              side: BorderSide(color: c.statusCritical, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              textStyle: const TextStyle(
                fontFamily: ZyndioType.family,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────
// DASHED DROP-ZONE BORDER
// ─────────────────────────────────────
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.5;
    const dash = 7.0;
    const gap = 5.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          rect.deflate(strokeWidth / 2), Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
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
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final Color iconBg = isDone
        ? c.statusSuccessSubtle
        : isActive
            ? c.brandSubtle
            : context.z25.tileBg;

    final Color iconColor = isDone
        ? c.statusSuccess
        : isActive
            ? c.brandPrimary
            : c.textTertiary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
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
                    ? Icon(LucideIcons.check, size: 20, color: iconColor)
                    : Icon(data.icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              // Labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 15,
                        fontWeight: isActive || isDone
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isActive || isDone
                            ? c.textPrimary
                            : c.textTertiary,
                        letterSpacing: -0.2,
                      ),
                      child: Text(data.title),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 13,
                        color: isActive ? c.textSecondary : c.textTertiary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Status indicator
              if (isActive)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    strokeCap: StrokeCap.round,
                    valueColor: AlwaysStoppedAnimation<Color>(c.brandPrimary),
                  ),
                )
              else if (isDone)
                Icon(LucideIcons.checkCircle2,
                    size: 18, color: c.statusSuccess),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: c.borderSubtle, indent: 58),
      ],
    );
  }
}
