import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/patient_profile.dart';
import 'auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raised by the profile notifier when a client-supplied value exceeds the
/// TC-030 item 3 size limits (avatar <= 2 MB and an image type; display name
/// <= 80 characters). The UI catches it and shows the message; the DB CHECK
/// constraints (20261102163000_tc030_patient_accounts_size_limits.sql) are the
/// backstop behind this client-side guard.
class ProfileValidationException implements Exception {
  ProfileValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

final patientProfileProvider = AsyncNotifierProvider<PatientProfileNotifier, PatientProfile?>(() {
  return PatientProfileNotifier();
});

class PatientProfileNotifier extends AsyncNotifier<PatientProfile?> {
  /// Max avatar payload the client will upload (TC-030 item 3): 2 MB of raw
  /// image bytes, matched by the DB avatar_url length cap once base64-encoded.
  static const int maxAvatarBytes = 2 * 1024 * 1024;

  /// Max display-name length (TC-030 item 3), mirroring the DB
  /// patient_accounts_name_len CHECK and the edit-profile field's maxLength.
  static const int maxDisplayNameLength = 80;

  /// Best-effort image MIME lookup from a file name when the picker did not
  /// supply one (TC-030 item 3). Returns null for names we can't classify as an
  /// image, so the caller treats them as "not an image" and rejects the upload.
  static String? _guessImageMimeType(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    switch (name.substring(dot + 1).toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'bmp':
        return 'image/bmp';
      default:
        return null;
    }
  }
  /// patient_accounts has no `id`/`email` columns of its own (it's keyed
  /// directly off auth.users via `patient_id`) - fold those in from the
  /// signed-in user before handing the row to PatientProfile.fromJson,
  /// which still expects the flat `profiles`-shaped keys.
  static PatientProfile _profileFromAccountRow(Map<String, dynamic> row, User user) {
    final json = Map<String, dynamic>.from(row);
    json['id'] = user.id;
    json['user_id'] = row['patient_id'];
    json['email'] ??= user.email;
    return PatientProfile.fromJson(json);
  }

  @override
  Future<PatientProfile?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null; // No user, no profile

    // We can't rely on SupabaseConfig.client for build time if not initialized
    // but usually user != null means auth IS initialized.

    PatientProfile? profile;
    RealtimeChannel? subscription;

    ref.onDispose(() {
      subscription?.unsubscribe();
    });

    // 1. Try to Fetch from Supabase (Best Effort)
    try {
      final client = SupabaseConfig.client;
      if (client != null) {
        // Setup Realtime listener for Admin Overrides
        subscription = client.channel('public:patient_accounts:${user.id}').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'patient_accounts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'patient_id',
            value: user.id,
          ),
          callback: (payload) {
             print('DEBUG: Supabase Realtime profile change: ${payload.newRecord}');
             var newProfile = _profileFromAccountRow(payload.newRecord, user);
             newProfile = _enforceAdminExpiry(newProfile, client);
             state = AsyncData(newProfile);
          }
        ).subscribe();

        final response = await client
            .from('patient_accounts')
            .select()
            .eq('patient_id', user.id)
            .maybeSingle();

