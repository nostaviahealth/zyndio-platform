import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/chat_provider.dart';
import '../../models/chat_session.dart';
import '../../widgets/tc025/tc025_widgets.dart';

class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(chatHistoryProvider);
    final c = Theme.of(context).extension<ZyndioColors>()!;

    return ZyndioDetailScaffold(
      title: 'History',
      onBack: () => context.pop(),
      body: historyAsync.when(
        data: (sessions) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          itemCount: sessions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _HistoryCard(session: sessions[index]);
          },
        ),
        loading: () =>
            Center(child: CircularProgressIndicator(color: c.brandPrimary)),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Error: $err',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: ZyndioType.family,
                fontSize: 15,
                color: c.statusCritical,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  final ChatSession session;

  const _HistoryCard({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Container(
      decoration: zyndioCard(context, radius: 22),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () async {
            // Load the selected session
            await ref.read(chatProvider.notifier).loadSession(session.id);
            // Navigate to chat screen
            if (context.mounted) {
              context.pushNamed('chat');
            }
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              session.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: ZyndioType.family,
                                fontSize: 16,
                                height: 22 / 16,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(session.date),
                            style: TextStyle(
                              fontFamily: ZyndioType.family,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: c.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.lastMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontSize: 14,
                          height: 20 / 14,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronRight, size: 20, color: c.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${date.month}/${date.day}';
  }
}
