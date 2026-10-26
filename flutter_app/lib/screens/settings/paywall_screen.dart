import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/purchase_provider.dart';
import 'legal_screens.dart';

// ─── Palette (SuperGrok Exact) ───────────────────────────────────────────
const _kBg           = Color(0xFF000000); // Pure black scaffold
const _kCardBg       = Color(0x331C1C1E); // Glassy dark feature card
const _kPlanSelected = Color(0x662C2C2E); // Selected plan card bg
const _kPlanUnsel    = Color(0x331C1C1E); // Unselected plan card bg
const _kTextMain     = Colors.white;
const _kTextGray     = Color(0xFF8E8E93); // Gray for secondary labels
const _kBadge        = Color(0xFF007AFF); // iOS Blue for badge

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  /// Push as full-screen route with rootNavigator to avoid bottom bar
  static Future<void> show(BuildContext context) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PaywallScreen(),
      ),
    );
  }

  /// Show the Customer Center for managing existing subscriptions
  static Future<void> showCustomerCenter() async {
    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      debugPrint('❌ Customer Center error: $e');
    }
  }

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  int _selectedPlanIndex = 1; // 1 = monthly (7-day trial), 0 = yearly
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  // ─── Helper: Extract packages from offerings ─────────────────────────
  Package? _getMonthlyPackage(PurchaseState state) {
    final packages = state.offerings?.current?.availablePackages ?? [];
    for (final pkg in packages) {
      if (pkg.packageType == PackageType.monthly) return pkg;
    }
    return null;
  }

  Package? _getAnnualPackage(PurchaseState state) {
    final packages = state.offerings?.current?.availablePackages ?? [];
    for (final pkg in packages) {
      if (pkg.packageType == PackageType.annual) return pkg;
    }
    return null;
  }

  // ─── Helper: Format price from StoreProduct ──────────────────────────
  String _formatPrice(Package? pkg, String fallback) {
    if (pkg == null) return fallback;
    return pkg.storeProduct.priceString;
  }

  // ─── Helper: Detect if package has a free trial ──────────────────────
  bool _hasTrial(Package? pkg) {
    if (pkg == null) return false;
    final introPrice = pkg.storeProduct.introductoryPrice;
    if (introPrice == null) return false;
    return introPrice.price == 0;
  }

  @override
  Widget build(BuildContext context) {
    final purchaseState = ref.watch(purchaseProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // ── Extract live packages ──
    final monthlyPkg = _getMonthlyPackage(purchaseState);
    final annualPkg = _getAnnualPackage(purchaseState);

    // ── Dynamic labels & pricing ──
    final monthlyPrice = _formatPrice(monthlyPkg, '---');
    final annualPrice = _formatPrice(annualPkg, '---');

    // Trial label logic: Priority to eligibility status OR presence of trial info from StoreProduct
    // This ensures Android users see the trial if Google Play says it exists, even if 
    // RevenueCat's eligibility pre-flight check hasn't completed or is inconclusive.
    String monthlyLabel = 'Monthly';
    bool showTrialCTA = false;
    int activeTrialDays = 7;

    final bool monthlyHasTrial = _hasTrial(monthlyPkg);
    final bool annualHasTrial = _hasTrial(annualPkg);

    if (monthlyHasTrial) {
      final days = _calculateTrialDays(monthlyPkg!.storeProduct.introductoryPrice);
      monthlyLabel = '$days ${days == 1 ? 'Day' : 'Days'} Free';
      if (_selectedPlanIndex == 1) {
        showTrialCTA = true;
        activeTrialDays = days;
      }
    } 
    
    if (annualHasTrial) {
      if (_selectedPlanIndex == 0) {
        showTrialCTA = true;
        activeTrialDays = _calculateTrialDays(annualPkg!.storeProduct.introductoryPrice);
      }
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background Image (Dimmed) ────────────────────────────────
          Positioned.fill(
            child: Opacity(
              opacity: 0.65,
              child: Image.asset(
                'assets/images/paywall_premium_bg.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),

          // ── 2. Top-to-Bottom Gradient Fades ──────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 0.75, 1.0],
                  colors: [
                    _kBg.withValues(alpha: 0.1),
                    _kBg.withValues(alpha: 0.4),
                    _kBg.withValues(alpha: 0.8),
                    _kBg,
                  ],
                ),
              ),
            ),
          ),

          // ── 3. Main Interface ───────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Close Button at Left
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.close, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),

                // Heading (Center Aligned)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(
                        'Zyndio Plus',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: _kTextMain,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 0),
                      Text(
                        'Unlock your full health potential',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: _kTextMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Feature List Card (Liquid Glass)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _kCardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(height: 12),
                              _FeatureRow(
                                icon: LucideIcons.sparkles,
                                title: '24/7 AI Health Concierge',
                                subtitle: 'Unlimited expert-level guidance',
                              ),
                              SizedBox(height: 16),
                              _FeatureRow(
                                icon: LucideIcons.brain,
                                title: 'Adaptive Intelligence Core',
                                subtitle: 'A neural brain that learns you',
                              ),
                              SizedBox(height: 16),
                              _FeatureRow(
                                icon: LucideIcons.dna,
                                title: 'Digital Twin Simulation',
                                subtitle: 'Real-time bio-age forecasting',
                              ),
                              SizedBox(height: 16),
                              _FeatureRow(
                                icon: LucideIcons.camera,
                                title: 'Infinite Nutrition Scans',
                                subtitle: 'Uncapped meal tracking access',
                              ),
                              SizedBox(height: 16),
                              _FeatureRow(
                                icon: LucideIcons.activity,
                                title: 'Advanced Dietary Insight',
                                subtitle: 'Deep-layer metabolic analytics',
                              ),
                              SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Plan Cards (Liquid Glass) — DYNAMIC PRICING
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PlanCard(
                          label: monthlyLabel,
                          price: monthlyPrice,
                          suffix: '/month',
                          isSelected: _selectedPlanIndex == 1,
                          onTap: () => setState(() => _selectedPlanIndex = 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlanCard(
                          label: 'Yearly',
                          price: annualPrice,
                          suffix: '/year',
                          badge: '2 months free',
                          isSelected: _selectedPlanIndex == 0,
                          onTap: () => setState(() => _selectedPlanIndex = 0),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // CTA Button (White Pill)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildCTA(purchaseState, showTrialCTA, activeTrialDays),
                ),

                const SizedBox(height: 12),

                // Subscription Disclaimer
                if (showTrialCTA)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Cancel at least 24 hours before the trial ends to avoid being charged. Recurring billing, cancel anytime.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _kTextGray, fontSize: 11, height: 1.3),
                    ),
                  ),

                const SizedBox(height: 10),

                // Legal Rows — BALANCED 2x2
                Padding(
                  padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
                            ),
                            child: _legalText('Terms of Use (EULA)'),
                          ),
                          _dot(),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                            ),
                            child: _legalText('Privacy Policy'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SubscriptionDetailsScreen()),
                            ),
                            child: _legalText('Subscription Details'),
                          ),
                          _dot(),
                          GestureDetector(
                            onTap: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(context);
                              await ref.read(purchaseProvider.notifier).restorePurchases();
                              if (mounted) {
                                final restored = ref.read(purchaseProvider).isPlus;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      restored
                                          ? '✅ Purchases restored successfully!'
                                          : 'No previous purchases found.',
                                    ),
                                    backgroundColor: restored ? Colors.green.shade700 : Colors.grey.shade800,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                                if (restored) navigator.pop();
                              }
                            },
                            child: _legalText('Restore Purchases'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading Overlay
          if (_isPurchasing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCTA(PurchaseState state, bool isTrialEligible, int days) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isPurchasing ? null : () => _handlePurchase(state),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.2),
        ),
        child: Text(
          isTrialEligible ? 'Start $days-Day Free Trial' : 'Upgrade to Zyndio Plus',
        ),
      ),
    );
  }

  int _calculateTrialDays(IntroductoryPrice? intro) {
    if (intro == null) return 7;
    switch (intro.periodUnit) {
      case PeriodUnit.day:
        return intro.periodNumberOfUnits;
      case PeriodUnit.week:
        return intro.periodNumberOfUnits * 7;
      case PeriodUnit.month:
        return intro.periodNumberOfUnits * 30;
      case PeriodUnit.year:
        return intro.periodNumberOfUnits * 365;
      default:
        return 7;
    }
  }

  Future<void> _handlePurchase(PurchaseState state) async {
    final packages = state.offerings?.current?.availablePackages ?? [];
    if (packages.isEmpty) {
      // Show feedback if no packages available (e.g., no internet)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to load plans. Please check your connection and try again.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    setState(() => _isPurchasing = true);
    Package? target;
    for (final pkg in packages) {
      if (_selectedPlanIndex == 0 && pkg.packageType == PackageType.annual) { target = pkg; break; }
      if (_selectedPlanIndex == 1 && pkg.packageType == PackageType.monthly) { target = pkg; break; }
    }
    target ??= packages.first;

    final (success, error) = await ref.read(purchaseProvider.notifier).purchasePackage(target);
    if (mounted) {
      setState(() => _isPurchasing = false);
      if (success) {
        Navigator.of(context).pop();
      } else if (error != null && error != 'Purchase cancelled') {
        // Show error feedback for failed purchase
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red.shade900,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        // Silent for cancel or generic failure
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Purchase was not completed.'),
            backgroundColor: Colors.grey.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _legalText(String text) => Text(text, style: const TextStyle(color: _kTextGray, fontSize: 12));
  Widget _dot() => const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('·', style: TextStyle(color: _kTextGray)));
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
          ),
          child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 14, color: _kTextGray)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String label;
  final String price;
  final String suffix;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.label,
    required this.price,
    required this.suffix,
    this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? _kPlanSelected : _kPlanUnsel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: isSelected ? 0.4 : 0.1), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(label, style: TextStyle(fontSize: 14, color: isSelected ? Colors.white : _kTextGray, fontWeight: FontWeight.w600)),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _kBadge, borderRadius: BorderRadius.circular(6)),
                        child: Text(badge!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: price, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : _kTextGray)),
                      TextSpan(text: suffix, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white70 : _kTextGray)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
