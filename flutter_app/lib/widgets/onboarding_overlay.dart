import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../screens/lens/widgets/lens_shared_widgets.dart';
import '../providers/auth_provider.dart';
import '../services/ai_consent_service.dart';

// ───────────────────────────────────────────────────────────────
//  ONBOARDING OVERLAY — Health Intelligence showcase
//  Design: Frosted silver gradient, left-aligned titles,
//          embedded static preview cards, dark Continue button
// ───────────────────────────────────────────────────────────────

class OnboardingOverlay extends ConsumerStatefulWidget {
  const OnboardingOverlay({super.key});

  @override
  ConsumerState<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends ConsumerState<OnboardingOverlay> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 6; // Increased to 6 for Privacy slide
  
  bool _isLoading = false;
  bool _hasConsented = false;

  Future<void> _next() async {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Final page logic: Submit consent
      if (!_hasConsented) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please accept the privacy terms to continue.')),
          );
        }
        return;
      }
      
      final user = ref.read(currentUserProvider);
      if (user == null) {
          if (mounted) Navigator.of(context).pop();
          return;
      }

      setState(() => _isLoading = true);
      try {
        await ref.read(aiConsentServiceProvider).saveConsent(user.id, true);
        ref.invalidate(aiConsentProvider); // Notify app of consent
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving consent: $e')),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFCDD0D6), // silver top
                Color(0xFFD8DADF), // mid
                Color(0xFFE3E5EA), // bottom
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── Page content ──
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      const _WelcomePage(),
                      const _LabIntelligencePage(),
                      const _FoodIntelligencePage(),
                      const _WearablesSyncPage(),
                      const _AIConciegePage(),
                      _PrivacyConsentPage(
                         hasConsented: _hasConsented,
                         onConsentChanged: (v) => setState(() => _hasConsented = v ?? false),
                      ),
                    ],
                  ),
                ),
  
                // ── Bottom controls ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    children: [
                      // Dot indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_totalPages, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == i
                                  ? BrandColors.dark
                                  : BrandColors.dark.withValues(alpha: 0.2),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
  
                      // Continue button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BrandColors.dark,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _isLoading 
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                _currentPage == _totalPages - 1
                                    ? 'Get Started'
                                    : 'Continue',
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                        ),
                      ),
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

