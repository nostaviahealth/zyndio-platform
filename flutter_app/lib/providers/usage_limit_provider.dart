import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import 'purchase_provider.dart';

// ─── Limits ─────────────────────────────────────────────────────────────────
const int kLensScansPerDay = 3;
const int kChatMessagesPerDay = 10;
const int kProtocolGenerationsPerMonth = 2;

// ─── State ───────────────────────────────────────────────────────────────────
class UsageLimitState {
  final int lensScansToday;
  final int chatMessagesToday;
  final int protocolGenerationsThisMonth;
  final bool isLoaded;

  const UsageLimitState({
    this.lensScansToday = 0,
    this.chatMessagesToday = 0,
    this.protocolGenerationsThisMonth = 0,
    this.isLoaded = false,
  });

  bool get canScan => lensScansToday < kLensScansPerDay;
  bool get canChat => chatMessagesToday < kChatMessagesPerDay;
  bool get canGenerateProtocol => protocolGenerationsThisMonth < kProtocolGenerationsPerMonth;

  int get lensScansRemaining => (kLensScansPerDay - lensScansToday).clamp(0, kLensScansPerDay);
  int get chatMessagesRemaining => (kChatMessagesPerDay - chatMessagesToday).clamp(0, kChatMessagesPerDay);

  UsageLimitState copyWith({
    int? lensScansToday,
    int? chatMessagesToday,
    int? protocolGenerationsThisMonth,
    bool? isLoaded,
  }) {
    return UsageLimitState(
      lensScansToday: lensScansToday ?? this.lensScansToday,
      chatMessagesToday: chatMessagesToday ?? this.chatMessagesToday,
      protocolGenerationsThisMonth: protocolGenerationsThisMonth ?? this.protocolGenerationsThisMonth,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────
class UsageLimitNotifier extends Notifier<UsageLimitState> {
  @override
  UsageLimitState build() {
    // Load on build
    Future.microtask(() => _loadUsage());
    return const UsageLimitState();
  }

  Future<void> _loadUsage() async {
    final client = SupabaseConfig.client;
    final userId = SupabaseConfig.currentUser?.id;
    if (client == null || userId == null) return;

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toUtc();
      final monthStart = DateTime(now.year, now.month, 1).toUtc();

      // Fetch all today's and this month's events in a single query
      final response = await client
          .from('usage_logs')
          .select('event_type, created_at')
          .eq('user_id', userId)
          .gte('created_at', monthStart.toIso8601String());

      final logs = response as List;

      int lens = 0;
      int chat = 0;
      int protocol = 0;

      for (final log in logs) {
        final eventType = log['event_type'] as String;
        final createdAt = DateTime.parse(log['created_at'] as String).toLocal();
        final isToday = !createdAt.isBefore(todayStart.toLocal());

        if (eventType == 'lens_scan' && isToday) lens++;
        if (eventType == 'chat_message' && isToday) chat++;
        if (eventType == 'protocol_generation') protocol++;
      }

      state = state.copyWith(
        lensScansToday: lens,
        chatMessagesToday: chat,
        protocolGenerationsThisMonth: protocol,
        isLoaded: true,
      );
    } catch (e) {
      // On error, allow usage (fail open)
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> _logEvent(String eventType) async {
    final client = SupabaseConfig.client;
    final userId = SupabaseConfig.currentUser?.id;
    if (client == null || userId == null) return;

    try {
      // Log to Supabase (existing)
      await client.from('usage_logs').insert({
        'user_id': userId,
        'event_type': eventType,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // Silent fail — don't block UX
    }
  }

  void incrementLensScans() {
    state = state.copyWith(lensScansToday: state.lensScansToday + 1);
    _logEvent('lens_scan');
  }

  void incrementChat() {
    state = state.copyWith(chatMessagesToday: state.chatMessagesToday + 1);
    _logEvent('chat_message');
  }

  void incrementProtocolGenerations() {
    state = state.copyWith(protocolGenerationsThisMonth: state.protocolGenerationsThisMonth + 1);
    _logEvent('protocol_generation');
  }

  /// Force a fresh reload from Supabase
  Future<void> refresh() => _loadUsage();
}

final usageLimitProvider = NotifierProvider<UsageLimitNotifier, UsageLimitState>(() {
  return UsageLimitNotifier();
});

/// Convenience: returns true if the user can perform an action OR is Plus
final canScanLensProvider = Provider<bool>((ref) {
  final isPlus = ref.watch(purchaseProvider).isPlus;
  if (isPlus) return true;
  return ref.watch(usageLimitProvider).canScan;
});

final canSendChatProvider = Provider<bool>((ref) {
  final isPlus = ref.watch(purchaseProvider).isPlus;
  if (isPlus) return true;
  return ref.watch(usageLimitProvider).canChat;
});

final canGenerateProtocolProvider = Provider<bool>((ref) {
  final isPlus = ref.watch(purchaseProvider).isPlus;
  if (isPlus) return true;
  return ref.watch(usageLimitProvider).canGenerateProtocol;
});
