import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class AIConsentService {
  String _getConsentKey(String userId) => 'ai_consent_$userId';

  Future<bool> hasConsented(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_getConsentKey(userId)) ?? false;
  }

  Future<void> saveConsent(String userId, bool consented) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_getConsentKey(userId), consented);
  }
}

final aiConsentServiceProvider = Provider<AIConsentService>((ref) {
  return AIConsentService();
});

final aiConsentProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return false;
  
  final service = ref.watch(aiConsentServiceProvider);
  return await service.hasConsented(userId);
});
