import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/daily_feed_provider.dart';
import '../../providers/timeline_view_provider.dart';
import '../home/widgets/daily_feed_card.dart';
import '../home/widgets/swipeable_timeline.dart';

/// Standalone screen for viewing the historical Daily Feed / Health Timeline.
/// Migrated from the Home screen tab to Settings.
class TimelineHistoryScreen extends ConsumerWidget {
  const TimelineHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(dailyFeedProvider);

    return Scaffold(
      backgroundColor: BrandColors.background,
      appBar: AppBar(
        title: const Text('Timeline'),
        backgroundColor: BrandColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          // View Toggle (Swipe vs List)
          Consumer(builder: (context, ref, _) {
            final isSwipe = ref.watch(timelineViewProvider);
            return IconButton(
              icon: Icon(isSwipe ? LucideIcons.list : LucideIcons.layers),
              onPressed: () => ref.read(timelineViewProvider.notifier).toggleView(),
              tooltip: isSwipe ? 'Switch to List' : 'Switch to Swipe',
            );
          }),
        ],
      ),
      body: feedAsync.when(
        data: (days) {
          if (days.isEmpty) {
            return _buildEmptyState();
          }

          final isSwipeMode = ref.watch(timelineViewProvider);

          if (isSwipeMode) {
            return SwipeableTimeline(snapshots: days);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: days.length,
            itemBuilder: (context, index) => DailyFeedCard(snapshot: days[index]),
          );
        },
        loading: () => _buildLoadingState(),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 64, color: Color(0xFFCBD5E1)),
          SizedBox(height: 24),
          Text(
            'Your health timeline will appear here',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          SizedBox(height: 12),
          Text(
            'Connect your wearable to unlock daily health summaries, bio-impact analysis, and historical trends.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3, color: BrandColors.emerald500),
          ),
          SizedBox(height: 16),
          Text(
            'Building your health journey...',
            style: TextStyle(fontSize: 14, color: BrandColors.slate500, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
