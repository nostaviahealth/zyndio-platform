import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/revenue_cat_service.dart';
import '../services/branding_service.dart';
import 'patient_provider.dart';
import 'auth_provider.dart';
import '../models/patient_profile.dart';

class PurchaseState {
  final bool isPlus;
  final Offerings? offerings;
  final Map<String, IntroEligibility> introEligibility;
  final bool isLoading;

  PurchaseState({
    this.isPlus = false,
    this.offerings,
    this.introEligibility = const {},
    this.isLoading = false,
  });

  PurchaseState copyWith({
    bool? isPlus,
    Offerings? offerings,
    Map<String, IntroEligibility>? introEligibility,
    bool? isLoading,
  }) {
    return PurchaseState(
      isPlus: isPlus ?? this.isPlus,
      offerings: offerings ?? this.offerings,
      introEligibility: introEligibility ?? this.introEligibility,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PurchaseNotifier extends Notifier<PurchaseState> with WidgetsBindingObserver {
  final RevenueCatService _service = RevenueCatService();

  DateTime? _bootTime;
  bool _iconLocked = true; // 🛡️ Prevent app icon changes during the first 15s of boot

  @override
  PurchaseState build() {
    _bootTime = DateTime.now();

    // 🛡️ Unlock icon syncing after 15 seconds to allow background services to stabilize.
    // At this point, we perform a definitive ONE-SHOT sync to ensure the UI and Icon match.
    Future.delayed(const Duration(seconds: 15), () async {
      _iconLocked = false; 
      debugPrint('🛡️ PurchaseNotifier: Stabilization period complete - triggering One-Shot Icon Sync');
      
      // Perform a final refresh and FORCE the icon to match the result
      await _refreshStatus();
      ref.read(brandingServiceProvider).syncIconWithTier(state.isPlus);
    });

    // Listen to profile changes for admin overrides
    ref.listen<AsyncValue<PatientProfile?>>(patientProfileProvider, (previous, next) {
      if (previous?.value?.isPremium != next.value?.isPremium) {
        _refreshStatus();
      }
    });

    // ── CRITICAL STARTUP FIX ──
    // 1. Explicitly track session identity. When Supabase restores the session
    // (which happens after `build()` initialized), we MUST force RevenueCat 
    // to identify to that specific user ID and re-fetch.
    ref.listen<User?>(currentUserProvider, (previous, next) {
      if (previous?.id != next?.id && next?.id != null) {
        debugPrint('👤 PurchaseNotifier: Identity change detected to ${next!.id} - Syncing RevenueCat');
        _ensureLoggedIn().then((_) => _refreshStatus());
      } else if (next == null) {
        Purchases.logOut();
      }
    });

    // Register lifecycle observer so we always refresh when the app resumes
    // (e.g. the user returns from Manage Subscription / App Store)
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));

    // Start initialization on next frame
    Future.microtask(_init);
    return PurchaseState();
  }

  // Refresh CustomerInfo whenever the app returns to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);

    // Listen for real-time push updates from RevenueCat (purchases, renewals, expirations)
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      debugPrint('📡 PurchaseNotifier: CustomerInfo listener fired');
      _updatePurchaseStatus(customerInfo);
    });

    // ── CRITICAL: Log in FIRST, then fetch customer info ──
    // On Android, RevenueCat starts as anonymous. We must identify the user
    // BEFORE fetching customer info, otherwise entitlements won't be found.
    await _ensureLoggedIn();

    final customerInfo = await _service.getCustomerInfo();
    debugPrint('📦 PurchaseNotifier._init: customerInfo entitlements=${customerInfo?.entitlements.active.keys.toList()}');
    _updatePurchaseStatus(customerInfo);

    final offerings = await _service.getOfferings();
    
    // Check eligibility for all products in current offering
    Map<String, IntroEligibility> eligibility = {};
    if (offerings?.current != null) {
      final productIds = offerings!.current!.availablePackages
          .map((p) => p.storeProduct.identifier)
          .toList();
      eligibility = await _service.checkTrialEligibility(productIds);
    }

    state = state.copyWith(offerings: offerings, introEligibility: eligibility, isLoading: false);
  }

  /// Ensures the RevenueCat SDK is identified as the current Supabase user.
  /// Must be called BEFORE getCustomerInfo to get correct entitlements on Android.
  Future<void> _ensureLoggedIn() async {
    final userId = ref.read(patientProfileProvider).value?.id ?? 
                   ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    try {
      final loginResult = await Purchases.logIn(userId);
      final currentRcId = await Purchases.appUserID;
      debugPrint('🔑 PurchaseNotifier._ensureLoggedIn: logged in as $userId (RC ID: $currentRcId) | '
          'entitlements=${loginResult.customerInfo.entitlements.active.keys.toList()}');
    } catch (e) {
      debugPrint('⚠️ PurchaseNotifier._ensureLoggedIn failed: $e');
    }
  }

  /// Re-fetch the latest CustomerInfo from RevenueCat and propagate it.
  Future<void> _refreshStatus() async {
    try {
      // Always ensure login before refreshing — handles app resume on Android
      await _ensureLoggedIn();
      final customerInfo = await _service.getCustomerInfo();
      debugPrint('🔄 PurchaseNotifier._refreshStatus: entitlements=${customerInfo?.entitlements.active.keys.toList()}');
      _updatePurchaseStatus(customerInfo);
    } catch (e) {
      debugPrint('⚠️ PurchaseNotifier: refresh failed: $e');
    }
  }

  // Guard to prevent concurrent _updatePurchaseStatus calls from racing
  bool _isUpdating = false;

  void _updatePurchaseStatus(CustomerInfo? customerInfo) async {
    // Prevent concurrent invocations from overwriting each other
    if (_isUpdating) {
      debugPrint('⏳ PurchaseNotifier._updatePurchaseStatus: skipping (already running)');
      return;
    }
    _isUpdating = true;

    try {
      final profileAsync = ref.read(patientProfileProvider);
      final profile = profileAsync.value;
      final userId = profile?.id ?? ref.read(currentUserProvider)?.id;

      if (userId == null && !state.isLoading) {
        // If we are signed out and NOT initializing, we MUST be false
        if (state.isPlus) {
          state = state.copyWith(isPlus: false);
          ref.read(brandingServiceProvider).syncIconWithTier(false);
        }
        return; 
      }

      // If customerInfo is null (e.g. getCustomerInfo failed), try to fetch fresh
      if (customerInfo == null && userId != null) {
        try {
          final loginResult = await Purchases.logIn(userId);
          customerInfo = loginResult.customerInfo;
        } catch (e) {
          debugPrint('⚠️ PurchaseNotifier: fallback logIn failed: $e');
        }
      }

      final bool rcIsPlus = customerInfo?.entitlements.active.containsKey(RevenueCatService.entitlementPlus) ?? false;
      final bool profileIsPlus = profile?.isPremium ?? false;
      final bool hasActiveManualGrant = profileIsPlus && 
          profile?.subscriptionExpiresAt != null && 
          profile!.subscriptionExpiresAt!.isAfter(DateTime.now());

      debugPrint('🏆 PurchaseNotifier: rcIsPlus=$rcIsPlus | profileIsPlus=$profileIsPlus | manualGrant=$hasActiveManualGrant');

      // 🏆 RECONCILIATION LOGIC:
      // 1. If RevenueCat says Plus OR Supabase has an active Manual Grant -> We are Plus.
      // 2. If BOTH say Free, we are Free.
      
      bool finalIsPlus = rcIsPlus || hasActiveManualGrant;
      
      // BOOT GRACE PERIOD: 
      // If we just opened the app and Supabase says Plus, we trust it during the first 3s
      // to prevent the icon from flickering while RevenueCat identifies the user.
      final bool withinBootGrace = _bootTime != null && 
          DateTime.now().difference(_bootTime!).inSeconds < 3;

      if (withinBootGrace && profileIsPlus) {
        finalIsPlus = true; 
        debugPrint('PurchaseNotifier: 🛡️ Boot Grace Protection active - honoring Supabase Plus status');
      }

      if (!finalIsPlus && profileIsPlus) {
        // Expiration candidate: BOTH RC and Manual Grant are False, but Supabase was Plus.
        
        // --- DEVICE CACHE CHECK (Android Only) ---
        // sometimes RevenueCat's servers get out of sync with Google Play. If the subscription
        // is active on the DEVICE, syncPurchases() will push it to the server and fix it.
        if (Platform.isAndroid && !state.isLoading) {
           debugPrint('🛡️ PurchaseNotifier: Android local validation fallback triggered');
           try {
             await Purchases.syncPurchases();
             final customerInfoResult = await Purchases.getCustomerInfo();
             if (customerInfoResult.entitlements.active.containsKey(RevenueCatService.entitlementPlus)) {
               debugPrint('✅ PurchaseNotifier: Local sync restored the subscription!');
               customerInfo = customerInfoResult;
               finalIsPlus = true;
             }
           } catch (e) {
             debugPrint('⚠️ Local sync failed: $e');
           }
        }

        if (!finalIsPlus) {
          // IDENTITY LOCK: Only downgrade if the RevenueCat user ID actually matches our UserID.
          // This prevents "expiring" an anonymous session during a slow boot.
          final rcUserId = await Purchases.appUserID;
          if (rcUserId == userId) {
            debugPrint('PurchaseNotifier: ⬇️ Confirmed expiration for $userId - syncing to Free');
            finalIsPlus = false;
            _syncToSupabase(false);
          } else {
            debugPrint('PurchaseNotifier: ⏳ Identity mismatch ($rcUserId != $userId) - delaying downgrade');
            finalIsPlus = true; // Stay Plus until identity is stable
          }
        }
      } else if (rcIsPlus && !profileIsPlus) {
        // New purchase detected: RC is Plus but Supabase was Free.
        finalIsPlus = true;
        _syncToSupabase(true);
      }

      debugPrint('🏁 PurchaseNotifier: finalIsPlus=$finalIsPlus (was ${state.isPlus})');

      // 2. Update local Riverpod state
      if (state.isPlus != finalIsPlus) {
        state = state.copyWith(isPlus: finalIsPlus);
      }

      // 🎨 App Icon Sync (Strict Guard)
      // We only allow automatic icon changes if the boot-lock is released
      // OR if it's a manual purchase/restore action currently in progress.
      if (!_iconLocked) {
        ref.read(brandingServiceProvider).syncIconWithTier(finalIsPlus);
      } else {
        debugPrint('⏳ PurchaseNotifier: Icon sync suppressed - boot phase active');
      }
    } finally {
      _isUpdating = false;
    }
  }

  /// Writes is_premium to the profiles table and OPTIMISTICALLY updates local state.
  Future<void> _syncToSupabase(bool isPlus) async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final client = SupabaseConfig.client;
      if (client == null) return;

      // --- OPTIMISTIC UPDATE ---
      // We manually update the local patientProfileProvider so the UI reflects the change INSTANTLY.
      final profileNotifier = ref.read(patientProfileProvider.notifier);
      profileNotifier.updateSubscriptionStatus(isPlus, isPlus ? 'plus' : 'free');

      await client.from('profiles').upsert({
        'user_id': user.id,
        'is_premium': isPlus,
        'subscription_plan': isPlus ? 'plus' : 'free',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      debugPrint('✅ PurchaseNotifier: synced is_premium=$isPlus to Supabase');
    } catch (e) {
      debugPrint('⚠️ PurchaseNotifier: Supabase sync failed: $e');
    }
  }

  Future<(bool, String?)> purchasePackage(Package package) async {
    state = state.copyWith(isLoading: true);
    final (success, error) = await _service.purchasePackage(package);
    if (success) {
      debugPrint('✅ Purchase successful! Triggering immediate status refresh and icon sync...');
      _iconLocked = false; // Bypass lock for manual purchase
      await _refreshStatus();
    } else if (error != null) {
      debugPrint('⚠️ Purchase failed or cancelled: $error');
    }
    state = state.copyWith(isLoading: false);
    return (success, error);
  }

  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true);
    await _service.restorePurchases();
    _iconLocked = false; // Bypass lock for manual restore
    final customerInfo = await _service.getCustomerInfo();
    _updatePurchaseStatus(customerInfo);
    state = state.copyWith(isLoading: false);
  }
}

final purchaseProvider = NotifierProvider<PurchaseNotifier, PurchaseState>(() {
  return PurchaseNotifier();
});

