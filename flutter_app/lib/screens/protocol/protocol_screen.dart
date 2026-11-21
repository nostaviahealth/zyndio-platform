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
import '../../widgets/tc025/tc025_widgets.dart';
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

  // Category accents from the shared tint families (My Plan / Today).
  static const _categories = [
    _Category('Lifestyle', LucideIcons.leaf, ZyndioTint.violet),
    _Category('Diet', LucideIcons.utensils, ZyndioTint.indigo),
    _Category('Fitness', LucideIcons.dumbbell, ZyndioTint.rose),
    _Category('Supplements', LucideIcons.pill, ZyndioTint.green),
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

  /// Loading / error / empty states: the pushed-screen scaffold (with a back
  /// button) when opened from My Plan, the tab scaffold otherwise.
  Widget _stateScaffold(List<Widget> children) {
    if (Navigator.of(context).canPop()) {
      return ZyndioDetailScaffold(
        title: 'My Plan',
        subtitle: 'Published by your care team.',
        children: children,
      );
    }
    return ZyndioTabScaffold(
      title: 'My Plan',
      subtitle: 'Published by your care team.',
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider); // Keep provider active
    final protocolState = ref.watch(protocolProvider);

    if (protocolState.isLoading) {
      return _stateScaffold(const [
        ZyndioStateCard(
          icon: LucideIcons.clipboardList,
          title: 'Loading your plan',
          body: 'Checking for a plan your care team has published.',
        ),
      ]);
    }

    if (protocolState.loadFailed) {
      return _stateScaffold([
        ZyndioStateCard(
          icon: LucideIcons.triangleAlert,
          title: "We couldn't load your plan",
          body: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: () => ref.read(protocolProvider.notifier).fetchLibrary(),
        ),
      ]);
    }

    final protocol = protocolState.selectedProtocol;
    if (protocol == null) {
      return _stateScaffold(const [
        ZyndioStateCard(
          icon: LucideIcons.clipboardList,
          title: 'No plan yet',
          body:
              'Your care team will publish your plan here after your first consultation.',
        ),
      ]);
    }
    final accent = _categories[_selectedIndex].tint;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: context.z25.screenBg,
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
                // ── Same back header as the other pushed screens ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: canPop
                        ? ZyndioBackHeader(
                            title: 'Your plan',
                            subtitle: 'Published by your care team.',
                            onBack: () => Navigator.of(context).pop(),
                          )
                        : const ZyndioPageHeader(
                            title: 'Your plan',
                            subtitle: 'Published by your care team.',
                          ),
                  ),
                ),

                // ── Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 32, 20, 120),
                    child: HealthDisclaimerBanner(
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

  Widget _buildContent(ProtocolData protocol, ZyndioTint accent) {
    switch (_selectedIndex) {
      case 0:
        return _TaskList(
          key: const ValueKey('lifestyle'),
          tasks: protocol.lifestyle,
          accent: _categories[0].tint,
          emptyText: 'No lifestyle tasks for this phase.',
        );
      case 1:
        return _DietView(
          key: const ValueKey('diet'),
          blueprint: protocol.diet,
          tasks: protocol.lifestyle,
          accent: _categories[1].tint,
        );
      case 2:
        return _TaskList(
          key: const ValueKey('fitness'),
          tasks: protocol.fitness,
          accent: _categories[2].tint,
          emptyText: 'No fitness tasks for this phase.',
        );
      case 3:
        return _TaskList(
          key: const ValueKey('supplements'),
          tasks: protocol.supplements,
          accent: _categories[3].tint,
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
  final ZyndioTint tint;
  const _Category(this.label, this.icon, this.tint);
}

// ═══════════════════════════════════════════════════════════════════
//  HERO HEADER — premium white card
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
    final c = Theme.of(context).extension<ZyndioColors>()!;
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
    
    return ZyndioCard(
      radius: 24,
      padding: const EdgeInsets.all(20),
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
                    color: c.statusSuccessSubtle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    protocol.currentPhase,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      color: c.statusSuccess,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
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
                            fontFamily: ZyndioType.family,
                            color: c.statusCritical,
                            fontSize: 13,
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
                          'All plans',
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            color: c.brandPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(LucideIcons.chevronRight,
                            size: 16, color: c.brandPrimary),
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
                style: ZyndioType.title2.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                protocol.subtitle,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 14,
                  height: 20 / 14,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Streak & Consistency Badges
          if (isStarted)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ZyndioPill(
                  '${consistency.streakDays} Day Streak',
                  tone: ZyndioPillTone.warning,
                  icon: LucideIcons.flame,
                ),
                ZyndioPill(
                  '${(consistency.weekConsistency * 100).toInt()}% Consistency',
                  tone: ZyndioPillTone.success,
                  icon: LucideIcons.checkCircle,
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
                  .map((m) => ZyndioPill(m))
                  .toList(),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Progress or Start Action
          if (!isStarted)
            ZyndioGradientButton(
              label: 'Start plan',
              trailingArrow: false,
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
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Plan progress',
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: ZyndioType.tabular,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.bgSunken,
                borderRadius: BorderRadius.circular(999),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: ZyndioGradients.brand,
                    borderRadius: BorderRadius.circular(999),
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
                        ? c.statusSuccessSubtle
                        : c.bgSunken,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        readiness.isReady ? LucideIcons.zap : LucideIcons.clock,
                        size: 16,
                        color: readiness.isReady
                            ? c.statusSuccess
                            : c.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          readiness.reason,
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: readiness.isReady
                                ? c.statusSuccess
                                : c.textSecondary,
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
      builder: (context) {
        final c = Theme.of(context).extension<ZyndioColors>()!;
        return AlertDialog(
          backgroundColor: c.bgSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Reset Protocol?',
            style: ZyndioType.headline.copyWith(
                color: c.textPrimary, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'This will permanently delete your ${protocol.title} blueprint and restart your progress from Day 0. This cannot be undone.',
            style: ZyndioType.subhead.copyWith(color: c.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  color: c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                      backgroundColor: c.statusSuccess,
                    ),
                  );
                }
              },
              child: Text(
                'Reset',
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  color: c.statusCritical,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
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
    return ZyndioSegmentedTabs(
      labels: [for (final cat in categories) cat.label],
      selected: selectedIndex,
      onSelected: onChanged,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  TASK LIST
// ═══════════════════════════════════════════════════════════════════

class _TaskList extends StatelessWidget {
  final List<ProtocolTask> tasks;
  final ZyndioTint accent;
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
//  TASK CARD
// ═══════════════════════════════════════════════════════════════════

class _TaskCard extends StatefulWidget {
  final ProtocolTask task;
  final ZyndioTint accent;
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
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: zyndioCard(context, radius: 22),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Category accent bar
                Container(
                  width: 4,
                  margin: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: widget.accent.colors,
                    ),
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4)),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 18, 18),
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
                                  fontFamily: ZyndioType.family,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: c.textPrimary,
                                  height: 22 / 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _expanded
                                  ? LucideIcons.chevronUp
                                  : LucideIcons.chevronDown,
                              size: 18,
                              color: c.textTertiary,
                            ),
                          ],
                        ),

                        // Time
                        if (widget.task.time.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.task.time,
                            style: TextStyle(
                              fontFamily: ZyndioType.family,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: c.textTertiary,
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
                            fontFamily: ZyndioType.family,
                            fontSize: 14,
                            color: c.textSecondary,
                            height: 20 / 14,
                          ),
                        ),

                        // Frequency Pill (if expanded)
                        if (_expanded && widget.task.frequency != null) ...[
                          const SizedBox(height: 12),
                          ZyndioPill(widget.task.frequency!),
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
                                gradient: ZyndioGradients.brand,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Buy Now',
                                    style: TextStyle(
                                      fontFamily: ZyndioType.family,
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

/// Title inside a diet card ("Macros", "Principles", …).
Widget _cardTitle(BuildContext context, String text, {Color? color}) {
  final c = Theme.of(context).extension<ZyndioColors>()!;
  return Text(
    text,
    style: ZyndioType.headline.copyWith(color: color ?? c.textPrimary),
  );
}

/// A tinted inset row: coloured dot, label and right-aligned value.
Widget _tintedValueRow(BuildContext context,
    {required String label,
    required String value,
    required Color color,
    Color? background,
    required bool last}) {
  final c = Theme.of(context).extension<ZyndioColors>()!;
  return Container(
    width: double.infinity,
    margin: EdgeInsets.only(bottom: last ? 0 : 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: background ?? color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontFamily: ZyndioType.family,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFeatures: ZyndioType.tabular,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DietView extends StatelessWidget {
  final DietBlueprint blueprint;
  final List<ProtocolTask> tasks;
  final ZyndioTint accent;

  const _DietView({
    super.key,
    required this.blueprint,
    required this.tasks,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Macro Overview Card ──
        if (blueprint.macros.isNotEmpty)
          ZyndioCard(
            radius: 24,
            padding: const EdgeInsets.all(20),
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
                        painter: _MacroDonutPainter(
                          macros: blueprint.macros,
                          fallback: c.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    _cardTitle(context, 'Macros'),
                  ],
                ),
                const SizedBox(height: 16),
                // Macro rows
                ...blueprint.macros.asMap().entries.map((entry) {
                  final color = _getMacroColor(entry.value.label, c.textTertiary);
                  return _tintedValueRow(
                    context,
                    label: entry.value.label,
                    value: entry.value.value,
                    color: color,
                    last: entry.key >= blueprint.macros.length - 1,
                  );
                }),
              ],
            ),
          ),

        // ── Principles ──
        if (blueprint.features.isNotEmpty) ...[
          const SizedBox(height: 16),
          ZyndioCard(
            radius: 24,
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardTitle(context, 'Principles'),
                  const SizedBox(height: 14),
                  ...blueprint.features.map((f) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 1),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: c.statusSuccessSubtle,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(LucideIcons.check,
                                size: 12, color: c.statusSuccess),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              f,
                              style: TextStyle(
                                fontFamily: ZyndioType.family,
                                fontSize: 15,
                                color: c.textPrimary,
                                height: 20 / 15,
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
          ),
        ],

        // ── Avoid ──
        if (blueprint.avoid.isNotEmpty) ...[
          const SizedBox(height: 16),
          ZyndioCard(
            radius: 24,
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardTitle(context, 'Avoid', color: c.statusCritical),
                  const SizedBox(height: 14),
                  ...blueprint.avoid.map((a) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: c.statusCriticalSubtle,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(LucideIcons.x,
                                size: 12, color: c.statusCritical),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              a,
                              style: TextStyle(
                                fontFamily: ZyndioType.family,
                                fontSize: 15,
                                color: c.textPrimary,
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
          ),
        ],

        // ── Daily Targets ──
        if (blueprint.targets.isNotEmpty) ...[
          const SizedBox(height: 16),
          ZyndioCard(
            radius: 24,
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardTitle(context, 'Daily Targets'),
                  const SizedBox(height: 14),
                  ...blueprint.targets.asMap().entries.map((entry) {
                    final label = entry.value.label;
                    final value = entry.value.value;

                    // Determine formatting based on label
                    final l = label.toLowerCase();
                    final ZyndioTint? tint = l.contains('protein')
                        ? ZyndioTint.indigo
                        : l.contains('carb')
                            ? ZyndioTint.amber
                            : l.contains('fat')
                                ? ZyndioTint.green
                                : l.contains('calorie')
                                    ? ZyndioTint.blue
                                    : null;

                    return _tintedValueRow(
                      context,
                      label: label,
                      value: value,
                      color: tint?.colors.last ?? c.textSecondary,
                      background: tint == null ? c.bgSunken : null,
                      last: entry.key >= blueprint.targets.length - 1,
                    );
                  }),
                ],
              ),
            ),
          ),
        ],

        // ── Weekly Menu CTA ──
        const SizedBox(height: 16),
        ZyndioListRow(
          icon: LucideIcons.calendarCheck,
          tint: accent,
          title: 'Your Weekly Menu',
          subtitle: 'View your personalized meal plan',
          onTap: () => context.push('/weekly-menu'),
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
  final Color fallback;

  _MacroDonutPainter({required this.macros, required this.fallback});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 12.0;

    final colors = macros.map((m) => _getMacroColor(m.label, fallback)).toList();

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
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) =>
      oldDelegate.fallback != fallback;
}

/// Macro accent from the shared tint families; [fallback] for anything else.
Color _getMacroColor(String label, Color fallback) {
  final l = label.toLowerCase();
  if (l.contains('protein')) return ZyndioTint.indigo.colors.last;
  if (l.contains('carb')) return ZyndioTint.amber.colors.last;
  if (l.contains('fat')) return ZyndioTint.green.colors.last;
  return fallback;
}

// ═══════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: zyndioCard(context),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.z25.tileBg,
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.inbox, size: 26, color: c.textSecondary),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 15,
              height: 22 / 15,
              color: c.textSecondary,
            ),
          ),
        ],
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
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            'Set Protocol Duration',
            style: ZyndioType.title3.copyWith(
                color: c.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            widget.protocol.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your AI coach will pre-generate a day-by-day schedule for the entire duration.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 13,
              color: c.textTertiary,
              height: 18 / 13,
            ),
          ),

          const SizedBox(height: 24),

          // Wheel Picker
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: c.bgSunken,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              children: [
                // Selection highlight
                Center(
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: c.bgSurface,
                      borderRadius: BorderRadius.circular(999),
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
                            fontFamily: ZyndioType.family,
                            fontSize: isSelected ? 18 : 16,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontFeatures: ZyndioType.tabular,
                            color: isSelected
                                ? c.brandPrimary
                                : c.textTertiary,
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
          ZyndioGradientButton(
            label: 'Start • $_selectedWeeks Weeks',
            icon: LucideIcons.rocket,
            trailingArrow: false,
            onTap: () {
              HapticFeedback.heavyImpact();
              Navigator.of(context).pop();
              widget.onConfirm(_selectedWeeks);
            },
          ),
        ],
      ),
    );
  }
}
