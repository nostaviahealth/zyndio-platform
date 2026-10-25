import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/usage_limit_provider.dart';
import '../settings/paywall_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../providers/chat_provider.dart';
import '../../providers/navbar_provider.dart';
import '../../providers/suggestion_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/protocol_provider.dart';
import '../../models/health_protocol.dart';
import '../../models/meal_plan.dart';
import '../../data/meal_repository.dart';
import 'protocol_canvas.dart';
import 'meal_plan_canvas.dart';
import 'chat_cta_strip.dart';
import '../../services/conversion_service.dart';
import 'simulation_card.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../widgets/advanced_voice_mode.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? initialMessage;
  const ChatScreen({super.key, this.initialMessage});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  File? _selectedImage;

  bool _initialMessageSent = false;
  int _initialMessageCount = 0;
  final Set<int> _animatedIndices = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      Future.microtask(() {
        ref.read(chatProvider.notifier).startNewSession();
        ref.read(navbarVisibleProvider.notifier).hide();
      });
    } else {
      Future.microtask(() {
        ref.read(navbarVisibleProvider.notifier).hide();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _initialMessageCount = ref.read(chatProvider).messages.length;
        });
      }
    });

    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_initialMessageSent) {
          _initialMessageSent = true;
          ref.read(chatProvider.notifier).sendMessage(widget.initialMessage!);
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    Future.microtask(() {
      ref.read(navbarVisibleProvider.notifier).show();
    });
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    final canChat = ref.read(canSendChatProvider);
    if (!canChat) {
      PaywallScreen.show(context);
      return;
    }

    HapticFeedback.mediumImpact();
    ref.read(chatProvider.notifier).sendMessage(
      text.isEmpty ? 'Please analyze this image in context of my health data.' : text,
      imagePath: _selectedImage?.path,
    );
    _messageController.clear();
    setState(() => _selectedImage = null);
    FocusScope.of(context).unfocus();
  }

  void _scrollToBottom({bool force = false, bool isStreaming = false}) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final double pixelsFromBottom = position.maxScrollExtent - position.pixels;
    
    if (force || pixelsFromBottom < 100) {
      if (isStreaming) {
        _scrollController.jumpTo(position.maxScrollExtent);
      } else {
        _scrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;
    final isLoading = chatState.isLoading;

    ref.listen(chatProvider, (previous, next) {
      final bool newMsgAdded = next.messages.length > (previous?.messages.length ?? 0);
      final bool contentUpdating = next.isLoading && 
          previous != null && 
          next.messages.isNotEmpty && 
          previous.messages.isNotEmpty && 
          next.messages.last.text != previous.messages.last.text;

      if (newMsgAdded) {
        _scrollToBottom(force: true);
      } else if (contentUpdating) {
        _scrollToBottom(isStreaming: true);
      }

      // 🚀 High-conversion placement: record success and trigger paywall if threshold reached
      final bool responseFinished = previous != null && previous.isLoading && !next.isLoading;
      if (responseFinished && next.messages.isNotEmpty && !next.messages.last.isUser) {
        ref.read(conversionServiceProvider).recordAhaMoment(context);
      }
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        ref.read(navbarVisibleProvider.notifier).show();
      },
      child: Scaffold(
        backgroundColor: context.nc.scaffoldBg,
        body: Stack(
          children: [
            // 1. Solid Base Layer
            Positioned.fill(
              child: Container(color: context.nc.scaffoldBg),
            ),
            
            // 2. Ambient Multi-Gradient Aurora (High Intelligence Aesthetic)
            if (context.nc.isDark) ...[
              // Top Right Glow (Indigo)
              Positioned(
                top: -150,
                right: -120,
                child: Container(
                  width: 600,
                  height: 600,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF4F46E5).withValues(alpha: 0.35),
                        const Color(0xFF4F46E5).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              // Center Left Glow (Purple/Rose)
              Positioned(
                top: 150,
                left: -180,
                child: Container(
                  width: 550,
                  height: 550,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFA855F7).withValues(alpha: 0.25),
                        const Color(0xFFA855F7).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom Right Glow (Amber)
              Positioned(
                bottom: -200,
                right: -120,
                child: Container(
                  width: 600,
                  height: 600,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        const Color(0xFFF59E0B).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom Left Glow (Emerald)
              Positioned(
                bottom: 50,
                left: -150,
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF10B981).withValues(alpha: 0.15),
                        const Color(0xFF10B981).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ] else 
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFF8FAFC),
                        Colors.white,
                      ],
                    ),
                  ),
                ),
              ),

            SafeArea(
              child: Column(
                children: [
                  // --- Header ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () {
                              ref.read(navbarVisibleProvider.notifier).show();
                              context.pop();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(LucideIcons.arrowLeft, size: 24, color: context.nc.textPrimary),
                            ),
                          ),
                        ),
                        Text(
                          'Intelligence',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: context.nc.textPrimary,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: PopupMenuButton<String>(
                            icon: Icon(LucideIcons.moreHorizontal, size: 24, color: context.nc.textPrimary),
                            onSelected: (value) {
                              if (value == 'new_chat') {
                                ref.read(chatProvider.notifier).startNewSession();
                              } else if (value == 'history') {
                                context.pushNamed('chat_history');
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'new_chat',
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.plus, size: 18),
                                    SizedBox(width: 12),
                                    Text('New Chat'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'history',
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.history, size: 18),
                                    SizedBox(width: 12),
                                    Text('History'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Message List ---
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: messages.length + (isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          final lastUserMessage = messages.lastWhere((m) => m.isUser, orElse: () => ChatMessage(text: '', isUser: true));
                          return _LoadingBubble(promptContext: lastUserMessage.text);
                        }
                        final message = messages[index];
                        final bool isLastMessage = index == messages.length - 1;
                        final bool isNewMessage = index >= _initialMessageCount;
                        final bool shouldAnimate = isLastMessage && !isLoading && isNewMessage;

                        return _MessageBubble(
                          message: message,
                          messageIndex: index,
                          shouldAnimate: shouldAnimate && !_animatedIndices.contains(index),
                          scrollController: _scrollController,
                          onAnimationComplete: shouldAnimate ? () {
                            _animatedIndices.add(index);
                          } : null,
                          onSaveProtocol: message.attachment is HealthProtocol ? (protocol) async {
                            await ref.read(protocolProvider.notifier).saveGeneratedProtocol(protocol);
                          } : null,
                        );
                      },
                    ),
                  ),

                  // --- Regenerate Button ---
                  if (!isLoading && messages.isNotEmpty && !messages.last.isUser)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(chatProvider.notifier).regenerateLastResponse();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.refreshCw, size: 13, color: context.nc.textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(width: 6),
                            Text(
                              'Regenerate response',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.nc.textSecondary.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // --- Input Area ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Suggestions
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _messageController,
                          builder: (context, value, _) {
                            if (value.text.isNotEmpty || chatState.messages.isNotEmpty || chatState.isLoading) {
                              return const SizedBox.shrink();
                            }
                            final suggestions = ref.watch(suggestionProvider);
                            if (suggestions.isEmpty) return const SizedBox.shrink();
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: suggestions.map((s) => _GlassSuggestionChip(
                                  label: s.label,
                                  icon: s.icon,
                                  onTap: () {
                                    _messageController.text = s.prompt;
                                    _sendMessage();
                                  },
                                )).toList(),
                              ),
                            );
                          },
                        ),
                        
                        // Premium Intelligence Glass Input Box
                        ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: context.nc.isDark 
                                    ? Colors.white.withValues(alpha: 0.04) 
                                    : context.nc.cardSurface.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: context.nc.isDark 
                                      ? Colors.white.withValues(alpha: 0.12) 
                                      : context.nc.cardBorder, 
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  if (context.nc.isDark)
                                    BoxShadow(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_selectedImage != null)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                      child: Row(
                                        children: [
                                          Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.file(_selectedImage!, height: 60, width: 60, fit: BoxFit.cover),
                                              ),
                                              Positioned(
                                                top: -6,
                                                right: -6,
                                                child: GestureDetector(
                                                  onTap: () => setState(() => _selectedImage = null),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(color: context.nc.isDark ? Colors.white : const Color(0xFF1F2937), shape: BoxShape.circle),
                                                    child: Icon(LucideIcons.x, size: 10, color: context.nc.isDark ? Colors.black : Colors.white),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                  TextField(
                                    controller: _messageController,
                                    minLines: 1,
                                    maxLines: 8,
                                    style: GoogleFonts.outfit(
                                      fontSize: 17,
                                      color: context.nc.textPrimary,
                                      height: 1.5,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Ask anything',
                                      hintStyle: GoogleFonts.outfit(color: context.nc.textTertiary, fontSize: 17),
                                      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                                      fillColor: Colors.transparent,
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(10, 0, 12, 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        _GrokActionButton(
                                          icon: LucideIcons.paperclip,
                                          onTap: _pickImage,
                                        ),
                                        const SizedBox(width: 4),
                                        /* _GrokActionButton(
                                          icon: LucideIcons.mic,
                                          onTap: () {
                                            HapticFeedback.mediumImpact();
                                            AdvancedVoiceOverlay.show(context);
                                          },
                                        ), */
                                        const Spacer(),
                                        Consumer(
                                          builder: (context, ref, _) {
                                            final isLoading = ref.watch(chatProvider).isLoading;
                                            return GestureDetector(
                                              onTap: () {
                                                HapticFeedback.mediumImpact();
                                                if (isLoading) {
                                                  ref.read(chatProvider.notifier).cancelCurrentRequest();
                                                } else {
                                                  _sendMessage();
                                                }
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                height: 44,
                                                width: 44,
                                                decoration: BoxDecoration(
                                                  gradient: isLoading 
                                                      ? null 
                                                      : LinearGradient(
                                                          colors: [
                                                            const Color(0xFF4F46E5),
                                                            const Color(0xFF4F46E5).withValues(alpha: 0.8),
                                                          ],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                  color: isLoading ? context.nc.divider.withValues(alpha: 0.5) : null,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    if (!isLoading)
                                                      BoxShadow(
                                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                                                        blurRadius: 12,
                                                        spreadRadius: 1,
                                                      ),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: isLoading
                                                      ? Container(
                                                          width: 14,
                                                          height: 14,
                                                          decoration: BoxDecoration(
                                                            color: context.nc.textPrimary,
                                                            borderRadius: BorderRadius.circular(3),
                                                          ),
                                                        )
                                                      : const Icon(LucideIcons.arrowUp, size: 20, color: Colors.white),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
}
class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final int messageIndex;
  final bool shouldAnimate;
  final ScrollController? scrollController;
  final VoidCallback? onAnimationComplete;
  final Future<void> Function(HealthProtocol)? onSaveProtocol;

  const _MessageBubble({
    required this.message,
    required this.messageIndex,
    this.shouldAnimate = false, 
    this.scrollController,
    this.onAnimationComplete,
    this.onSaveProtocol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final chatState = ref.watch(chatProvider);
    final isGenerating = chatState.isLoading && messageIndex == chatState.messages.length - 1;
    
    if (isUser) {
        // --- USER MESSAGE (Clean Minimalist) ---
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: context.nc.inputFill,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                  ),
                  border: Border.all(color: context.nc.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image thumbnail (vision input)
                    if (message.imagePath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(message.imagePath!),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (message.text.isNotEmpty) const SizedBox(height: 10),
                    ],
                    if (message.text.isNotEmpty)
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 16,
                          color: context.nc.textPrimary,
                          height: 1.5,
                          fontFamily: 'SF Pro Display',
                          letterSpacing: 0.2,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
    } else {
        // --- AI MESSAGE (No Bubble, Text Stream) ---
        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Builder(
                      builder: (context) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...message.blocks.map((block) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildBlock(context, block, shouldAnimate, ref),
                              );
                            }),
                            
                            // Reaction row (thumbs up / down)
                            if (!shouldAnimate && !isGenerating && message.blocks.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 8),
                                child: Row(
                                  children: [
                                    _ReactionButton(
                                      icon: LucideIcons.thumbsUp,
                                      isActive: message.reaction == 'up',
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        ref.read(chatProvider.notifier).reactToMessage(messageIndex, 'up');
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _ReactionButton(
                                      icon: LucideIcons.thumbsDown,
                                      isActive: message.reaction == 'down',
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        ref.read(chatProvider.notifier).reactToMessage(messageIndex, 'down');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildBlock(BuildContext context, MessageBlock block, bool shouldAnimate, WidgetRef ref) {
    if (block is TextBlock) {
      return MarkdownBody(
        data: block.text,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            fontSize: 16,
            color: context.nc.textPrimary,
            height: 1.6,
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
          h1: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: context.nc.textPrimary,
            height: 1.3,
          ),
          h2: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.nc.textPrimary,
            height: 1.3,
          ),
          h3: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.nc.textPrimary,
            height: 1.3,
          ),
          strong: TextStyle(
            fontSize: 16,
            color: context.nc.textPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: 'SF Pro Display',
          ),
          listBullet: TextStyle(
            color: context.nc.textSecondary,
            fontSize: 16,
          ),
          listIndent: 24,
          blockSpacing: 16,
          blockquote: TextStyle(color: context.nc.textSecondary, fontStyle: FontStyle.italic, fontSize: 15),
          blockquoteDecoration: BoxDecoration(
            border: Border(left: BorderSide(width: 3, color: context.nc.divider))
          ),
          code: TextStyle(
            backgroundColor: context.nc.inputFill,
            color: context.nc.textPrimary,
            fontSize: 14,
            fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3
          ),
        ),
      );
    } else if (block is DataCardBlock) {
      return _DataCard(block: block);
    } else if (block is MetricCardBlock) {
      return _MetricCard(block: block);
    } else if (block is SimulationBlock) {
      return SimulationCard(simulation: block.simulation);
    } else if (block is ProtocolBlock) {
      return _ProtocolCard(
        protocol: block.protocol,
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (canvasContext) => ProtocolCanvas(
              protocol: block.protocol,
              onClose: () => Navigator.pop(canvasContext),
              onSave: () async {
                await ref.read(protocolProvider.notifier).saveGeneratedProtocol(block.protocol);
                if (canvasContext.mounted) {
                  Navigator.pop(canvasContext); 
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved as New Protocol")));
                }
              },
            ),
          );
        },
      );
    } else if (block is MealPlanBlock) {
      return _MealPlanCard(
        plan: block.mealPlan,
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (canvasContext) => MealPlanCanvas(
              plan: block.mealPlan,
              onClose: () => Navigator.pop(canvasContext),
              onSave: () async {
                final profile = ref.read(patientProfileProvider).value;
                if (profile != null) {
                  try {
                    await MealRepository.saveGeneratedPlan(profile.id, block.mealPlan);
                    if (canvasContext.mounted) {
                      Navigator.pop(canvasContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Meal plan saved to Your Weekly Menu")),
                      );
                    }
                  } catch (e) {
                    if (canvasContext.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
            ),
          );
        },
      );
    } else if (block is CtaBlock) {
      return ChatCtaStrip(actions: block.actions);
    }
    
    return const SizedBox.shrink();
  }
}

class _DataCard extends StatelessWidget {
  final DataCardBlock block;
  const _DataCard({required this.block});

  Widget _getStatusIcon(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('good') || lowerStatus.contains('excellent') || lowerStatus.contains('optimal')) {
      return const Icon(LucideIcons.checkCircle2, color: Color(0xFF10B981), size: 16);
    } else if (lowerStatus.contains('warning') || lowerStatus.contains('elevated') || lowerStatus.contains('low')) {
      return const Icon(LucideIcons.alertCircle, color: Color(0xFFF59E0B), size: 16);
    } else if (lowerStatus.contains('alert') || lowerStatus.contains('high') || lowerStatus.contains('danger')) {
      return const Icon(LucideIcons.alertTriangle, color: Color(0xFFEF4444), size: 16);
    }
    return const Icon(LucideIcons.info, color: Color(0xFF94A3B8), size: 16);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasVisual = block.rows.any((row) {
      final history = row['history'];
      final trend = row['trend'];
      return (history is List && history.isNotEmpty) || (trend != null);
    });

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.nc.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (block.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Text(
                block.title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.nc.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          
          if (block.title.isNotEmpty)
            Divider(height: 1, color: context.nc.divider),

          // Rows
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Table(
              columnWidths: hasVisual ? const {
                0: FlexColumnWidth(1.4), // Label + Status
                1: FlexColumnWidth(0.8), // Value
                2: FlexColumnWidth(0.8), // Visual (Graph/Trend)
              } : const {
                0: FlexColumnWidth(1.0),
                1: FlexColumnWidth(1.0),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: block.rows.map((row) {
                final List<dynamic>? history = row['history'] is List ? (row['history'] as List) : null;
                final double? trend = double.tryParse(row['trend']?.toString() ?? '');

                return TableRow(
                  children: [
                    // Col 1: Label + Status
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 4, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            row['label']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.nc.textSecondary,
                            ),
                          ),
                          if (row['status'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _getStatusIcon(row['status'].toString()),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    row['status'].toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: context.nc.textTertiary,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Col 2: Value
                    Padding(
                      padding: EdgeInsets.fromLTRB(4, 10, hasVisual ? 4 : 20, 10),
                      child: Text(
                        row['value']?.toString() ?? '',
                        textAlign: hasVisual ? TextAlign.left : TextAlign.right,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.nc.textPrimary,
                        ),
                      ),
                    ),

                    // Col 3: Visual (only if hasVisual is true)
                    if (hasVisual)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 20, 10),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: (history != null && history.isNotEmpty)
                              ? SizedBox(
                                  height: 24,
                                  width: 80,
                                  child: _InlineSparkline(data: history.map((e) => double.tryParse(e.toString()) ?? 0.0).toList()),
                                )
                              : (trend != null)
                                  ? _MiniTrendBar(trend: trend)
                                  : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),

          // Verdict Footer
          if (block.verdict != null && block.verdict!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: context.nc.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                border: Border(top: BorderSide(color: context.nc.divider.withValues(alpha: 0.5))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.info, size: 14, color: context.nc.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      block.verdict!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.nc.textSecondary,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final MetricCardBlock block;
  const _MetricCard({required this.block});

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'optimal': return const Color(0xFF10B981);
      case 'warning': return const Color(0xFFF59E0B);
      case 'alert': return const Color(0xFFEF4444);
      default: return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(block.status);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.nc.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.label,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.nc.textPrimary,
                      ),
                    ),
                    if (block.status != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              block.status!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (block.history != null && block.history!.isNotEmpty)
                SizedBox(
                  width: 100,
                  height: 45,
                  child: _InlineSparkline(
                    data: block.history!,
                    color: statusColor,
                    showDots: true,
                    showGradient: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                block.value,
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              if (block.unit != null) ...[
                const SizedBox(width: 6),
                Text(
                  block.unit!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineSparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final bool showDots;
  final bool showGradient;

  const _InlineSparkline({
    required this.data,
    this.color = const Color(0xFF3B82F6),
    this.showDots = false,
    this.showGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return const SizedBox.shrink();
    
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i]));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: showDots ? 2.5 : 1.5,
            dotData: FlDotData(
              show: showDots,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 3,
                color: context.nc.cardSurface,
                strokeWidth: 2,
                strokeColor: color,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: showGradient 
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withOpacity(0.2),
                      color.withOpacity(0.0),
                    ],
                  )
                : null,
              color: showGradient ? null : color.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTrendBar extends StatelessWidget {
  final double trend;
  const _MiniTrendBar({required this.trend});

  @override
  Widget build(BuildContext context) {
    final clamped = trend.clamp(-20.0, 20.0);
    final percent = (clamped / 20.0).abs();
    final color = trend >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      height: 4,
      width: 40,
      decoration: BoxDecoration(
        color: context.nc.inputFill,
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: trend >= 0 ? Alignment.centerLeft : Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: percent.clamp(0.1, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Small thumbs up/down reaction button
class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ReactionButton({required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isActive ? (context.nc.isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF3B82F6).withValues(alpha: 0.1)) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isActive ? (context.nc.isDark ? Colors.white : const Color(0xFF3B82F6)) : context.nc.textTertiary,
        ),
      ),
    );
  }
}



class _LoadingBubble extends StatefulWidget {
  final String promptContext;
  
  const _LoadingBubble({required this.promptContext});

  @override
  State<_LoadingBubble> createState() => _LoadingBubbleState();
}

class _LoadingBubbleState extends State<_LoadingBubble> {
  late final List<String> _phrases;
  
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _phrases = _generatePhrases(widget.promptContext);
    
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted) {
        setState(() {
          if (_currentIndex < _phrases.length - 1) {
            _currentIndex++;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }
  
  List<String> _generatePhrases(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    
    if (lowerPrompt.contains('protocol') || lowerPrompt.contains('plan') || lowerPrompt.contains('routine')) {
      return [
        "Analyzing health profile...",
        "Evaluating biomedical variables...",
        "Cross-referencing longevity literature...",
        "Synthesizing protocol...",
      ];
    }
    
    if (lowerPrompt.contains('simulate') || lowerPrompt.contains('twin') || lowerPrompt.contains('predict') || lowerPrompt.contains('impact')) {
      return [
        "Initializing digital twin...",
        "Running metabolic permutations...",
        "Extrapolating long-term outcomes...",
        "Finalizing simulation...",
      ];
    }
    
    return [
      "Analyzing context...",
      "Querying wellness intelligence...",
      "Structuring recommendations...",
      "Synthesizing response...",
    ];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.nc.isDark ? Colors.white.withValues(alpha: 0.05) : context.nc.inputFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.nc.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(width: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _phrases[_currentIndex],
                    key: ValueKey<int>(_currentIndex),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.nc.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// --- End of Header Customization ---


// ... existing imports ...

// Add this class at the bottom of the file


// Extension to easily blur containers
extension BlurExtension on Widget {
   Widget blur(double sigma) {
     return ImageFiltered(
       imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
       child: this,
     );
   }
}

class _GlassSuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GlassSuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.nc.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.nc.cardBorder),
          boxShadow: [
             BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
             )
          ]
        ),
        child: Text(
          label,
          style: TextStyle(
            color: context.nc.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFamily: 'SF Pro Display',
          ),
        ),
      ),
    );
  }
}


class _ProtocolCard extends StatelessWidget {
  final HealthProtocol protocol;
  final VoidCallback onTap;

  const _ProtocolCard({required this.protocol, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.nc.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.nc.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  LucideIcons.fileText,
                  size: 100,
                  color: context.nc.isDark 
                      ? Colors.white.withValues(alpha: 0.03) 
                      : Colors.black.withValues(alpha: 0.02),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(LucideIcons.fileText, size: 24, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            protocol.title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700, 
                              fontSize: 17, 
                              color: context.nc.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                "Protocol Document",
                                style: TextStyle(
                                  fontSize: 13, 
                                  fontWeight: FontWeight.w500,
                                  color: context.nc.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: context.nc.textTertiary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "AI Generated",
                                style: TextStyle(
                                  fontSize: 13, 
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, color: context.nc.textTertiary, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealPlanCard extends StatelessWidget {
  final MealPlan plan;
  final VoidCallback onTap;

  const _MealPlanCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Calculate average daily calories
    int avgCalories = 0;
    if (plan.weeklyPlan.isNotEmpty) {
      int sum = 0;
      for (final day in plan.weeklyPlan) {
        for (final meal in day.meals) {
          sum += meal.calories;
        }
      }
      avgCalories = (sum / plan.weeklyPlan.length).round();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.nc.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: const Color(0xFF10B981).withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.utensils, size: 22, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.nc.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${plan.weeklyPlan.length} days · ~$avgCalories kcal/day",
                    style: TextStyle(fontSize: 13, color: context.nc.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}





class _GrokActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GrokActionButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: context.nc.isDark ? Colors.white.withValues(alpha: 0.05) : context.nc.inputFill,
          shape: BoxShape.circle,
          border: Border.all(
            color: context.nc.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: context.nc.textSecondary,
        ),
      ),
    );
  }
}

// Duplicate _LoadingBubble removed. Using original phrases version above.
