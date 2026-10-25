import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/patient_profile.dart';
import 'auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final patientProfileProvider = AsyncNotifierProvider<PatientProfileNotifier, PatientProfile?>(() {
  return PatientProfileNotifier();
});

class PatientProfileNotifier extends AsyncNotifier<PatientProfile?> {
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
        subscription = client.channel('public:profiles:${user.id}').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
             print('DEBUG: Supabase Realtime profile change: ${payload.newRecord}');
             var newProfile = PatientProfile.fromJson(payload.newRecord);
             newProfile = _enforceAdminExpiry(newProfile, client);
             state = AsyncData(newProfile);
          }
        ).subscribe();

        // Try by ID
        var response = await client
            .from('profiles')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (response != null) {
          profile = PatientProfile.fromJson(response);
          profile = _enforceAdminExpiry(profile, client);
        } else {
           // Fallback by Email
           if (user.email != null) {
              response = await client
                .from('profiles')
                .select()
                .eq('email', user.email!)
                .maybeSingle();
               if (response != null) {
                  profile = PatientProfile.fromJson(response);
                  profile = _enforceAdminExpiry(profile, client);
               }
           }
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
              client.from('profiles').update({'avatar_url': socialAvatar}).eq('user_id', user.id).then((_) {
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

    try {
      final client = SupabaseConfig.client;
      if (client == null) return;

      final bytes = await file.readAsBytes();
      // Prefix with data URI so UI knows how to handle it
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      // 1. Update Profile Table directly with Base64 string
      await client.from('profiles').update({'avatar_url': base64String}).eq('user_id', user.id);

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
        
        updates['user_id'] = user.id;
        updates['updated_at'] = DateTime.now().toIso8601String();

        await client.from('profiles').upsert(updates, onConflict: 'user_id');
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
        await client.from('profiles').update({
          'questionnaire_data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('user_id', user.id);
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

  /// Checks if an admin's manual subscription override has expired.
  /// Reverts the local state to free and mutates the database to match.
  PatientProfile _enforceAdminExpiry(PatientProfile p, SupabaseClient client) {
    if (p.isPremium && p.subscriptionExpiresAt != null) {
      if (DateTime.now().toUtc().isAfter(p.subscriptionExpiresAt!.toUtc())) {
        print('DEBUG: Admin subscription override expired. Reverting to free.');
        
        final reverted = p.copyWith(
          isPremium: false,
          subscriptionPlan: 'free',
          clearExpiresAt: true,
        );
        
        // Fire and forget: update database to clear the expired manual flag
        if (p.userId != null) {
          client.from('profiles').upsert({
            'user_id': p.userId,
            'is_premium': false,
            'subscription_plan': 'free',
            'subscription_expires_at': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id').then((_) {
             print('DEBUG: Successfully reverted expired sub in Supabase');
          }).catchError((e) {
             print('DEBUG: Failed to revert expired sub in Supabase: $e');
          });
        }
        
        return reverted;
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
