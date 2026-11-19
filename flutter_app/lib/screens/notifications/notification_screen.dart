import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../models/notification_model.dart';
import '../../models/alert_model.dart';
import '../../providers/notification_provider.dart';
import '../../providers/alert_provider.dart';
import '../../widgets/tc025/tc025_widgets.dart';

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
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final z = context.z25;

    return ZyndioDetailScaffold(
      title: 'Notifications',
      onBack: () => context.pop(),
      trailing: TextButton(
        onPressed: () {
          ref.read(notificationsProvider.notifier).markAllAsRead();
          ref.read(alertProvider.notifier).clearHistory();
        },
        style: TextButton.styleFrom(
          foregroundColor: c.brandPrimary,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const StadiumBorder(),
        ),
        child: Text(
          'Clear all',
          style: TextStyle(
            fontFamily: ZyndioType.family,
            color: c.brandPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: z.segmentBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: ZyndioGradients.segmentActive,
                  borderRadius: BorderRadius.circular(999),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: z.segmentText,
                labelStyle: const TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                dividerColor: Colors.transparent,
                splashBorderRadius: BorderRadius.circular(999),
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: [
                  Tab(text: 'Activity (${alertHistory.length})'),
                  Tab(text: unreadCount > 0 ? 'Inbox ($unreadCount)' : 'Inbox'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: In-App Alert History (this session)
                _buildAlertHistoryTab(alertHistory),

                // Tab 2: Supabase Notifications (persisted)
                _buildInboxTab(notificationsAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _listPadding = EdgeInsets.fromLTRB(20, 12, 20, 40);

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
      padding: _listPadding,
      itemCount: alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return _AlertHistoryCard(alert: alert);
      },
    );
  }

  // ── TAB 2: INBOX ──

  Widget _buildInboxTab(AsyncValue<List<NotificationItem>> notificationsAsync) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
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
          padding: _listPadding,
          itemCount: notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _NotificationCard(notification: notification);
          },
        );
      },
      loading: () =>
          Center(child: CircularProgressIndicator(color: c.brandPrimary)),
      error: (err, stack) => ListView(
        padding: _listPadding,
        children: [
          ZyndioCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.statusCriticalSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.alertCircle,
                      size: 20, color: c.statusCritical),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Could not load inbox',
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
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

  // ── EMPTY STATE ──

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListView(
      padding: _listPadding,
      children: [
        ZyndioStateCard(icon: icon, title: title, body: subtitle),
      ],
    );
  }
}

// ─── SHARED ROW PIECES ──────────────────────────────────────────────────────

String _formatTimeAgo(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

ZyndioTint _alertTint(AlertCategory category) => switch (category) {
      AlertCategory.protocol => ZyndioTint.blue,
      AlertCategory.insight => ZyndioTint.violet,
      AlertCategory.achievement => ZyndioTint.amber,
      AlertCategory.warning => ZyndioTint.rose,
      AlertCategory.system => ZyndioTint.green,
    };

(IconData, ZyndioTint) _notificationIcon(NotificationType type) =>
    switch (type) {
      NotificationType.info => (LucideIcons.info, ZyndioTint.blue),
      NotificationType.success => (LucideIcons.checkCircle, ZyndioTint.green),
      NotificationType.warning => (LucideIcons.alertTriangle, ZyndioTint.amber),
      NotificationType.error => (LucideIcons.alertCircle, ZyndioTint.rose),
      NotificationType.protocol =>
        (LucideIcons.clipboardCheck, ZyndioTint.indigo),
      NotificationType.alert => (LucideIcons.bell, ZyndioTint.violet),
    };

/// Icon tile + title/time row + body, shared by both notification cards.
class _NotificationRowContent extends StatelessWidget {
  const _NotificationRowContent({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
    required this.time,
    this.unread = false,
    this.boldTitle = true,
  });

  final IconData icon;
  final ZyndioTint tint;
  final String title;
  final String body;
  final String time;
  final bool unread;
  final bool boldTitle;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZyndioIconTile(icon: icon, tint: tint, size: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 16,
                        height: 22 / 16,
                        fontWeight:
                            boldTitle ? FontWeight.w700 : FontWeight.w600,
                        color: c.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.textTertiary,
                    ),
                  ),
                  if (unread) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 14,
                  height: 20 / 14,
                  color: c.textSecondary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── ALERT HISTORY CARD ─────────────────────────────────────────────────────

class _AlertHistoryCard extends StatelessWidget {
  final AppAlert alert;

  const _AlertHistoryCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return ZyndioCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        if (alert.actionRoute != null) {
          context.push(alert.actionRoute!);
        }
      },
      child: _NotificationRowContent(
        icon: AlertVisualConfig.fromCategory(alert.category).icon,
        tint: _alertTint(alert.category),
        title: alert.title,
        body: alert.message,
        time: _formatTimeAgo(alert.timestamp),
      ),
    );
  }
}

// ─── NOTIFICATION CARD (Supabase) ───────────────────────────────────────────

class _NotificationCard extends ConsumerWidget {
  final NotificationItem notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final (icon, tint) = _notificationIcon(notification.type);
    return ZyndioCard(
      padding: const EdgeInsets.all(16),
      // Unread rows sit on the soft brand tint; read rows on the plain surface.
      color: notification.isRead ? null : c.brandSubtle,
      onTap: () {
        if (!notification.isRead) {
          ref.read(notificationsProvider.notifier).markAsRead(notification.id);
        }
        if (notification.actionRoute != null) {
          context.push(notification.actionRoute!);
        }
      },
      child: _NotificationRowContent(
        icon: icon,
        tint: tint,
        title: notification.title,
        body: notification.body,
        time: _formatTimeAgo(notification.timestamp),
        unread: !notification.isRead,
        boldTitle: !notification.isRead,
      ),
    );
  }
}
