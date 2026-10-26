import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/chat_provider.dart';
import '../../config/theme.dart';

/// Renders a horizontal strip of tappable CTA action chips below an AI message.
class ChatCtaStrip extends StatelessWidget {
  final List<CtaAction> actions;

  const ChatCtaStrip({super.key, required this.actions});

  IconData _iconForAction(String action) {
    switch (action) {
      case 'navigate_to_meal_log':
        return LucideIcons.utensils;
      case 'navigate_to_upload':
        return LucideIcons.upload;
      case 'navigate_to_protocol':
        return LucideIcons.clipboardList;
      case 'navigate_to_wearables':
        return LucideIcons.watch;
      default:
        return LucideIcons.arrowRight;
    }
  }

  void _handleTap(BuildContext context, String action) {
    HapticFeedback.lightImpact();
    switch (action) {
      case 'navigate_to_meal_log':
        context.push('/food-log');
        break;
      case 'navigate_to_upload':
        context.push('/health_data/upload');
        break;
      case 'navigate_to_protocol':
        context.push('/protocol');
        break;
      case 'navigate_to_wearables':
        context.push('/wearables');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions.map((action) {
          return GestureDetector(
            onTap: () => _handleTap(context, action.action),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: context.nc.primary.withOpacity(0.1), // Light blue tint
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.nc.primary.withOpacity(0.3), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: context.nc.primary.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconForAction(action.action),
                    size: 14,
                    color: context.nc.primary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.nc.primary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
