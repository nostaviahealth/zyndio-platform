import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../config/theme.dart';
import '../services/azure_openai_service.dart';
import 'tc025/tc025_widgets.dart';

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
    final c = context.zc;
    final canAnalyze = _lastWords.isNotEmpty && !_isRefining;
    final rose = ZyndioTint.rose;
    return Dialog(
      backgroundColor: c.bgSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: Theme.of(context).brightness == Brightness.dark
            ? BorderSide(color: c.borderSubtle)
            : BorderSide.none,
      ),
      // Scrolls instead of overflowing on a small phone with large text.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Voice Meal Log',
              style: ZyndioType.title2.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 16),
            Container(
              height: 140,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.bgSunken,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.borderSubtle),
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
                    fontFamily: ZyndioType.family,
                    color: (_lastWords.isEmpty || _isRefining) ? c.textTertiary : c.textPrimary,
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
                  ? SizedBox(
                      height: 80,
                      width: 80,
                      child: CircularProgressIndicator(
                        color: c.brandPrimary,
                        strokeWidth: 3.5,
                      ),
                    )
                  : AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final pulse = _pulseController.value;
                        return GestureDetector(
                          onTap: _isListening ? _stopListening : _startListening,
                          child: SizedBox(
                            height: 104,
                            width: 104,
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
                                        color: rose.colors.last.withValues(alpha: 0.4 * (1.0 - pulse)),
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
                                    gradient: _isListening
                                        ? LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: rose.colors,
                                          )
                                        : ZyndioGradients.brand,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isListening ? rose.colors.last : ZyndioTint.indigo.colors.last)
                                            .withValues(alpha: 0.30 + (0.12 * pulse)),
                                        blurRadius: 16 + (8 * pulse),
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isListening ? LucideIcons.mic : LucideIcons.micOff,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              _isRefining
                  ? "Zyndio Intelligence is polishing..."
                  : (_isListening ? "Recording..." : "Tap mic to speak"),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: ZyndioType.family,
                color: _isListening ? c.statusCritical : c.textTertiary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            // Stacked full-width actions: never squeezed on a narrow phone.
            ZyndioGradientButton(
              label: _isRefining ? 'Refining...' : 'Analyze',
              trailingArrow: false,
              onTap: canAnalyze ? _handleAnalyze : null,
            ),
            const SizedBox(height: 10),
            ZyndioOutlineButton(
              label: 'Cancel',
              onTap: _isRefining ? null : () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
