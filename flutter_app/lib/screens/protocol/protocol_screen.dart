import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../data/protocol_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/patient_provider.dart';
import '../../providers/protocol_provider.dart';
import '../../providers/protocol_progress_provider.dart';
import '../../providers/consistency_provider.dart';
import '../../widgets/health_disclaimer_banner.dart';
import '../wearables/widgets/dashboard_card_style.dart';
import '../../providers/blueprint_provider.dart';
import '../../providers/navbar_provider.dart';

class ProtocolScreen extends ConsumerStatefulWidget {
  const ProtocolScreen({super.key});
  @override
  ConsumerState<ProtocolScreen> createState() => _ProtocolScreenState();
}

class _ProtocolScreenState extends ConsumerState<ProtocolScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _previousIndex = 0;
  late AnimationController _progressController;

  // Apple Health–style accent colors per category
  static const _categories = [
    _Category('Lifestyle', LucideIcons.leaf, Color(0xFFA855F7)),
    _Category('Diet', LucideIcons.utensils, Color(0xFF6366F1)),
    _Category('Fitness', LucideIcons.dumbbell, Color(0xFFEF4444)),
    _Category('Supplements', LucideIcons.pill, Color(0xFF10B981)),
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(patientProfileProvider).value;
      if (profile != null) {
        ref.read(protocolProvider.notifier).setProfileId(profile.id);
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  // Match Wearables dashboard background
  

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider); // Keep provider active
    final protocolState = ref.watch(protocolProvider);

    if (protocolState.isLoading) {
      return Container(
        color: context.nc.isDark ? Colors.transparent : context.nc.scaffoldBg,
        child: Center(
          child: CircularProgressIndicator(color: BrandColors.emerald500),
        ),
      );
    }

    final protocol = protocolState.selectedProtocol ?? ProtocolData.mock;
    final accent = _categories[_selectedIndex].color;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.nc.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: context.nc.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: context.nc.isDark ? Colors.transparent : context.nc.scaffoldBg,
        body: SafeArea(
          bottom: false,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                final double dy = notification.scrollDelta ?? 0.0;
                if (dy > 3.0) {
                  ref.read(navbarVisibleProvider.notifier).hide();
                } else if (dy < -3.0) {
                  ref.read(navbarVisibleProvider.notifier).show();
                }
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Page Title — matches Wearables header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Protocol',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: context.nc.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your personalized health protocol',
                          style: TextStyle(
                            fontSize: 15,
                            color: context.nc.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
  
                  // ── Header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _HeroHeader(
                        protocol: protocol,
                        progressController: _progressController,
                        onViewProtocols: () => context.push('/protocols'),
                      ),
                    ),
                  ),
  
                  // ── Segmented Control ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: _SegmentedControl(
                        categories: _categories,
                        selectedIndex: _selectedIndex,
                        onChanged: (i) => setState(() {
                          _previousIndex = _selectedIndex;
                          _selectedIndex = i;
                        }),
                      ),
                    ),
                  ),
  
                  // ── Content Body ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final isIncoming = child.key == ValueKey(_selectedIndex);
                          final slideRight = _selectedIndex >= _previousIndex;
  
                          Offset begin;
                          if (isIncoming) {
                            begin = slideRight
                                ? const Offset(0.08, 0)
                                : const Offset(-0.08, 0);
                          } else {
                            begin = slideRight
                                ? const Offset(-0.08, 0)
                                : const Offset(0.08, 0);
                          }
  
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: begin,
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          key: ValueKey(_selectedIndex),
                          child: _buildContent(protocol, accent),
                        ),
                      ),
                    ),
                  ),
  
                  // ── Bottom Spacing + Disclaimer ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 120),
                      child: const HealthDisclaimerBanner(
                        message: DisclaimerMessages.protocol,
                      ),
                    ),
                  ),
                ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ProtocolData protocol, Color accent) {
    switch (_selectedIndex) {
      case 0:
        return _TaskList(
          key: const ValueKey('lifestyle'),
          tasks: protocol.lifestyle,
          accent: _categories[0].color,
          emptyText: 'No lifestyle tasks for this phase.',
        );
      case 1:
        return _DietView(
          key: const ValueKey('diet'),
          blueprint: protocol.diet,
          tasks: protocol.lifestyle,
          accent: _categories[1].color,
        );
      case 2:
        return _TaskList(
          key: const ValueKey('fitness'),
          tasks: protocol.fitness,
          accent: _categories[2].color,
          emptyText: 'No fitness tasks for this phase.',
        );
      case 3:
        return _TaskList(
          key: const ValueKey('supplements'),
          tasks: protocol.supplements,
          accent: _categories[3].color,
          emptyText: 'No supplements for this phase.',
          showBuyLinks: true,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
//  DATA
// ═══════════════════════════════════════════════════════════════════

class _Category {
  final String label;
  final IconData icon;
  final Color color;
  const _Category(this.label, this.icon, this.color);
}

// ═══════════════════════════════════════════════════════════════════
//  HERO HEADER — Apple Health style white card
// ═══════════════════════════════════════════════════════════════════

class _HeroHeader extends ConsumerWidget {
  final ProtocolData protocol;
  final AnimationController progressController;
  final VoidCallback onViewProtocols;

  const _HeroHeader({
    required this.protocol,
    required this.progressController,
    required this.onViewProtocols,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressState = ref.watch(protocolProgressProvider);
    final isStarted = progressState.isStarted(protocol.id);
    
    // Get the actual duration from the progress state, or fallback to parsing the subtitle
    int durationWeeks = progressState.durations[protocol.id] ?? 12;
    if (!progressState.durations.containsKey(protocol.id)) {
      final match = RegExp(r'(\d+)\s*weeks', caseSensitive: false).firstMatch(protocol.subtitle);
      if (match != null) {
        durationWeeks = int.tryParse(match.group(1) ?? '') ?? 12;
      }
    }
    
    final consistency = ref.watch(consistencyProvider);
    final progress = progressState.getProgress(protocol.id, durationWeeks: durationWeeks, performanceRate: consistency.weekConsistency);
    
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar: Phase badge + "All Protocols"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Phase badge
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    protocol.currentPhase,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isStarted) ...[
                    GestureDetector(
                      onTap: () => _showResetDialog(context, ref, protocol),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            color: Colors.red.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: onViewProtocols,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'All Protocols',
                          style: TextStyle(
                            color: context.nc.textTertiary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(LucideIcons.chevronRight,
                            size: 16, color: context.nc.textTertiary),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                protocol.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.nc.textPrimary,
                  letterSpacing: -0.6,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                protocol.subtitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.nc.textTertiary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Streak & Consistency Badges
          if (isStarted)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFF97316).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.flame, color: Color(0xFFF97316), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${consistency.streakDays} Day Streak',
                        style: TextStyle(
                          color: Color(0xFFF97316),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.checkCircle, color: Color(0xFF10B981), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${(consistency.weekConsistency * 100).toInt()}% Consistency',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // Target Metrics
          if (protocol.targetMetrics.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: protocol.targetMetrics
                  .map(
                    (m) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        m,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.nc.textSecondary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Progress or Start Action
          if (!isStarted)
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _DurationPickerSheet(
                    protocol: protocol,
                    defaultWeeks: durationWeeks,
                    onConfirm: (weeks) {
                      ref.read(protocolProgressProvider.notifier).startProtocol(protocol.id, durationWeeks: weeks);
                      ref.read(blueprintProvider.notifier).startProtocolWithBlueprint(protocol.id, weeks);
                    },
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: context.nc.textPrimary,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Start Protocol',
                  style: TextStyle(
                    color: context.nc.scaffoldBg,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Protocol Progress',
                  style: TextStyle(
                    color: context.nc.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    color: context.nc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.nc.isDark ? context.nc.divider.withOpacity(0.1) : context.nc.cardBorder,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Phase Readiness Indicator
            Builder(builder: (context) {
              final readiness = progressState.getPhaseReadiness(
                protocol.id,
                durationWeeks: durationWeeks,
                weekConsistency: consistency.weekConsistency,
                streakDays: consistency.streakDays,
              );
              
              final hasMultiplePhases = protocol.availablePhases.length > 1;
              if (!hasMultiplePhases && !readiness.isReady) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: readiness.isReady
                        ? Color(0xFF10B981).withOpacity(0.08)
                        : context.nc.isDark ? context.nc.divider.withOpacity(0.05) : context.nc.scaffoldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: readiness.isReady
                          ? Color(0xFF10B981).withOpacity(0.3)
                          : context.nc.cardBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        readiness.isReady ? LucideIcons.zap : LucideIcons.clock,
                        size: 16,
                        color: readiness.isReady
                            ? Color(0xFF10B981)
                            : context.nc.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          readiness.reason,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: readiness.isReady
                                ? Color(0xFF10B981)
                                : context.nc.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref, ProtocolData protocol) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.nc.cardSurface,
        title: Text('Reset Protocol?', style: TextStyle(color: context.nc.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete your ${protocol.title} blueprint and restart your progress from Day 0. This cannot be undone.',
          style: TextStyle(color: context.nc.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Perform Reset
              await ref.read(blueprintProvider.notifier).resetBlueprint(protocol.id);
              await ref.read(protocolProgressProvider.notifier).resetProtocol(protocol.id);
              
              // Show confirmation snackbar
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${protocol.title} has been reset.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            child: Text('Reset', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  PROGRESS RING (multi-color like Apple Health)
// ═══════════════════════════════════════════════════════════════════

class _ProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;

  const _ProgressRing({
    required this.progress,
    required this.size,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ProgressRingPainter(
          progress: progress,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Text(
            '${(progress * 100).round()}%',
            style: TextStyle(
              color: context.nc.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc — teal/emerald like Apple Health
    final progressPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          Color(0xFF06B6D4), // Cyan
          Color(0xFF10B981), // Emerald
          Color(0xFFF59E0B), // Amber
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════
//  SEGMENTED CONTROL
// ═══════════════════════════════════════════════════════════════════

class _SegmentedControl extends StatelessWidget {
  final List<_Category> categories;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentedControl({
    required this.categories,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64, // Fixed height for consistent sliding
      padding: const EdgeInsets.all(4),
      decoration: DashboardCardStyle.decorationOf(context),
      child: Stack(
        children: [
          // Sliding background indicator
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            alignment: Alignment(
              -1 + (selectedIndex * (2 / (categories.length - 1))),
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / categories.length,
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: context.nc.cardSurface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab Labels
          Row(
            children: List.generate(categories.length, (i) {
              final cat = categories[i];
              final isSelected = i == selectedIndex;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? context.nc.textPrimary
                          : context.nc.textSecondary,
                      letterSpacing: -0.1,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            cat.icon,
                            key: ValueKey('icon_${cat.label}_$isSelected'),
                            size: 18,
                            color: isSelected
                                ? context.nc.textPrimary
                                : context.nc.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(cat.label),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  TASK LIST
// ═══════════════════════════════════════════════════════════════════

class _TaskList extends StatelessWidget {
  final List<ProtocolTask> tasks;
  final Color accent;
  final String emptyText;
  final bool showBuyLinks;

  const _TaskList({
    super.key,
    required this.tasks,
    required this.accent,
    required this.emptyText,
    this.showBuyLinks = false,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return _EmptyState(text: emptyText);

    return Column(
      children: tasks.asMap().entries.map((entry) {
        final i = entry.key;
        final task = entry.value;
        return TweenAnimationBuilder<double>(
          key: ValueKey('${task.title}_$i'),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (i * 80)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - value)),
                child: child,
              ),
            );
          },
          child: _TaskCard(
            task: task,
            accent: accent,
            showBuyLink: showBuyLinks && task.buyLink != null,
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  TASK CARD — Clean, premium Apple Health style
// ═══════════════════════════════════════════════════════════════════

class _TaskCard extends StatefulWidget {
  final ProtocolTask task;
  final Color accent;
  final bool showBuyLink;

  const _TaskCard({
    required this.task,
    required this.accent,
    this.showBuyLink = false,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: DashboardCardStyle.decorationOf(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.task.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.nc.textPrimary,
                                  height: 1.3,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _expanded
                                  ? LucideIcons.chevronUp
                                  : LucideIcons.chevronDown,
                              size: 18,
                              color: context.nc.textTertiary,
                            ),
                          ],
                        ),

                        // Time
                        if (widget.task.time.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.task.time,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.nc.textTertiary,
                            ),
                          ),
                        ],

                        // Description
                        const SizedBox(height: 8),
                        Text(
                          widget.task.detail,
                          maxLines: _expanded ? 100 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: context.nc.textSecondary,
                            height: 1.5,
                          ),
                        ),

                        // Frequency Pill (if expanded)
                        if (_expanded && widget.task.frequency != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: context.nc.isDark ? context.nc.divider.withOpacity(0.1) : context.nc.cardBorder,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.task.frequency!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.nc.textSecondary,
                              ),
                            ),
                          ),
                        ],

                        // Buy Button (if enabled)
                        if (_expanded && widget.showBuyLink) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              // Handle buy link
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 16),
                              decoration: BoxDecoration(
                                color: context.nc.textPrimary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Buy Now',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(LucideIcons.externalLink,
                                      size: 14, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  DIET VIEW — Macros, Principles, Avoid, Targets
// ═══════════════════════════════════════════════════════════════════

class _DietView extends StatelessWidget {
  final DietBlueprint blueprint;
  final List<ProtocolTask> tasks;
  final Color accent;

  const _DietView({
    super.key,
    required this.blueprint,
    required this.tasks,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Macro Overview Card ──
        if (blueprint.macros.isNotEmpty)
          DashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Donut + "MACROS" label
                Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CustomPaint(
                        painter: _MacroDonutPainter(macros: blueprint.macros),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      'Macros',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.nc.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Macro rows
                ...blueprint.macros.asMap().entries.map((entry) {
                  final color = _getMacroColor(entry.value.label);
                  return Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(
                        bottom:
                            entry.key < blueprint.macros.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          entry.value.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.nc.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.value.value,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

        // ── Principles ──
        if (blueprint.features.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: DashboardCardStyle.padding,
            decoration: DashboardCardStyle.decorationOf(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Principles',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.nc.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                ...blueprint.features.map((f) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color:
                                Color(0xFF10B981).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check,
                              size: 12, color: Color(0xFF10B981)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.nc.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        // ── Avoid ──
        if (blueprint.avoid.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: DashboardCardStyle.padding,
            decoration: DashboardCardStyle.decorationOf(context).copyWith(
              border: Border.all(color: context.nc.isDark ? Color(0xFFEF4444).withOpacity(0.3) : Color(0xFFFECACA).withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avoid',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEF4444),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                ...blueprint.avoid.map((a) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFEE2E2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close,
                              size: 12, color: Color(0xFFEF4444)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            a,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.nc.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        // ── Daily Targets ──
        if (blueprint.targets.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: DashboardCardStyle.padding,
            decoration: DashboardCardStyle.decorationOf(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Targets',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.nc.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                ...blueprint.targets.asMap().entries.map((entry) {
                  final label = entry.value.label;
                  final value = entry.value.value;

                  // Determine formatting based on label
                  Color bgColor;
                  Color textColor;

                  if (label.toLowerCase().contains('protein')) {
                    bgColor = Color(0xFFEEF2FF); // Indigo 50
                    textColor = Color(0xFF6366F1); // Indigo 500
                  } else if (label.toLowerCase().contains('carb')) {
                    bgColor = Color(0xFFFFFBEB); // Amber 50
                    textColor = Color(0xFFF59E0B); // Amber 500
                  } else if (label.toLowerCase().contains('fat')) {
                    bgColor = Color(0xFFECFDF5); // Emerald 50
                    textColor = Color(0xFF10B981); // Emerald 500
                  } else if (label.toLowerCase().contains('calorie')) {
                    bgColor = Color(0xFFEFF6FF); // Blue 50
                    textColor = Color(0xFF3B82F6); // Blue 500
                  } else {
                    bgColor = Color(0xFFF8FAFC); // Slate 50
                    textColor = Color(0xFF64748B); // Slate 500
                  }

                  return Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(
                        bottom:
                            entry.key < blueprint.targets.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.nc.isDark ? textColor.withOpacity(0.12) : bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    child: Row(
                      children: [
                        // Colored Dot
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: textColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Label
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.nc.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Value
                        Expanded(
                          child: Text(
                            value,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        // ── Weekly Menu CTA ──
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => context.push('/weekly-menu'),
          child: DashboardCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(LucideIcons.calendarCheck, color: accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Weekly Menu',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.nc.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'View your personalized meal plan',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.nc.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight,
                    size: 18, color: accent.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  MACRO DONUT PAINTER
// ═══════════════════════════════════════════════════════════════════

class _MacroDonutPainter extends CustomPainter {
  final List<MacroItem> macros;

  _MacroDonutPainter({required this.macros});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 12.0;

    final colors = macros.map((m) => _getMacroColor(m.label)).toList();

    final values = macros.map((m) {
      final numStr = m.value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(numStr) ?? 33.3;
    }).toList();

    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return;

    double startAngle = -math.pi / 2;

    for (var i = 0; i < values.length && i < colors.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep - 0.06,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Color _getMacroColor(String label) {
  final l = label.toLowerCase();
  if (l.contains('protein')) return Color(0xFF6366F1); // Indigo
  if (l.contains('carb')) return Color(0xFFF59E0B); // Amber
  if (l.contains('fat')) return Color(0xFF10B981); // Emerald
  return Color(0xFF64748B); // Slate
}

// ═══════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.nc.isDark ? context.nc.divider.withOpacity(0.1) : context.nc.navbarPillBg,
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.inbox,
                  size: 32, color: context.nc.textTertiary),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: context.nc.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  DURATION PICKER BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════

class _DurationPickerSheet extends StatefulWidget {
  final ProtocolData protocol;
  final int defaultWeeks;
  final ValueChanged<int> onConfirm;

  const _DurationPickerSheet({
    required this.protocol,
    required this.defaultWeeks,
    required this.onConfirm,
  });

  @override
  State<_DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<_DurationPickerSheet> {
  late int _selectedWeeks;
  late FixedExtentScrollController _scrollController;

  static const int _minWeeks = 2;
  static const int _maxWeeks = 52;

  @override
  void initState() {
    super.initState();
    _selectedWeeks = widget.defaultWeeks.clamp(_minWeeks, _maxWeeks);
    _scrollController = FixedExtentScrollController(
      initialItem: _selectedWeeks - _minWeeks,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: context.nc.scaffoldBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.nc.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            'Set Protocol Duration',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.nc.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.protocol.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.nc.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your AI coach will pre-generate a day-by-day schedule for the entire duration.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.nc.textSecondary.withOpacity(0.8),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 24),

          // Wheel Picker
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: context.nc.isDark ? context.nc.scaffoldBg : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.nc.cardBorder),
            ),
            child: Stack(
              children: [
                // Selection highlight
                Center(
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: context.nc.textPrimary.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // Picker
                ListWheelScrollView.useDelegate(
                  controller: _scrollController,
                  itemExtent: 44,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _selectedWeeks = index + _minWeeks;
                    });
                    HapticFeedback.selectionClick();
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: _maxWeeks - _minWeeks + 1,
                    builder: (context, index) {
                      final weeks = index + _minWeeks;
                      final isSelected = weeks == _selectedWeeks;
                      return Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: isSelected ? 20 : 16,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            color: isSelected
                                ? context.nc.textPrimary
                                : context.nc.textTertiary,
                          ),
                          child: Text(
                            '$weeks weeks  •  ${weeks * 7} days',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Confirm Button
          GestureDetector(
            onTap: () {
              HapticFeedback.heavyImpact();
              Navigator.of(context).pop();
              widget.onConfirm(_selectedWeeks);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: context.nc.textPrimary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: context.nc.textPrimary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.rocket, size: 18, color: context.nc.scaffoldBg),
                  const SizedBox(width: 8),
                  Text(
                    'Start • $_selectedWeeks Weeks',
                    style: TextStyle(
                      color: context.nc.scaffoldBg,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
