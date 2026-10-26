import 'package:flutter/material.dart';
import 'dart:async';
import '../config/theme.dart';

enum LoadingType { general, labs }

class IntelligenceAnalysisLoading extends StatefulWidget {
  final LoadingType type;
  const IntelligenceAnalysisLoading({super.key, this.type = LoadingType.general});

  @override
  State<IntelligenceAnalysisLoading> createState() => _IntelligenceAnalysisLoadingState();
}

class _IntelligenceAnalysisLoadingState extends State<IntelligenceAnalysisLoading> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  int _messageIndex = 0;
  Timer? _timer;

  List<String> get _messages {
    if (widget.type == LoadingType.labs) {
      return [
        "Analyzing Biomarker Correlations...",
        "Evaluating Lab Reference Ranges...",
        "Identifying Longitudinal Trends...",
        "Synthesizing Health Insights...",
      ];
    }
    return [
      "Consulting Zyndio Expertise...",
      "Identifying Trends & Patterns...",
      "Decoding Biological Markers...",
      "Finalizing Personalized Insights...",
    ];
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _messages.length;
        });
        _fadeController.reset();
        _fadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.nc.isDark ? context.nc.cardSurface : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.nc.cardBorder.withValues(alpha: 0.1)),
      ),
      child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              // Animated Status Text
              FadeTransition(
                opacity: _fadeController,
                child: Text(
                  _messages[_messageIndex],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.nc.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
    );
  }
}


