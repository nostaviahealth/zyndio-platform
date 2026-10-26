// In-App Alert Banner — Premium Visual Component
//
// A high-end, animated alert banner that slides down from the top of the screen.
// Features glassmorphic design, gradient accents, and smooth animations.
// Designed to overlay on top of any screen via the global AlertWrapper.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/alert_model.dart';
import '../providers/alert_provider.dart';
import '../providers/rhythm_provider.dart';

// ─── ALERT WRAPPER ──────────────────────────────────────────────────────────
// 
// Wrap the entire app's content with this widget to enable global alert display.
// Used inside MaterialApp.router's `builder`.

class AlertWrapper extends ConsumerWidget {
  final Widget child;

  const AlertWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAlert = ref.watch(activeAlertProvider);

    return Stack(
      children: [
        // App content
        child,

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
            child: activeAlert != null
                ? _AlertBannerCard(
                    key: ValueKey(activeAlert.id),
                    alert: activeAlert,
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ),
      ],
    );
  }
}

// ─── ALERT BANNER CARD ──────────────────────────────────────────────────────

class _AlertBannerCard extends ConsumerStatefulWidget {
  final AppAlert alert;

  const _AlertBannerCard({super.key, required this.alert});

  @override
  ConsumerState<_AlertBannerCard> createState() => _AlertBannerCardState();
}

class _AlertBannerCardState extends ConsumerState<_AlertBannerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AlertVisualConfig _visual;
  Offset _dragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _visual = AlertVisualConfig.fromCategory(widget.alert.category);

    // Progress bar animation (fills from left to right over the auto-dismiss duration)
    _progressController = AnimationController(
      vsync: this,
      duration: widget.alert.autoDismissDuration,
    )..forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _dismiss() {
    ref.read(alertProvider.notifier).dismiss();
  }

  void _handleTap() {
    if (widget.alert.actionRoute != null) {
      _dismiss();
      // Small delay for the dismiss animation to play
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          // Fix for "black screen" issue: Use context.go() to avoid stack push issues with top-level shell routes
          context.go(widget.alert.actionRoute!);
        }
      });
    } else {
      _dismiss();
    }
  }

  void _handleUndo() {
    if (widget.alert.undoActionId == 'daily_rhythm') {
      // Import of rhythm_provider is already there or handled by ref
      // We'll perform the undo specifically for the rhythm tasks
      ref.read(dailyRhythmProvider.notifier).undoLastAutoCompletion();
      _dismiss();
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: _handleTap,
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragOffset += details.delta;
          });
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset.dy < -30 || (details.primaryVelocity != null && details.primaryVelocity! < -200)) {
            _dismiss();
          } else {
            setState(() {
              _dragOffset = Offset.zero;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _dragOffset.dy.clamp(-80, 10), 0),
          child: Container(
            margin: EdgeInsets.only(
              top: topPadding + 8,
              left: 12,
              right: 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: -10,
                ),
                // Glow effect based on category
                BoxShadow(
                  color: _visual.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Category Icon Indicator
                      Container(
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _visual.primaryColor.withValues(alpha: 0.2),
                              _visual.primaryColor.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _visual.primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          _visual.icon,
                          color: _visual.primaryColor,
                          size: 20,
                        ),
                      ),

                      // Text content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.alert.title.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true), ''),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.alert.message.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true), ''),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Undo Button
                      if (widget.alert.undoActionId != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: TextButton(
                            onPressed: _handleUndo,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                            ),
                            child: const Text(
                              'Undo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                      // Close button
                      GestureDetector(
                        onTap: _dismiss,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

