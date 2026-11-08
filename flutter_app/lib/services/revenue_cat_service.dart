import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'analytics_service.dart';

class RevenueCatService {
  static const iosApiKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const androidApiKey = String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const entitlementPlus = 'Zyndio Plus';

  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🚀 RevenueCat: Starting initialization...');
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);

      PurchasesConfiguration configuration;
      if (Platform.isAndroid) {
        debugPrint('🤖 RevenueCat: Detected Android');
        configuration = PurchasesConfiguration(androidApiKey);
      } else if (Platform.isIOS) {
        debugPrint('🍎 RevenueCat: Detected iOS');
        configuration = PurchasesConfiguration(iosApiKey);
      } else {
        debugPrint('❌ RevenueCat: Unsupported platform');
        return;
      }

      await Purchases.configure(configuration);
      _isInitialized = true;
      debugPrint('✅ RevenueCat: Configuration complete');
      
      // Perform an immediate fetch check
      final offerings = await Purchases.getOfferings();
      debugPrint('📦 RevenueCat: Initial fetch result: ${offerings.current != null ? "HAS CURRENT" : "NO CURRENT OFFERING"}');
    } catch (e) {
      debugPrint('❌ RevenueCat: Initialization CRASHED: $e');
    }
  }

  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('❌ Failed to get customer info: $e');
      return null;
    }
  }

  Future<bool> isPlus() async {
    final customerInfo = await getCustomerInfo();
    return customerInfo?.entitlements.active.containsKey(entitlementPlus) ?? false;
  }

  Future<Offerings?> getOfferings() async {
    try {
      debugPrint('🔍 RevenueCat: Fetching offerings...');
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        debugPrint('⚠️ RevenueCat: Current offering is NULL');
      } else {
        debugPrint('✅ RevenueCat: Current offering has ${offerings.current!.availablePackages.length} packages');
        for (var pkg in offerings.current!.availablePackages) {
          debugPrint('   - Pkg: ${pkg.identifier} | Product: ${pkg.storeProduct.identifier} | Price: ${pkg.storeProduct.priceString}');
        }
      }
      return offerings;
    } catch (e) {
      debugPrint('❌ RevenueCat: Failed to get offerings: $e');
      return null;
    }
  }

  /// Performs a purchase and returns a result indicating success and any error message.
  Future<(bool, String?)> purchasePackage(Package package) async {
    try {
      debugPrint('🛒 RevenueCat: Initiating purchase for package: ${package.identifier}');
      debugPrint('🛒 RevenueCat: Product ID: ${package.storeProduct.identifier}');
      
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final customerInfo = result.customerInfo;
      final hasPlus = customerInfo.entitlements.active.containsKey(entitlementPlus);
      
      debugPrint('🛒 RevenueCat: Purchase result received. hasPlus=$hasPlus');
      
      if (hasPlus) {
        debugPrint('✅ RevenueCat: Entitlement "$entitlementPlus" is ACTIVE');
        // Log to Firebase Analytics
        await AnalyticsService().logPurchase(
          productId: package.storeProduct.identifier,
          price: package.storeProduct.price,
          currency: package.storeProduct.currencyCode,
        );
        await AnalyticsService().setUserIsPlus(true);
      } else {
        debugPrint('⚠️ RevenueCat: Purchase returned BUT entitlement "$entitlementPlus" NOT found in active entitlements.');
        debugPrint('🛒 RevenueCat: Active Entitlements: ${customerInfo.entitlements.active.keys.toList()}');
        debugPrint('🛒 RevenueCat: All Entitlements: ${customerInfo.entitlements.all.keys.toList()}');
      }
      
      return (hasPlus, null);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('❌ RevenueCat: Purchase failed (PlatformException)');
      debugPrint('   - Error Code: $errorCode');
      debugPrint('   - Message: ${e.message}');
      debugPrint('   - Details: ${e.details}');
      
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return (false, 'Purchase cancelled');
      }
      return (false, e.message ?? 'Purchase failed: $errorCode');
    } catch (e) {
      debugPrint('❌ RevenueCat: Unexpected purchase error: $e');
      return (false, e.toString());
    }
  }

  Future<void> restorePurchases() async {
    try {
      await Purchases.restorePurchases();
    } catch (e) {
      debugPrint('❌ Restore failed: $e');
    }
  }

  Future<Map<String, IntroEligibility>> checkTrialEligibility(List<String> productIds) async {
    try {
      return await Purchases.checkTrialOrIntroductoryPriceEligibility(productIds);
    } catch (e) {
      debugPrint('❌ RevenueCat: Failed to check eligibility: $e');
      return {};
    }
  }

  Future<void> logIn(String userId) async {
    try {
      await Purchases.logIn(userId);
    } catch (e) {
      debugPrint('❌ RevenueCat login failed: $e');
    }
  }

  Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('❌ RevenueCat logout failed: $e');
    }
  }
}
