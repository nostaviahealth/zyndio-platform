import 'package:flutter/foundation.dart';
import '../../config/supabase_config.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  static const String _table = 'notifications';

  /// Fetch notifications for the current user
  Future<List<NotificationItem>> getNotifications() async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) return [];

      final client = SupabaseConfig.client;
      if (client == null) return [];

      final data = await client
          .from(_table)
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (data as List).map((e) => NotificationItem.fromJson(e)).toList();
    } catch (e) {
      // If table doesn't exist yet, return empty list gracefully
      return [];
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final client = SupabaseConfig.client;
      if (client == null) return;

      await client
          .from(_table)
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      // Handle error cleanly
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) return;

      final client = SupabaseConfig.client;
      if (client == null) return;

      await client
          .from(_table)
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      // Handle error cleanly
    }
  }

  /// Create a new notification in the database
  Future<void> createNotification(NotificationItem item) async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) return;

      final client = SupabaseConfig.client;
      if (client == null) return;

      await client.from(_table).insert({
        'user_id': user.id,
        'title': item.title,
        'body': item.body,
        'type': item.type.toString().split('.').last,
        'is_read': false,
        'action_route': item.actionRoute,
        'created_at': item.timestamp.toIso8601String(),
        if (item.metadata != null) 'metadata': item.metadata,
      });
      debugPrint('✅ Persisted notification to inbox: ${item.title}');
    } catch (e) {
      debugPrint('❌ Error persisting notification: $e');
    }
  }
}