// ═══════════════════════════════════════════════════════════════
//  PAGE 1 — WELCOME
// ═══════════════════════════════════════════════════════════════

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset(
                'assets/icons/app_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Tagline
          Text(
            'Your Personal\nHealth Intelligence',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: BrandColors.dark.withValues(alpha: 0.55),
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PAGE 2 — LAB INTELLIGENCE
// ═══════════════════════════════════════════════════════════════

class _LabIntelligencePage extends StatelessWidget {
  const _LabIntelligencePage();

  @override
  Widget build(BuildContext context) {
    return _FeaturePage(
      title: 'Lab Intelligence',
      subtitle:
          'Visualize your health trajectory. Unify all your clinical data to build a clearer picture of your biological future.',
      children: [
        const IgnorePointer(
          child: Column(
            children: [
              _MockBiomarkerCardFull(
                name: 'Vitamin D',
                value: '42.5',
                unit: 'ng/mL',
                status: 'Optimal',
                statusColor: BrandColors.emerald500,
              ),
              SizedBox(height: 16),
              _MockBiomarkerCard(
                name: 'LDL Cholesterol',
                value: '97.8',
                unit: 'mg/dL',
                status: 'Optimal',
                statusColor: BrandColors.emerald500,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PAGE 3 — FOOD INTELLIGENCE
// ═══════════════════════════════════════════════════════════════

class _FoodIntelligencePage extends StatelessWidget {
  const _FoodIntelligencePage();

  @override
  Widget build(BuildContext context) {
    return _FeaturePage(
      title: 'Food Intelligence',
      subtitle:
          'Scan meals, get molecular breakdowns. Understand toxin exposures. Predict metabolic responses.',
      children: [
        const _MockFoodIntelligenceLayout(),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: LensMetabolicCard(
                label: "Digestion Time", 
                value: "2.5 hrs",
                textColor: BrandColors.dark,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: LensMetabolicCard(
                label: "Energy Curve", 
                value: "Stable",
                textColor: BrandColors.dark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PAGE 4 — WEARABLES SYNC
// ═══════════════════════════════════════════════════════════════

class _WearablesSyncPage extends StatelessWidget {
  const _WearablesSyncPage();

  @override
  Widget build(BuildContext context) {
    return _FeaturePage(
      title: 'Wearables Sync',
      subtitle:
          'Connect Apple Watch, Oura, or Whoop. Real-time heart rate, sleep, strain, and recovery insights.',
      children: [
        const Row(
          children: [
            Expanded(
              child: _MockWearableStatsCard(
                icon: LucideIcons.wind,
                title: 'RR',
                value: '15.0',
                unit: 'rpm',
                status: 'Normal',
                statusColor: BrandColors.emerald500,
                progress: 0.6,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _MockWearableStatsCard(
                icon: LucideIcons.heart,
                title: 'RHR',
                value: '54',
                unit: 'bpm',
                status: 'Normal',
                statusColor: BrandColors.emerald500,
                progress: 0.7,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _MockStressCard(),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PAGE 5 — AI HEALTH CONCIERGE
// ═══════════════════════════════════════════════════════════════

class _AIConciegePage extends StatelessWidget {
  const _AIConciegePage();

  @override
  Widget build(BuildContext context) {
    return _FeaturePage(
      title: 'AI Health\nConcierge',
      subtitle:
          'An intelligence trained on your\nbiomarkers, wearables, nutrition\npatterns, and risk factors.',
      children: [
        const IgnorePointer(
          child: _MockAICard(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PAGE 6 — PRIVACY CONSENT
// ═══════════════════════════════════════════════════════════════

class _PrivacyConsentPage extends StatelessWidget {
  final bool hasConsented;
  final ValueChanged<bool?> onConsentChanged;

  const _PrivacyConsentPage({
    required this.hasConsented,
    required this.onConsentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _FeaturePage(
      title: 'Privacy &\nData Security',
      subtitle:
          'Personalized longevity insights powered by advanced medical AI models. Your data is encrypted and secure.',
      children: [
        _FrostCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trusted AI Partners',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your data is processed by HIPAA-compliant Azure OpenAI & Google Gemini.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: BrandColors.slate600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                'Health Data Processing',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'To generate personalized protocols and insights, we share requested data such as Lab Reports, Food Images, and Wearable Metrics.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: BrandColors.slate600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                'Privacy Shield',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Data is NEVER used to train public AI models. Encrypted at rest and in transit.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: BrandColors.slate600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Consent Checkbox integration
        GestureDetector(
          onTap: () => onConsentChanged(!hasConsented),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: hasConsented,
                  onChanged: onConsentChanged,
                  activeColor: BrandColors.dark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'I agree to the AI-powered analysis of my health data as described above to receive personalized insights.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: BrandColors.slate600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED LAYOUT — Feature page scaffold
// ═══════════════════════════════════════════════════════════════

class _FeaturePage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _FeaturePage({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            // Title
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: BrandColors.dark,
                height: 1.05,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 12),
            // Subtitle
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: BrandColors.slate500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            // Cards
            ...children,
            const SizedBox(height: 40), // Safety margin
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED COMPONENTS
// ═══════════════════════════════════════════════════════════════

/// Frosted glass card
class _FrostCard extends StatelessWidget {
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;
  const _FrostCard({required this.child, this.height, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: height,
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Text style helpers ──

TextStyle _cardLabel() => GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: BrandColors.slate500,
    );

// ═══════════════════════════════════════════════════════════════
//  MOCK COMPONENTS (Static UI for perfect onboarding layout)
// ═══════════════════════════════════════════════════════════════

class _MockWearableStatsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final String status;
  final Color statusColor;
  final double progress;

  const _MockWearableStatsCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.statusColor,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return _FrostCard(
      height: 120,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: BrandColors.slate500),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BrandColors.slate600,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.dark,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BrandColors.slate400,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Vertical Slider / Gauge
          Container(
            width: 10,
            height: 100,
            decoration: BoxDecoration(
              color: BrandColors.slate100,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: 10,
                  height: 100 * progress,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Positioned(
                  bottom: 100 * progress - 10,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: statusColor, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockStressCard extends StatelessWidget {
  const _MockStressCard();

  @override
  Widget build(BuildContext context) {
    return _FrostCard(
      height: 240, // Increased to fit battery
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: BrandColors.emerald400),
                  SizedBox(width: 8),
                  Text(
                    "Today's stress",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.dark,
                    ),
                  ),
                ],
              ),
              Icon(LucideIcons.arrowRight, size: 18, color: BrandColors.slate300),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Last updated at 5:01 PM',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: BrandColors.slate400,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _statCol('62', 'Highest', BrandColors.orange500),
                  _divider(32),
                  _statCol('10', 'Lowest', BrandColors.emerald500),
                  _divider(32),
                  _statCol('30', 'Average', BrandColors.slate700),
                ],
              ),
              // Segmented Stress Gauge
              SizedBox(
                width: 75,
                height: 75,
                child: CustomPaint(
                  painter: _StressGaugePainter(progress: 0.46),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '46',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: BrandColors.dark,
                          ),
                        ),
                        Text(
                          'Low',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: BrandColors.emerald500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Energy / Battery Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.zap, size: 18, color: BrandColors.emerald500),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomPaint(
                    size: const Size(double.infinity, 12),
                    painter: _BatteryPainter(progress: 0.85),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '85%',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.dark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String val, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          val,
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: BrandColors.slate500,
          ),
        ),
      ],
    );
  }

  Widget _divider(double height) {
    return Container(
      height: height,
      width: 1,
      color: BrandColors.slate100,
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _MockBiomarkerCard extends StatelessWidget {
  final String name;
  final String value;
  final String unit;
  final String status;
  final Color statusColor;

  const _MockBiomarkerCard({
    required this.name,
    required this.value,
    required this.unit,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return _FrostCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          // Left side: Name and Status
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.dark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Middle: Value and Unit
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.slate400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right side: Graph
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: _MockBiomarkerChart(color: statusColor, showDots: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockBiomarkerCardFull extends StatelessWidget {
  final String name;
  final String value;
  final String unit;
  final String status;
  final Color statusColor;

  const _MockBiomarkerCardFull({
    required this.name,
    required this.value,
    required this.unit,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return _FrostCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    unit,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BrandColors.slate400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Large trend graph below
          SizedBox(
            height: 100,
            width: double.infinity,
            child: _MockBiomarkerChart(color: statusColor, showDots: true, showTitles: true),
          ),
        ],
      ),
    );
  }
}

class _MockBiomarkerChart extends StatelessWidget {
  final Color color;
  final bool showDots;
  final bool showTitles;
  const _MockBiomarkerChart({
    required this.color,
    this.showDots = false,
    this.showTitles = false,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showTitles,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final style = GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.slate400,
                );
                if (value == 0) return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('JAN', style: style));
                if (value == 4) return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('DEC', style: style));
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 3.5),
              FlSpot(1, 4.2),
              FlSpot(2, 3.8),
              FlSpot(3, 4.5),
              FlSpot(4, 2.8),
            ],
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: showDots,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: color,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockAICard extends StatelessWidget {
  const _MockAICard();

  @override
  Widget build(BuildContext context) {
    return _FrostCard(
      height: 380,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What would you\nlike to know?',
            style: TextStyle(
              fontSize: 32,
              color: BrandColors.dark,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.1,
              fontFamily: 'SF Pro Display',
            ),
          ),
          const SizedBox(height: 16),
          // Insight Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Increase omega-3 intake to improve your HDL ratio by ~15%.|',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: BrandColors.dark.withValues(alpha: 0.8),
                fontFamily: 'SF Pro Display',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'AI-generated insights • Wellness Reference',
              style: TextStyle(
                fontSize: 11,
                color: BrandColors.slate400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'History →',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.dark,
                ),
              ),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: BrandColors.dark,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Start Chat',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StressGaugePainter extends CustomPainter {
  final double progress;
  _StressGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const int totalSegments = 30;
    const double gap = 0.05;
    final double segmentAngle = (2 * math.pi * (1 - gap)) / totalSegments;

    for (int i = 0; i < totalSegments; i++) {
      final startAngle = -math.pi / 2 + i * segmentAngle + (i * 0.02);
      final segmentProgress = i / totalSegments;
      
      if (segmentProgress < progress) {
        paint.color = BrandColors.emerald400;
      } else {
        paint.color = BrandColors.slate100;
      }
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle * 0.7,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BatteryPainter extends CustomPainter {
  final double progress;
  _BatteryPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const int totalBars = 20;
    final barSpacing = size.width / totalBars;
    final barWidth = barSpacing * 0.6;
    
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < totalBars; i++) {
      final barProgress = i / totalBars;
      paint.color = barProgress < progress 
          ? BrandColors.emerald500 
          : BrandColors.slate100;
      
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * barSpacing, 0, barWidth, size.height),
        const Radius.circular(2),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MockFoodIntelligenceLayout extends StatelessWidget {
  const _MockFoodIntelligenceLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FrostCard(
            height: 175,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 90,
                  width: 90,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 6,
                        color: BrandColors.emerald500.withValues(alpha: 0.2),
                      ),
                      const CircularProgressIndicator(
                        value: 0.85,
                        strokeWidth: 6,
                        color: BrandColors.emerald500,
                        backgroundColor: Colors.transparent,
                      ),
                      Center(
                        child: Text(
                          '85',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: BrandColors.dark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Avocado Toast',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.dark)),
                Text('320 kcal',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: BrandColors.slate500)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FrostCard(
            height: 175,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Macros', style: _cardLabel()),
                const SizedBox(height: 16),
                _mockMacroBar('Protein', '12g', BrandColors.blue500, 0.4),
                const SizedBox(height: 12),
                _mockMacroBar('Carbs', '35g', BrandColors.orange500, 0.7),
                const SizedBox(height: 12),
                _mockMacroBar('Fat', '15g', BrandColors.emerald500, 0.5),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mockMacroBar(String label, String amount, Color color, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: BrandColors.dark)),
            Text(amount, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: BrandColors.dark)),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: 4,
              width: constraints.maxWidth * progress,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            );
          },
        ),
      ],
    );
  }
}

