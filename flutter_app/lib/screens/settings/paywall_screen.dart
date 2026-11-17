import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/purchase_provider.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import 'legal_screens.dart';

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

    final c = context.zc;
    final noPlans =
        (purchaseState.offerings?.current?.availablePackages ?? []).isEmpty;

    final monthlyCard = _PlanCard(
      label: monthlyLabel,
      price: monthlyPrice,
      suffix: '/month',
      isSelected: _selectedPlanIndex == 1,
      onTap: () => setState(() => _selectedPlanIndex = 1),
    );
    final yearlyCard = _PlanCard(
      label: 'Yearly',
      price: annualPrice,
      suffix: '/year',
      badge: '2 months free',
      isSelected: _selectedPlanIndex == 0,
      onTap: () => setState(() => _selectedPlanIndex = 0),
    );

    final scaffold = ZyndioDetailScaffold(
      title: 'Zyndio Plus',
      subtitle: 'Unlock your full health potential',
      backIcon: LucideIcons.x,
      onBack: () => Navigator.of(context).pop(),
      bottomBar: _buildCTA(purchaseState, showTrialCTA, activeTrialDays),
      children: [
        // Hero art on a rounded card (decorative).
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/paywall_premium_bg.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          ZyndioGradients.brand.colors.first
                              .withValues(alpha: 0.10),
                          ZyndioGradients.brand.colors.last
                              .withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Feature list
        const ZyndioCard(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            children: [
              _FeatureRow(
                icon: LucideIcons.sparkles,
                tint: ZyndioTint.violet,
                title: '24/7 AI Health Concierge',
                subtitle: 'Unlimited expert-level guidance',
              ),
              SizedBox(height: 16),
              _FeatureRow(
                icon: LucideIcons.brain,
                tint: ZyndioTint.indigo,
                title: 'Adaptive Intelligence Core',
                subtitle: 'A neural brain that learns you',
              ),
              SizedBox(height: 16),
              _FeatureRow(
                icon: LucideIcons.dna,
                tint: ZyndioTint.rose,
                title: 'Digital Twin Simulation',
                subtitle: 'Real-time bio-age forecasting',
              ),
              SizedBox(height: 16),
              _FeatureRow(
                icon: LucideIcons.camera,
                tint: ZyndioTint.teal,
                title: 'Infinite Nutrition Scans',
                subtitle: 'Uncapped meal tracking access',
              ),
              SizedBox(height: 16),
              _FeatureRow(
                icon: LucideIcons.activity,
                tint: ZyndioTint.green,
                title: 'Advanced Dietary Insight',
                subtitle: 'Deep-layer metabolic analytics',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Plan options — DYNAMIC PRICING. Side by side when there is room,
        // stacked on a narrow phone or with large accessibility text.
        LayoutBuilder(builder: (context, box) {
          final roomy = box.maxWidth >= 340 &&
              MediaQuery.textScalerOf(context).scale(16) <= 18;
          if (roomy) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: monthlyCard),
                  const SizedBox(width: 12),
                  Expanded(child: yearlyCard),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [monthlyCard, const SizedBox(height: 12), yearlyCard],
          );
        }),

        // No offerings (offline, store not configured): say so instead of
        // leaving bare placeholder prices.
        if (noPlans) ...[
          const SizedBox(height: 12),
          if (purchaseState.isLoading)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: c.brandPrimary),
                ),
              ],
            )
          else
            const ZyndioStateBanner(
              message:
                  'Unable to load plans. Please check your connection and try again.',
            ),
        ],

        // Subscription Disclaimer
        if (showTrialCTA) ...[
          const SizedBox(height: 16),
          Text(
            'Cancel at least 24 hours before the trial ends to avoid being charged. Recurring billing, cancel anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              color: c.textTertiary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],

        const SizedBox(height: 20),
        ZyndioOutlineButton(
          label: 'Restore Purchases',
          icon: LucideIcons.rotateCcw,
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
        ),
        const SizedBox(height: 16),

        // Legal links
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _legalLink(
              'Terms of Use (EULA)',
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
              ),
            ),
            _dot(),
            _legalLink(
              'Privacy Policy',
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
            _dot(),
            _legalLink(
              'Subscription Details',
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionDetailsScreen()),
              ),
            ),
          ],
        ),
      ],
    );

    return Stack(
      children: [
        scaffold,
        // Loading Overlay (blocks taps while a purchase is in flight)
        if (_isPurchasing)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.4),
              child: Center(
                child: CircularProgressIndicator(color: c.brandPrimary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCTA(PurchaseState state, bool isTrialEligible, int days) {
    return ZyndioGradientButton(
      label: isTrialEligible ? 'Start $days-Day Free Trial' : 'Upgrade to Zyndio Plus',
      trailingArrow: false,
      loading: _isPurchasing,
      onTap: _isPurchasing ? null : () => _handlePurchase(state),
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

  Widget _legalLink(String text, VoidCallback onTap) {
    final c = context.zc;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: ZyndioType.family,
            color: c.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('·', style: TextStyle(color: context.zc.textTertiary)),
      );
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final ZyndioTint tint;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    return Row(
      children: [
        ZyndioIconTile(icon: icon, tint: tint, size: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 16,
                  height: 22 / 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 14,
                  height: 20 / 14,
                  color: c.textSecondary,
                ),
              ),
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
    final c = context.zc;
    const radius = 20.0;
    return Semantics(
      button: true,
      selected: isSelected,
      child: DecoratedBox(
        // Selection ring drawn over the card so its size never changes.
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isSelected ? c.brandPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: ZyndioCard(
          radius: radius,
          padding: const EdgeInsets.all(16),
          color: isSelected ? c.brandSubtle : null,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? c.brandOnSubtle : c.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isSelected ? LucideIcons.circleCheck : LucideIcons.circle,
                    size: 20,
                    color: isSelected ? c.brandPrimary : c.borderStrong,
                  ),
                ],
              ),
              if (badge != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ZyndioPill(badge!, tone: ZyndioPillTone.brand),
                ),
              ],
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: price,
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFeatures: ZyndioType.tabular,
                        color: c.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: suffix,
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 13,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
