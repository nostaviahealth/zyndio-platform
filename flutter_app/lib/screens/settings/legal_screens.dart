import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/theme.dart';
import '../../widgets/tc025/tc025_widgets.dart';

/// Long-form legal copy shown on the shared pushed-screen chrome: the text
/// sits in one card inside a scrolling list, so it never overflows on a small
/// phone or with large accessibility text.
class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ZyndioDetailScaffold(
      title: title,
      children: [
        ZyndioCard(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          child: _LegalText(text),
        ),
      ],
    );
  }
}

/// Renders [text] verbatim, styling numbered all-caps lines ("1. SCOPE") as
/// section headings and a leading "Last Updated" line as a caption.
class _LegalText extends StatelessWidget {
  const _LegalText(this.text);

  final String text;

  static final RegExp _heading = RegExp(r"^\d+\.\s+[A-Z][A-Z0-9 &()’'/,-]*$");

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final bodyStyle = TextStyle(
      fontFamily: ZyndioType.family,
      fontSize: 15,
      height: 1.6,
      color: c.textSecondary,
    );
    final headingStyle = TextStyle(
      fontFamily: ZyndioType.family,
      fontSize: 15,
      height: 22 / 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: c.textPrimary,
    );
    final captionStyle = TextStyle(
      fontFamily: ZyndioType.family,
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w600,
      color: c.textTertiary,
    );

    final blocks = <Widget>[];
    final paragraph = <String>[];
    void flush() {
      if (paragraph.isEmpty) return;
      blocks.add(Text(paragraph.join('\n'), style: bodyStyle));
      paragraph.clear();
    }

    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        flush();
        continue;
      }
      if (i == 0 && line.startsWith('Last Updated')) {
        blocks.add(Text(line, style: captionStyle));
        continue;
      }
      if (i == 0 || _heading.hasMatch(line.trim())) {
        flush();
        blocks.add(Padding(
          padding: EdgeInsets.only(top: blocks.isEmpty ? 0 : 10),
          child: Semantics(
            header: true,
            child: Text(line, style: headingStyle),
          ),
        ));
        continue;
      }
      paragraph.add(line);
    }
    flush();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          blocks[i],
        ],
      ],
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Privacy Policy',
      text:
          '''Last Updated: February 7, 2026

1. INTRODUCTION AND SCOPE
Zyndio (“Zyndio,” “we,” “our,” or “us”) is committed to protecting the privacy, confidentiality, and security of your information. This Privacy Policy explains how we collect, use, store, disclose, and safeguard your Personal Information and Sensitive Personal Data or Information (“SPDI”) when you access or use our mobile application, website, platform, and related services (collectively, the “Platform”).

2. INFORMATION WE COLLECT
2.1 Personal Information
- Identity Data: Name, age, gender, date of birth
- Contact Data: Email address, phone number, shipping address

2.2 Sensitive Personal Data or Information (SPDI)
- Biological Samples & Lab Results: Markers, hormonal panels, toxin levels.
- Genetic & Epigenetic Data: Predispositions for disease risk.
- Health & Lifestyle Data: Sleep, stress, diet, medications, history.
- Physiological Metrics: HRV, heart rate, activity levels from wearables.

2.3 Automatically Collected Information
Device info, usage data, and log data (IP, errors).

2.4 Camera and Photo Library Access
Required for lab report uploads and meal tracking only.

3. HOW WE USE YOUR INFORMATION
We do not sell your data. Used strictly for:
3.1 Service Delivery: Longevity reports, functional grading, custom protocols.
3.2 Genius Doctor Review: Human review by qualified professional doctors/nutritionists.
3.3 AI & Predictive Modeling: AI models for risk probabilities.
3.4 Operations: Care team access, support, security.

4. DATA SHARING
4.1 Authorized Sharing: Labs, care professionals, IT infrastructure.
4.2 Legal Disclosure: Required by laws or authorities.
4.3 No Commercial Sale: Firewall-protected from insurers and brokers.

5. THIRD-PARTY AI SERVICES
We utilize third-party artificial intelligence services to analyze health data and provide insights.
5.1 Data Processors: Our primary AI processors are Microsoft Azure (OpenAI) and Google (Gemini).
5.2 Data Shared: Depending on the feature used, we may share:
    - Lab results and biomarkers for longevity analysis.
    - Food images for nutritional and metabolic breakdown.
    - Chat messages for health-related queries.
5.3 Privacy Protections: We confirm that any third-party AI service we share data with provides the same or equal privacy protection as stated in this policy. Your data is processed securely and is strictly NOT used by these third parties to train their public models. We seek your explicit consent before any data is shared with these services.

6. DATA SECURITY
Encrypted at rest (cloud) and in transit (TLS). Role-based access.

7. DATA RETENTION
Retained for continuous tracking. Medical records retained per Indian legal regulations even after cancellation.

8. YOUR RIGHTS
Access, correction, porting, or deletion. Grievance Officer: support@zyndio.example.

9. CHILDREN’S PRIVACY
Services not intended for under 18.

10. CONTACT US
Email: support@zyndio.example''',
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Terms of Use (EULA)',
      text:
          '''Last Updated: February 7, 2026

1. ACCEPTANCE OF TERMS
By accessing Zyndio, you agree to these Terms. If you do not agree, discontinue use immediately.

2. ELIGIBILITY
Must be 18+ or have parent/guardian consent.

3. DESCRIPTION OF SERVICES
Digital Clinics (telehealth), Personalized Health Plans (AI-generated/doctor-verified), Wellness Programs, and Marketplace.

4. DATA PRIVACY
Governed by IT Act 2000 and DPDP Act 2023. Principles: Secure encryption, no commercial sale of data.

5. HEALTH DISCLAIMERS
Complies with Telemedicine Practice Guidelines (India). App is NOT a substitute for in-person medical care or emergencies.

6. MARKETPLACE
Zyndio is a facilitator. Liabilities for products rest with third-party vendors.

7. PAYMENTS & REFUNDS
Approved Indian payment methods. Refunds governed by Refund Policy.

8. INTELLECTUAL PROPERTY
Algorithms, branding, and content are exclusive property of Zyndio.

9. GOVERNING LAW
Laws of India. Dispute resolution via arbitration in Lucknow, Uttar Pradesh.

10. CONTACT
Email: support@zyndio.example
Phone: +1 555 0100
11. AUTO-RENEWING SUBSCRIPTIONS (APPLE EULA)
• Acknowledgment: You acknowledge that these Terms are between you and Zyndio only, and not with Apple. Zyndio is solely responsible for the App and its content.
• Subscription Terms: By subscribing to Zyndio Plus, you agree to an auto-renewing subscription. Payment will be charged to your iTunes Account at confirmation of purchase.
• Renewal: The subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. Your account will be charged the current price for renewal within 24 hours prior to the end of the current period.
• Management: You can manage or turn off auto-renewal in your Apple ID Account Settings at any time after purchase.
• Free Trial: If a free trial is offered, any unused portion will be forfeited when you purchase a subscription.''',
    );
  }
}

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Refund Policy',
      text:
          '''Last Updated: February 7, 2026

1. SUBSCRIPTIONS
- Monthly: Cancel anytime. Fully refundable within 7 days if no services used.
- Annual: Cancel with full refund within 14 days. Prorated refund after 14 days (minus used services). No refunds after 90 days.

2. DIGITAL CLINIC
- Free cancellation up to 24h before.
- 50% fee for cancellations within 24h.
- Full refund for technical failures reported within 24h.

3. MARKETPLACE
- Cancel unshipped orders within 24h for full refund.
- 14-day returns for unused/unopened items (user pays shipping).
- Full refund for defective/incorrect items.

4. NON-REFUNDABLE
Personalized health plans or programs once accessed/downloaded.

5. PROCESS
Refunds processed via PhonePe within 7-10 business days.

6. DISPUTES
Contact support@zyndio.example; resolved within 14 days per Indian law.''',
    );
  }
}

