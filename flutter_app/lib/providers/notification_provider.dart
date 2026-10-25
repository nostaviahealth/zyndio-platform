import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../data/notification_repository.dart';

// Repository Provider
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

// Notifications State (AsyncList)
final notificationsProvider = NotifierProvider<NotificationNotifier, AsyncValue<List<NotificationItem>>>(() {
  return NotificationNotifier();
});

class NotificationNotifier extends Notifier<AsyncValue<List<NotificationItem>>> {
  bool _hasLoaded = false;

  @override
  AsyncValue<List<NotificationItem>> build() {
    // Only fetch once — refresh() handles subsequent reloads explicitly.
    if (!_hasLoaded) {
      _hasLoaded = true;
      _loadNotifications();
      return const AsyncValue.loading();
    }
    
    // Safety check: Avoid reading 'state' if uninitialized
    try {
      return state;
    } catch (_) {
      return const AsyncValue.loading();
    }
  }

  NotificationRepository get _repository => ref.read(notificationRepositoryProvider);

  Future<void> _loadNotifications() async {
    try {
      final notifications = await _repository.getNotifications();
      state = AsyncValue.data(notifications);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadNotifications();
  }

  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
    
    // Optimistic update
    state = state.whenData((notifications) {
      return notifications.map((n) {
        if (n.id == id) {
          return NotificationItem(
            id: n.id,
            title: n.title,
            body: n.body,
            timestamp: n.timestamp,
            isRead: true, // Mark read locally
            type: n.type,
            actionRoute: n.actionRoute,
            metadata: n.metadata,
          );
        }
        return n;
      }).toList();
    });
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    await refresh(); // Full refresh to be safe
  }
}

// Unread Count Provider
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(notificationsProvider);
  return notificationsAsync.maybeWhen(
    data: (notifications) => notifications.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});
