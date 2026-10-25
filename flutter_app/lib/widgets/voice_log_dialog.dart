import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'dart:ui' as ui;
import '../services/azure_openai_service.dart';

class VoiceLogDialog extends ConsumerStatefulWidget {
  final Function(String) onResult;

  const VoiceLogDialog({super.key, required this.onResult});

  @override
  ConsumerState<VoiceLogDialog> createState() => _VoiceLogDialogState();
}

class _VoiceLogDialogState extends ConsumerState<VoiceLogDialog> with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  bool _isListening = false;
  bool _isRefining = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (val) => debugPrint('Speech Error: $val'),
        onStatus: (val) => debugPrint('Speech Status: $val'),
      );
      if (mounted) {
        setState(() {});
        if (_speechEnabled) {
          _startListening();
        }
      }
    } catch (e) {
      debugPrint('Speech Init Exception: $e');
    }
  }

  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    if (mounted) {
      setState(() {
        _isListening = true;
      });
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (mounted) {
      setState(() {
        _lastWords = result.recognizedWords;
      });
    }
  }

  Future<void> _handleAnalyze() async {
    if (_lastWords.isEmpty) return;

    setState(() {
      _isRefining = true;
      _isListening = false;
    });

    try {
      final refinedText = await ref.read(azureOpenAIServiceProvider).refineTranscript(_lastWords);
      if (mounted) {
        widget.onResult(refinedText);
      }
    } catch (e) {
      if (mounted) {
        widget.onResult(_lastWords); // Fallback to raw if refinement fails
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speechToText.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E293B).withOpacity(0.85),
                  const Color(0xFF0F172A).withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Voice Meal Log',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 140,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      _isRefining
                          ? "Refining transcript..."
                          : (_lastWords.isEmpty
                              ? (_isListening ? "Listening..." : "Initializing mic...")
                              : _lastWords),
                      style: TextStyle(
                        color: (_lastWords.isEmpty || _isRefining) ? Colors.white.withOpacity(0.35) : Colors.white,
                        fontSize: 17,
                        height: 1.4,
                        fontStyle: _isRefining ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: _isRefining
                      ? const SizedBox(
                          height: 80,
                          width: 80,
                          child: CircularProgressIndicator(
                            color: Color(0xFF007AFF),
                            strokeWidth: 3.5,
                          ),
                        )
                      : AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final pulse = _pulseController.value;
                            return GestureDetector(
                              onTap: _isListening ? _stopListening : _startListening,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // External glowing wave ring
                                  if (_isListening)
                                    Container(
                                      height: 80 + (24 * pulse),
                                      width: 80 + (24 * pulse),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.4 * (1.0 - pulse)),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  // Main button
                                  Container(
                                    height: 80,
                                    width: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: _isListening
                                            ? [
                                                const Color(0xFFFF453A),
                                                const Color(0xFFFF3B30).withOpacity(0.8),
                                              ]
                                            : [
                                                const Color(0xFF0A84FF),
                                                const Color(0xFF0056B3),
                                              ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_isListening ? Colors.red : const Color(0xFF007AFF)).withOpacity(0.35 + (0.15 * pulse)),
                                          blurRadius: 16 + (8 * pulse),
                                          spreadRadius: 2,
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.15),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      _isListening ? LucideIcons.mic : LucideIcons.micOff,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _isRefining
                        ? "Zyndio Intelligence is polishing..."
                        : (_isListening ? "Recording..." : "Tap mic to speak"),
                    style: TextStyle(
                      color: _isListening ? const Color(0xFFFF453A) : Colors.white.withOpacity(0.4),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isRefining ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: (_lastWords.isEmpty || _isRefining)
                              ? [
                                  Colors.white.withOpacity(0.05),
                                  Colors.white.withOpacity(0.03),
                                ]
                              : [
                                  const Color(0xFF007AFF),
                                  const Color(0xFF0056B3),
                                ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: (_lastWords.isEmpty || _isRefining)
                            ? []
                            : [
                                BoxShadow(
                                  color: const Color(0xFF007AFF).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: ElevatedButton(
                        onPressed: (_lastWords.isEmpty || _isRefining) ? null : _handleAnalyze,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white.withOpacity(0.2),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _isRefining ? 'Refining...' : 'Analyze',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
