import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/chat_provider.dart';
import '../services/voice_service.dart';

class AdvancedVoiceOverlay extends ConsumerStatefulWidget {
  const AdvancedVoiceOverlay({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const AdvancedVoiceOverlay();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.1, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<AdvancedVoiceOverlay> createState() => _AdvancedVoiceOverlayState();
}

class _AdvancedVoiceOverlayState extends ConsumerState<AdvancedVoiceOverlay> with TickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _recognizedWords = '';
  bool _isListening = false;
  bool _hasSentMessage = false;
  bool _isSpeaking = false;
  
  late AnimationController _orbController;
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (val) => debugPrint('Voice Error: $val'),
        onStatus: (val) {
          if (mounted) {
            setState(() {
              _isListening = _speechToText.isListening;
            });
          }
        },
      );
      if (mounted && _speechEnabled) {
        _startListening();
      }
    } catch (e) {
      debugPrint('Voice Init Exception: $e');
    }
  }

  void _startListening() async {
    if (!mounted) return;
    setState(() {
      _hasSentMessage = false;
      _recognizedWords = '';
      // We do not reset _isSpeaking here to allow true Voice Barge-in.
    });
    
    await _speechToText.listen(
      onResult: (result) {
        if (mounted) {
          // Voice Barge-In: If the AI is speaking and the user starts talking, instantly stop the AI
          if (_isSpeaking && result.recognizedWords.trim().isNotEmpty) {
            ref.read(voiceServiceProvider).stop();
            setState(() => _isSpeaking = false);
          }

          setState(() {
            _recognizedWords = result.recognizedWords;
          });
          // Only auto-send if the plugin is extremely confident (finalResult)
          if (result.finalResult && !_hasSentMessage) {
            _handleFinalResult();
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(milliseconds: 1500), // Reduced from 3s to 1.5s for a snappier, conversational feel
      partialResults: true,
      localeId: 'en_IN', // Optimize for Indian English as per the user's "haan"
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    // Manual override: if the user taps to stop, send what we have immediately
    if (mounted && _recognizedWords.trim().isNotEmpty && !_hasSentMessage) {
      _handleFinalResult();
    }
  }

  void _handleFinalResult() {
    if (_recognizedWords.trim().isEmpty || _hasSentMessage) return;
    
    setState(() => _hasSentMessage = true);
    HapticFeedback.mediumImpact();
    
    // Send to chat provider with voice mode flag for concise responses
    ref.read(chatProvider.notifier).sendMessage(_recognizedWords, isVoiceMode: true);
  }

  Future<void> _triggerSpeech(String text) async {
    if (text.isEmpty || !mounted) return;
    
    setState(() => _isSpeaking = true);
    
    // Comprehensive markdown cleanup for natural speech
    final cleanText = text
        .replaceAll(RegExp(r'\*\*'), '')   // Bold
        .replaceAll(RegExp(r'__'), '')     // Underline
        .replaceAll(RegExp(r'#+ '), '')    // Headers
        .replaceAll(RegExp(r'^\s*[\*\-]\s+', multiLine: true), '') // Bullet points
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')     // Links
        .replaceAll('\n', ' ')             // Newlines to spaces
        .trim();
        
    // Start listening immediately so the user can barge-in and interrupt
    _startListening();
    
    await ref.read(voiceServiceProvider).speak(cleanText);
    
    // Re-sync UI once it finishes speaking naturally
    if (mounted && _isSpeaking) {
      setState(() => _isSpeaking = false);
    }
  }

  @override
  void dispose() {
    _orbController.dispose();
    _pulseController.dispose();
    _speechToText.cancel();
    ref.read(voiceServiceProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final isThinking = chatState.isLoading;
    final lastMessage = chatState.messages.isNotEmpty ? chatState.messages.last : null;
    final isAIResponding = lastMessage != null && !lastMessage.isUser;
    
    // Auto-trigger speech when AI message is finished and we haven't spoken it yet
    if (!isThinking && _hasSentMessage && isAIResponding) {
       // We use a listener pattern for cleaner execution in build
    }

    // Use ref.listen to trigger speech once response is complete
    ref.listen(chatProvider, (previous, next) {
      if (previous?.isLoading == true && next.isLoading == false) {
        final last = next.messages.isNotEmpty ? next.messages.last : null;
        if (last != null && !last.isUser && _hasSentMessage) {
          _triggerSpeech(last.text);
        }
      }
    });
    
    // Determine what text to show
    String displayTitle = "Zyndio Intelligence";
    String displayText = _recognizedWords;
    
    if (isThinking && !_isListening) {
      displayTitle = "Thinking...";
      if (isAIResponding) {
        displayText = lastMessage.text.isNotEmpty ? lastMessage.text : "I've generated a health update for you.";
      } else {
        displayText = "Analyzing your health query...";
      }
    } else if (_isSpeaking) {
      displayTitle = "Speaking...";
      displayText = lastMessage?.text.isNotEmpty == true ? lastMessage!.text : "Listening to response...";
    } else if (_isListening) {
      displayTitle = "Listening...";
      if (_recognizedWords.isEmpty) displayText = "How can I help you today?";
    } else if (!isThinking && _hasSentMessage && lastMessage != null && !lastMessage.isUser) {
      displayTitle = "Intelligence";
      displayText = lastMessage.text.isNotEmpty ? lastMessage.text : "I've updated your health dashboard.";
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. High-fidelity glass blur background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: Colors.black.withOpacity(0.85),
              ),
            ),
          ),
          
          // 2. Animated Aurora Background (Siri-like)
          if (_isListening || isThinking) ...[
            _AuroraBlob(
              color: const Color(0xFF4F46E5),
              top: -100,
              right: -50,
              size: 400,
              opacity: isThinking ? 0.3 : 0.2,
            ),
            _AuroraBlob(
              color: const Color(0xFFA855F7),
              bottom: 100,
              left: -100,
              size: 500,
              opacity: isThinking ? 0.25 : 0.15,
            ),
          ],

          SafeArea(
            child: Column(
              children: [
                // Header / Close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayTitle.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(LucideIcons.x, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // 3. The Intelligence Orb
                Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_orbController, _pulseController]),
                    builder: (context, child) {
                      double pulseValue = (isThinking || _isSpeaking) ? 0.5 + (0.5 * _pulseController.value) : _pulseController.value;
                      double orbRotation = (isThinking || _isSpeaking) ? _orbController.value * 4 * math.pi : _orbController.value * 2 * math.pi;
                      
                      return GestureDetector(
                        onTap: () {
                          if (!_isListening && !isThinking && !_isSpeaking) {
                            _startListening();
                          } else if (_isListening) {
                            _stopListening();
                          } else if (_isSpeaking) {
                            ref.read(voiceServiceProvider).stop();
                            _startListening();
                          }
                        },
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withOpacity(0.4 * pulseValue),
                                blurRadius: 50 + (30 * pulseValue),
                                spreadRadius: 15 * pulseValue,
                              ),
                              BoxShadow(
                                color: const Color(0xFFA855F7).withOpacity(0.3 * pulseValue),
                                blurRadius: 70 + (40 * pulseValue),
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Rotating rainbow sweep gradient
                              Transform.rotate(
                                angle: orbRotation,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: [
                                        const Color(0xFFF59E0B).withOpacity(0.9),
                                        const Color(0xFFA855F7).withOpacity(0.9),
                                        const Color(0xFF3B82F6).withOpacity(0.9),
                                        const Color(0xFF22D3EE).withOpacity(0.9),
                                        const Color(0xFFF43F5E).withOpacity(0.9),
                                        const Color(0xFFF59E0B).withOpacity(0.9),
                                      ],
                                    ),
                                  ),
                                ),
                              ).blur(isThinking ? 30 : 20),
                              
                              // Core Zyndio Orb Image
                              Container(
                                width: 160,
                                height: 160,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/icons/zyndioorb.png',
                                        width: 160,
                                        height: 160,
                                        fit: BoxFit.cover,
                                      ),
                                      if (isThinking)
                                        Container(
                                          color: Colors.black.withOpacity(0.3),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 50,
                                              height: 50,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 3,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // 4. Transcription / Response Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Text(
                        displayText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // Status hint
                GestureDetector(
                  onTap: () {
                     if (!_isListening && !isThinking && !_isSpeaking) _startListening();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      _isListening ? "Listening..." : (isThinking ? "Intelligence is working" : (_isSpeaking ? "Tap orb to interrupt" : "Tap orb to speak again")),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  final Color color;
  final double? top, bottom, left, right;
  final double size;
  final double opacity;

  const _AuroraBlob({
    required this.color,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(opacity),
              color.withOpacity(0),
            ],
          ),
        ),
      ),
    );
  }
}

extension _BlurWidget on Widget {
  Widget blur(double sigma) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: this,
    );
  }
}
