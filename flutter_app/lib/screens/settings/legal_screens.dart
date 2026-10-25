import 'package:flutter/material.dart';
import '../../config/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy Policy'),
        backgroundColor: context.nc.scaffoldBg,
        foregroundColor: BrandColors.dark,
        elevation: 0,
      ),
      backgroundColor: context.nc.scaffoldBg,
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Text(
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
          style: TextStyle(fontSize: 14, height: 1.6, color: BrandColors.slate700),
        ),
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Terms of Use (EULA)'),
        backgroundColor: context.nc.scaffoldBg,
        foregroundColor: BrandColors.dark,
        elevation: 0,
      ),
      backgroundColor: context.nc.scaffoldBg,
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Text(
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
Phone: +91-9598320559
11. AUTO-RENEWING SUBSCRIPTIONS (APPLE EULA)
• Acknowledgment: You acknowledge that these Terms are between you and Zyndio only, and not with Apple. Zyndio is solely responsible for the App and its content.
• Subscription Terms: By subscribing to Zyndio Plus, you agree to an auto-renewing subscription. Payment will be charged to your iTunes Account at confirmation of purchase.
• Renewal: The subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. Your account will be charged the current price for renewal within 24 hours prior to the end of the current period.
• Management: You can manage or turn off auto-renewal in your Apple ID Account Settings at any time after purchase.
• Free Trial: If a free trial is offered, any unused portion will be forfeited when you purchase a subscription.''',
          style: TextStyle(fontSize: 14, height: 1.6, color: BrandColors.slate700),
        ),
      ),
    );
  }
}

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Refund Policy'),
        backgroundColor: context.nc.scaffoldBg,
        foregroundColor: BrandColors.dark,
        elevation: 0,
      ),
      backgroundColor: context.nc.scaffoldBg,
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Text(
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
          style: TextStyle(fontSize: 14, height: 1.6, color: BrandColors.slate700),
        ),
      ),
    );
  }
}

class InformedConsentScreen extends StatelessWidget {
  const InformedConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Informed Consent'),
        backgroundColor: context.nc.scaffoldBg,
        foregroundColor: BrandColors.dark,
        elevation: 0,
      ),
      backgroundColor: context.nc.scaffoldBg,
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Text(
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
          style: TextStyle(fontSize: 14, height: 1.6, color: BrandColors.slate700),
        ),
      ),
    );
  }
}

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Help Center'),
        backgroundColor: context.nc.scaffoldBg,
        foregroundColor: BrandColors.dark,
        elevation: 0,
      ),
      backgroundColor: context.nc.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'How can we help you?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'For technical support, account questions, or data requests, please contact our support team.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BrandColors.slate600),
            ),
            const SizedBox(height: 32),
            ListTile(
              leading: const Icon(Icons.email, color: BrandColors.blue500),
              title: const Text('Email Support'),
              subtitle: const Text('support@zyndio.example'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: BrandColors.blue500),
              title: const Text('Phone Support'),
              subtitle: const Text('+91-9598320559'),
              onTap: () {},
            ),
            const ListTile(
              leading: Icon(Icons.access_time, color: BrandColors.blue500),
              title: Text('Response Time'),
              subtitle: Text('Usually within 24 hours'),
            ),
          ],
        ),
      ),
    );
  }
}

class SubscriptionDetailsScreen extends StatelessWidget {
  const SubscriptionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subscription Details'),
        backgroundColor: context.nc.scaffoldBg,
        foregroundColor: BrandColors.dark,
        elevation: 0,
      ),
      backgroundColor: context.nc.scaffoldBg,
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Text(
          '''Subscription Terms & Details:

• Payment will be charged to your iTunes Account at confirmation of purchase.

• Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period.

• Your account will be charged for renewal within 24-hours prior to the end of the current period, and identify the cost of the renewal.

• Subscriptions may be managed by the user and auto-renewal may be turned off by going to the user's Account Settings after purchase.

• Any unused portion of a free trial period, if offered, will be forfeited when the user purchases a subscription to that publication, where applicable.''',
          style: TextStyle(fontSize: 14, height: 1.6, color: BrandColors.dark),
        ),
      ),
    );
  }
}