        if (response != null) {
          profile = _profileFromAccountRow(response, user);
          profile = _enforceAdminExpiry(profile, client);
        }
      }
    } catch (e) {
      print('DEBUG: Error fetching profile from Supabase: $e');
      // Continue to local fallback
    }

    // 2. If no profile found (or error), create a transient one base on Auth
    if (profile == null) {
      print('DEBUG: Using transient profile fallback');
      profile = PatientProfile(
        id: 'transient',
        userId: user.id,
        name: user.userMetadata?['name'] ?? 'User',
        email: user.email,
        // Default age if not known
        age: 30, 
      );
    }

    // 3. Apply Local Overrides (The core requirement: Local edits win)
    try {
      final prefs = await SharedPreferences.getInstance();
      final localName = prefs.getString('local_profile_name_${user.id}');
      final localAge = prefs.getInt('local_profile_age_${user.id}');
      final localOrg = prefs.getString('local_profile_organization_${user.id}');

      if (localName != null || localAge != null || localOrg != null) {
        print('DEBUG: Applying local overrides - Name: $localName, Age: $localAge, Org: $localOrg');
        profile = profile.copyWith(
          name: localName ?? profile.name,
          age: localAge ?? profile.age,
          organization: localOrg ?? profile.organization,
        );
      }
    } catch (e) {
      print('DEBUG: Error reading SharedPreferences: $e');
    }

    // 4. Social Auth Avatar Sync (If no custom avatar set)
    if (profile!.avatarUrl == null || profile.avatarUrl!.isEmpty) {
        final socialAvatar = user.userMetadata?['avatar_url'] ?? 
                            user.userMetadata?['picture'] ?? 
                            user.userMetadata?['avatarUrl'];
        if (socialAvatar != null) {
            print('DEBUG: Syncing avatar from social provider: $socialAvatar');
            profile = profile.copyWith(avatarUrl: socialAvatar);
            
            // Background sync back to DB if it's currently null there
            final client = SupabaseConfig.client;
            if (client != null) {
              client.from('patient_accounts').upsert(
                {'patient_id': user.id, 'avatar_url': socialAvatar},
                onConflict: 'patient_id',
              ).then((_) {
                print('DEBUG: Successfully synced social avatar to DB');
              }).catchError((e) => print('DEBUG: Social avatar sync failed: $e'));
            }
        }
    }

    return profile;
  }

  /// Converts image to Base64 and updates profile (Zero-Config approach)
  Future<void> updateAvatar(XFile file) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // TC-030 item 3: reject a non-image or an over-2 MB file before it is ever
    // encoded or uploaded. These checks run ahead of the Supabase client lookup
    // so they hold even when the client is unconfigured (and are unit-testable).
    final mimeType = file.mimeType ?? _guessImageMimeType(file.name);
    if (mimeType == null || !mimeType.startsWith('image/')) {
      throw ProfileValidationException('Profile photo must be an image file.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxAvatarBytes) {
      throw ProfileValidationException('Profile photo must be 2 MB or smaller.');
    }

    try {
      final client = SupabaseConfig.client;
      if (client == null) return;

      // Prefix with data URI so UI knows how to handle it
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      // 1. Update Profile Table directly with Base64 string
      await client.from('patient_accounts').upsert(
        {'patient_id': user.id, 'avatar_url': base64String},
        onConflict: 'patient_id',
      );

      // 2. Update Local State
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(avatarUrl: base64String));
      }
      
      print('DEBUG: Profile photo updated successfully via Base64');
    } catch (e) {
      print('DEBUG: Error updating avatar: $e');
      rethrow;
    }
  }

  /// Updates profile locally immediately, and attempts to sync to Supabase in background.
  Future<void> updateProfile({String? name, int? age, String? organization}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // TC-030 item 3: reject an over-80-character display name before it touches
    // local state or the DB (whose patient_accounts_name_len CHECK is the
    // backstop). Runs ahead of the Supabase lookup so it is unit-testable.
    if (name != null && name.runes.length > maxDisplayNameLength) {
      throw ProfileValidationException(
        'Name must be $maxDisplayNameLength characters or fewer.',
      );
    }

    // 1. Update Local State Immediately (Optimistic UI)
    final current = state.value;
    if (current != null) {
       final updated = current.copyWith(
         name: name ?? current.name,
         age: age ?? current.age,
         organization: organization ?? current.organization,
       );
       state = AsyncData(updated);
    }

    // 2. Persist Locally (SharedPrefs) - Ensures data survives restart even if sync fails
    try {
      final prefs = await SharedPreferences.getInstance();
      if (name != null) await prefs.setString('local_profile_name_${user.id}', name);
      if (age != null) await prefs.setInt('local_profile_age_${user.id}', age);
      if (organization != null) await prefs.setString('local_profile_organization_${user.id}', organization);
    } catch (e) {
      print('DEBUG: Error saving to SharedPreferences: $e');
    }

    // 3. Sync to Supabase (Background / Best Effort)
    try {
      final client = SupabaseConfig.client;
      if (client != null) {
        final updates = <String, dynamic>{};
        if (name != null) updates['name'] = name;
        if (age != null) updates['age'] = age;
        if (organization != null) updates['organization'] = organization;
        
        updates['patient_id'] = user.id;
        updates['updated_at'] = DateTime.now().toIso8601String();

        await client.from('patient_accounts').upsert(updates, onConflict: 'patient_id');
        print('DEBUG: Synced profile update to Supabase');
      }
    } catch (e) {
      print('DEBUG: Background sync to Supabase failed: $e');
    }
  }

  /// Updates the questionnaire data in Supabase and local state.
  Future<void> updateQuestionnaire(Map<String, dynamic> data) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // 1. Update Local State Immediately
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(questionnaireData: data));
    }

    // 2. Sync to Supabase
    try {
      final client = SupabaseConfig.client;
      if (client != null) {
        await client.from('patient_accounts').upsert({
          'patient_id': user.id,
          'questionnaire_data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'patient_id');
        print('DEBUG: Synced questionnaire to Supabase');
      }
    } catch (e) {
      print('DEBUG: Questionnaire sync failed: $e');
      rethrow;
    }
  }

  /// Updates the subscription status in the local state immediately.
  void updateSubscriptionStatus(bool isPremium, String plan) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(
        isPremium: isPremium,
        subscriptionPlan: plan,
      ));
    }
  }

  /// Applies gamification XP/coin/league updates to the local state immediately.
  void applyGamificationUpdate({
    required int xp,
    required int coins,
    required int leagueXp,
    required String currentLeague,
  }) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(
        xp: xp,
        coins: coins,
        leagueXp: leagueXp,
        currentLeague: currentLeague,
      ));
    }
  }

  /// Checks if an admin's manual subscription override has expired and
  /// reverts the local state to free. The database side (is_premium/
  /// subscription_plan/subscription_expires_at) is never written by the
  /// client - patient_accounts revokes client UPDATE on those columns, so
  /// only the RevenueCat webhook (service role) can clear an expired
  /// override there.
  PatientProfile _enforceAdminExpiry(PatientProfile p, SupabaseClient client) {
    if (p.isPremium && p.subscriptionExpiresAt != null) {
      if (DateTime.now().toUtc().isAfter(p.subscriptionExpiresAt!.toUtc())) {
        print('DEBUG: Admin subscription override expired. Reverting to free (local only).');
        return p.copyWith(
          isPremium: false,
          subscriptionPlan: 'free',
          clearExpiresAt: true,
        );
      }
    }
    return p;
  }
}

/// Provider for specific vital metrics to make UI updates cleaner
final biologicalAgeProvider = Provider<int?>((ref) {
  return ref.watch(patientProfileProvider).value?.bioAge;
});

final paceOfAgingProvider = Provider<double?>((ref) {
  return ref.watch(patientProfileProvider).value?.paceOfAging;
});
