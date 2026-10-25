import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuration for white-labeling hospital / health system clients.
/// Changing this single configuration updates branding, currency, enabled features,
/// support contacts, and API endpoints across the entire app.
class WhiteLabelConfig {
  final String hospitalBrandName;
  final String tagline;
  final String logoAssetOrUrl;
  final String primaryColorHex;
  final String currencySymbol;
  final String supportPhone;
  final String supportEmail;
  final bool enableTelehealth;
  final bool enableInPersonVisits;
  final bool enableHomeVisits;
  final bool requireInsuranceId;
  final bool requirePatientPhone;
  final String apiBaseUrl;

  const WhiteLabelConfig({
    required this.hospitalBrandName,
    required this.tagline,
    required this.logoAssetOrUrl,
    required this.primaryColorHex,
    required this.currencySymbol,
    required this.supportPhone,
    required this.supportEmail,
    this.enableTelehealth = true,
    this.enableInPersonVisits = true,
    this.enableHomeVisits = true,
    this.requireInsuranceId = false,
    this.requirePatientPhone = true,
    this.apiBaseUrl = 'https://api.hospital-partner.com/v1',
  });

  /// Preset 1: Zyndio Executive Health & Longevity Institute
  static const WhiteLabelConfig zyndioDefault = WhiteLabelConfig(
    hospitalBrandName: 'ZYNDIO',
    tagline: 'Hospital & Specialist Hub',
    logoAssetOrUrl: '',
    primaryColorHex: '#6366F1',
    currencySymbol: '\$',
    supportPhone: '+1 (800) 555-0199',
    supportEmail: 'care@zyndio.health',
    enableTelehealth: true,
    enableInPersonVisits: true,
    enableHomeVisits: true,
    requireInsuranceId: false,
    requirePatientPhone: true,
    apiBaseUrl: 'https://api.zyndio.health/v1',
  );

  /// Preset 2: Metro General Health System (White-Label Demo)
  static const WhiteLabelConfig metroGeneral = WhiteLabelConfig(
    hospitalBrandName: 'METRO HEALTHCARE',
    tagline: 'Outpatient & Specialist Network',
    logoAssetOrUrl: '',
    primaryColorHex: '#0EA5E9',
    currencySymbol: '\$',
    supportPhone: '+1 (888) 432-5000',
    supportEmail: 'appointments@metrohealth.org',
    enableTelehealth: true,
    enableInPersonVisits: true,
    enableHomeVisits: false,
    requireInsuranceId: true,
    requirePatientPhone: true,
    apiBaseUrl: 'https://api.metrohealth.org/v2',
  );
}

/// Notifier to switch white-label hospital configs dynamically
class WhiteLabelConfigNotifier extends Notifier<WhiteLabelConfig> {
  @override
  WhiteLabelConfig build() => WhiteLabelConfig.zyndioDefault;

  void setConfig(WhiteLabelConfig config) {
    state = config;
  }
}

final whiteLabelConfigProvider = NotifierProvider<WhiteLabelConfigNotifier, WhiteLabelConfig>(() {
  return WhiteLabelConfigNotifier();
});
