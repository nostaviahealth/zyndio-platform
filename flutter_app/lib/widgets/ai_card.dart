import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/ai_theme_provider.dart'; 
import './intelligence_glow_wrapper.dart';
import '../config/theme.dart';

/// Zyndio AI Insight Card - Light Elegant Design
class AICard extends ConsumerStatefulWidget {
  final VoidCallback? onTap;
  final List<String> insights;

  const AICard({
    super.key,
    this.onTap,
    this.insights = const [],
  });

  @override
  ConsumerState<AICard> createState() => _AICardState();
}

class _AICardState extends ConsumerState<AICard> with TickerProviderStateMixin {
  late AnimationController _cursorController;
  late AnimationController _typingController;
  late Animation<int> _characterCount;
  Timer? _typingTimer; // Timer for text pause
  
  // ValueNotifier instead of setState for insight cycling — avoids full rebuild
  late final ValueNotifier<int> _insightIndex;
  String _currentText = '';

  @override
  void initState() {
    super.initState();
    _insightIndex = ValueNotifier(0);
    _cursorController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);

    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _typingController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 1), () {
          if (mounted) _nextInsight();
        });
      }
    });

    if (widget.insights.isNotEmpty) {
      _startTyping(widget.insights[0]);
    } else {
      _startTyping("Welcome to Zyndio. Complete your daily protocol to generate new health insights.");
    }
  }

  @override
  void didUpdateWidget(AICard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.insights != oldWidget.insights && widget.insights.isNotEmpty) {
      _insightIndex.value = 0;
      _startTyping(widget.insights[0]);
    }
  }

  void _startTyping(String text) {
    _currentText = text;
    _typingController.duration = Duration(milliseconds: text.length * 30);
    _characterCount = StepTween(begin: 0, end: text.length)
        .animate(CurvedAnimation(parent: _typingController, curve: Curves.easeIn));
    _typingController.reset();
    _typingController.forward();
  }

  void _nextInsight() {
    if (widget.insights.isEmpty) return;
    final next = (_insightIndex.value + 1) % widget.insights.length;
    _insightIndex.value = next;
    _startTyping(widget.insights[next]);
  }

  void _previousInsight() {
    if (widget.insights.isEmpty) return;
    final prev = (_insightIndex.value - 1 + widget.insights.length) % widget.insights.length;
    _insightIndex.value = prev;
    _startTyping(widget.insights[prev]);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity! < 0) {
      _nextInsight();
    } else if (details.primaryVelocity! > 0) {
      _previousInsight();
    }
  }

  @override
  void dispose() {
    _cursorController.dispose();
    _typingController.dispose();
    _typingTimer?.cancel();
    _insightIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiTheme = ref.watch(aiThemeProvider);
    final isSiri = aiTheme == AIThemeMode.siri;

    return IntelligenceGlowWrapper(
      borderRadius: 32,
      child: Container(
          decoration: BoxDecoration(
            color: context.nc.cardSurface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: context.nc.cardBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Stack(
                children: [
                  // 1. Theme-aware Background
                  Positioned.fill(
                    child: Container(color: context.nc.cardSurface.withValues(alpha: 0.6)),
                  ),

                // 2. Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 24, 16), 
                  child: GestureDetector(
                    onHorizontalDragEnd: _onHorizontalDragEnd,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        // Main Title
                        Text(
                          'What would you like to know?',
                          style: TextStyle(
                            fontSize: 32, 
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            height: 1.1,
                            fontFamily: 'SF Pro Display',
                            color: context.nc.textPrimary,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Content Box - Simple Flat Style
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 120), // Increased to prevent resizing during typing
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.nc.isDark ? context.nc.divider.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_typingController, _cursorController]),
                            builder: (context, child) {
                              String textToShow = _currentText;
                              if (_typingController.value < 1.0) {
                                int count = _characterCount.value;
                                if (count > _currentText.length) count = _currentText.length;
                                textToShow = _currentText.substring(0, count);
                              }
                              return RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: context.nc.textPrimary,
                                    fontFamily: 'SF Pro Display',
                                    letterSpacing: -0.1,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  children: [
                                    TextSpan(text: textToShow),
                                    TextSpan(
                                      text: '|',
                                      style: TextStyle(
                                        color: _cursorController.value > 0.5 
                                            ? (isSiri ? const Color(0xFFA855F7) : const Color(0xFF6366F1))
                                            : Colors.transparent,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Health Disclaimer
                        Center(
                          child: Text(
                            'AI-generated insights • Wellness Reference',
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8).withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Footer Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                                onTap: () => context.pushNamed('chat_history'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  color: Colors.transparent, 
                                  child: Row(
                                    children: [
                                      Text(
                                        'History',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: context.nc.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        LucideIcons.arrowRight,
                                        size: 14,
                                        color: context.nc.textPrimary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            
                              // Start Chat Button
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  context.pushNamed('chat');
                                },
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: context.nc.isDark ? Colors.white : const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (context.nc.isDark ? Colors.white : const Color(0xFF0F172A)).withValues(alpha: 0.2), 
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Start Chat',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: context.nc.isDark ? Colors.black : Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),

                          ],
                        ),
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

// Extension to easily blur containers
extension BlurExtension on Widget {
   Widget blur(double sigma) {
     return ImageFiltered(
       imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
       child: this,
     );
   }
}