class InformedConsentScreen extends StatelessWidget {
  const InformedConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Informed Consent',
      text:
          '''Wellness & AI Consent

1. DATA COLLECTION
I consent to collection of my biological samples, genetic data, and physiological metrics for health analysis.

2. PROFESSIONAL REVIEW
I explicitly consent to my anonymized data being reviewed by "Genius Doctors" (qualified doctors/nutritionists) to personalize my protocols.

3. AI PREDICTIONS & DATA SHARING
I explicitly consent to my health data (including lab reports, food photos, and metrics) being shared with and processed by third-party AI services (including Microsoft Azure and Google) to generate health risk scores, longevity protocols, and nutritional insights. I understand these represent statistical probabilities, not medical diagnosis.

4. MEDICAL DISCLAIMER
I acknowledge that I am using this app for wellness optimization and not for acute medical management.

5. STORAGE
I consent to my data being stored securely on cloud infrastructure for longitudinal tracking.''',
    );
  }
}

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    return ZyndioDetailScaffold(
      title: 'Help Center',
      children: [
        ZyndioCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ZyndioIconTile(
                  icon: LucideIcons.lifeBuoy, tint: ZyndioTint.blue, size: 48),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  'How can we help you?',
                  style: ZyndioType.title3.copyWith(color: c.textPrimary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'For technical support, account questions, or data requests, please contact our support team.',
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 15,
                  height: 22 / 15,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ZyndioCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              _HelpRow(
                icon: LucideIcons.mail,
                tint: ZyndioTint.blue,
                title: 'Email Support',
                subtitle: 'support@zyndio.example',
                onTap: () {},
              ),
              Divider(height: 1, indent: 76, color: c.borderSubtle),
              _HelpRow(
                icon: LucideIcons.phone,
                tint: ZyndioTint.green,
                title: 'Phone Support',
                // Fictional placeholder number (no real contact data).
                subtitle: '+1 555 0100',
                onTap: () {},
              ),
              Divider(height: 1, indent: 76, color: c.borderSubtle),
              const _HelpRow(
                icon: LucideIcons.clock,
                tint: ZyndioTint.violet,
                title: 'Response Time',
                subtitle: 'Usually within 24 hours',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One contact line in the Help Center card: gradient icon tile, title and
/// detail. Tappable rows keep a 44pt+ target; the detail text wraps freely.
class _HelpRow extends StatelessWidget {
  const _HelpRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final ZyndioTint tint;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ZyndioIconTile(icon: icon, tint: tint, size: 44),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class SubscriptionDetailsScreen extends StatelessWidget {
  const SubscriptionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Subscription Details',
      text:
          '''Subscription Terms & Details:

• Payment will be charged to your iTunes Account at confirmation of purchase.

• Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period.

• Your account will be charged for renewal within 24-hours prior to the end of the current period, and identify the cost of the renewal.

• Subscriptions may be managed by the user and auto-renewal may be turned off by going to the user's Account Settings after purchase.

• Any unused portion of a free trial period, if offered, will be forfeited when the user purchases a subscription to that publication, where applicable.''',
    );
  }
}
