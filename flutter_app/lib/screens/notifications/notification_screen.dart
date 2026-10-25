import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../models/notification_model.dart';
import '../../models/alert_model.dart';
import '../../providers/notification_provider.dart';
import '../../providers/alert_provider.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final alertHistory = ref.watch(alertHistoryProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(
            color: context.nc.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: context.nc.scaffoldBg,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: context.nc.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(notificationsProvider.notifier).markAllAsRead();
              ref.read(alertProvider.notifier).clearHistory();
            },
            child: const Text(
              'Clear all',
              style: TextStyle(
                color: BrandColors.emerald500,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.nc.divider, width: 0.5)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 2,
              labelColor: Colors.white,
              unselectedLabelColor: context.nc.textTertiary,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: 'Activity (${alertHistory.length})'),
                Tab(text: unreadCount > 0 ? 'Inbox ($unreadCount)' : 'Inbox'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: In-App Alert History (this session)
          _buildAlertHistoryTab(alertHistory),

          // Tab 2: Supabase Notifications (persisted)
          _buildInboxTab(notificationsAsync),
        ],
      ),
    );
  }

  // ── TAB 1: ALERT HISTORY ──

  Widget _buildAlertHistoryTab(List<AppAlert> alerts) {
    if (alerts.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.bellOff,
        title: 'No alerts yet',
        subtitle: 'Alerts from this session will appear here',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return _AlertHistoryCard(alert: alert);
      },
    );
  }

  // ── TAB 2: INBOX ──

  Widget _buildInboxTab(AsyncValue<List<NotificationItem>> notificationsAsync) {
    return notificationsAsync.when(
      data: (notifications) {
        if (notifications.isEmpty) {
          return _buildEmptyState(
            icon: LucideIcons.inbox,
            title: 'Inbox empty',
            subtitle: 'You have no messages',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _NotificationCard(notification: notification);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.alertCircle, size: 40, color: context.nc.textTertiary),
            const SizedBox(height: 12),
            Text('Could not load inbox', style: TextStyle(color: context.nc.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── EMPTY STATE ──

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.nc.cardSurface,
              shape: BoxShape.circle,
              border: Border.all(color: context.nc.cardBorder),
            ),
            child: Icon(icon, size: 40, color: context.nc.textTertiary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.nc.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: context.nc.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ─── ALERT HISTORY CARD ─────────────────────────────────────────────────────

class _AlertHistoryCard extends StatelessWidget {
  final AppAlert alert;

  const _AlertHistoryCard({required this.alert});

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: () {
        if (alert.actionRoute != null) {
          context.push(alert.actionRoute!);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.nc.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.nc.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                  child: Text(
                    alert.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.nc.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatTime(alert.timestamp),
                  style: TextStyle(fontSize: 11, color: context.nc.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              alert.message,
              style: TextStyle(
                fontSize: 13,
                color: context.nc.textSecondary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── NOTIFICATION CARD (Supabase) ───────────────────────────────────────────

class _NotificationCard extends ConsumerWidget {
  final NotificationItem notification;

  const _NotificationCard({required this.notification});

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return BrandColors.emerald500;
      case NotificationType.error:
        return Colors.redAccent;
      case NotificationType.warning:
        return Colors.amber;
      case NotificationType.alert:
        return Colors.orangeAccent;
      case NotificationType.protocol:
        return BrandColors.blue500;
      case NotificationType.info:
        return BrandColors.slate400;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          ref.read(notificationsProvider.notifier).markAsRead(notification.id);
        }
        if (notification.actionRoute != null) {
          context.push(notification.actionRoute!);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: notification.isRead ? context.nc.cardSurface : context.nc.cardSurfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead
                ? context.nc.cardBorder
                : Colors.white.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                  child: Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                      color: context.nc.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: BrandColors.blue500,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              notification.body,
              style: TextStyle(
                fontSize: 13,
                color: context.nc.textSecondary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              _formatTime(notification.timestamp),
              style: TextStyle(fontSize: 11, color: context.nc.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
