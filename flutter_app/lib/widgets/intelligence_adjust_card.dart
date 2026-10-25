import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/rhythm_provider.dart';
import '../providers/purchase_provider.dart';
import '../screens/settings/paywall_screen.dart';
import '../config/theme.dart';

/// A premium, high-impact trigger for Intelligence Adapt.
/// - Version 3: Supreme Gradient Typography.
/// - Signals strong AI capabilities via the signature Siri-style gradient.
class IntelligenceAdjustCard extends ConsumerWidget {
  const IntelligenceAdjustCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rhythmState = ref.watch(dailyRhythmProvider);
    final isPlus = ref.watch(purchaseProvider).isPlus;
    final isAdjusting = rhythmState.isAdjusting;
    final isAdjusted = rhythmState.isAdjusted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // The Label - Gradient Typography (Version 3 Supreme)
          _buildGradientText(
            isAdjusting 
                ? 'Optimizing Blueprint...' 
                : (isAdjusted ? "Today's Blueprint" : 'Optimize Blueprint'),
            isAdjusted: isAdjusted,
            isAdjusting: isAdjusting,
          ),

          // The Actions
          if (!isAdjusting && !isAdjusted)
            // The Manual Adjust Button
            GestureDetector(
              onTap: () async {
                if (isPlus) {
                  HapticFeedback.heavyImpact();
                  try {
                    await ref.read(dailyRhythmProvider.notifier).intelligenceAdjust();
                  } catch (e) {
                     if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
                           content: Text(e.toString().replaceAll('Exception: ', '')),
                           behavior: SnackBarBehavior.floating,
                           backgroundColor: const Color(0xFF1E293B),
                         ),
                       );
                     }
                  }
                } else {
                  HapticFeedback.lightImpact();
                  PaywallScreen.show(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Adjust',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          
          if (isAdjusted)
             Row(
               children: [
                 const Text(
                   'Adapted',
                   style: TextStyle(
                     fontSize: 13,
                     fontWeight: FontWeight.w800,
                     color: Color(0xFF10B981),
                   ),
                 ),
                 const SizedBox(width: 6),
                 const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF10B981)),
               ],
             ),
             
          if (isAdjusting)
             const SizedBox(
               width: 16, height: 16, 
               child: CircularProgressIndicator(
                 strokeWidth: 2, 
                 valueColor: AlwaysStoppedAnimation(Color(0xFFA855F7))
               )
             ),
        ],
      ),
    );
  }

  /// High-fidelity gradient text for a strong, premium presence.
  Widget _buildGradientText(String text, {required bool isAdjusted, required bool isAdjusting}) {
    final style = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.4,
      color: Colors.white, // Color doesn't matter, overridden by Shader
    );

    if (isAdjusted) {
      return Text(
        text,
        style: style.copyWith(color: const Color(0xFF10B981)),
      );
    }

    // Siri Gradient (Supreme Style)
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFFF59E0B), // Amber
          Color(0xFFA855F7), // Purple
          Color(0xFF3B82F6), // Blue
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(text, style: style),
    );
  }
}
