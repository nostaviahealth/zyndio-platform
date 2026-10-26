import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BrandSDK {
  static final BrandSDK _instance = BrandSDK._internal();
  factory BrandSDK() => _instance;
  BrandSDK._internal();

  static const String _licenseCacheKey = 'ns_cached_license_status';
  static const String _licenseExpiryKey = 'ns_cached_license_expiry';
  
  bool _isInitialized = false;
  bool _isValidLicense = false;
  String _licenseKey = '';
  
  // Bring Your Own Key Configuration
  String _azureOpenAiKey = '';
  String _azureEndpoint = '';
  String _geminiKey = '';

  bool get isReady => _isInitialized && _isValidLicense;
  
  String get azureOpenAiKey => _azureOpenAiKey;
  String get azureEndpoint => _azureEndpoint;
  String get geminiKey => _geminiKey;

  /// Initializes the End-to-End SDK with Bring-Your-Own-Key configuration.
  static Future<void> initialize({
    required String licenseKey,
    String azureOpenAiKey = '',
    String azureEndpoint = '',
    String geminiKey = '',
  }) async {
    _instance._licenseKey = licenseKey;
    _instance._azureOpenAiKey = azureOpenAiKey;
    _instance._azureEndpoint = azureEndpoint;
    _instance._geminiKey = geminiKey;
    _instance._isInitialized = true;
    
    // Validate offline license
    await _instance._verifyLicenseLocallyAndRemotely();
  }

  Future<void> _verifyLicenseLocallyAndRemotely() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedStatus = prefs.getBool(_licenseCacheKey) ?? false;
    final cachedExpiryStr = prefs.getString(_licenseExpiryKey);

    if (cachedStatus && cachedExpiryStr != null) {
      final expiry = DateTime.parse(cachedExpiryStr);
      if (DateTime.now().isBefore(expiry)) {
        _isValidLicense = true;
      }
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.zyndio.example/v1/sdk/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'license_key': _licenseKey}),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool remoteValid = data['isValid'] ?? false;
        
        if (remoteValid) {
          _isValidLicense = true;
          await prefs.setBool(_licenseCacheKey, true);
          await prefs.setString(
            _licenseExpiryKey, 
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          );
        } else {
          _isValidLicense = false;
          await prefs.setBool(_licenseCacheKey, false);
        }
      }
    } catch (_) {
      if (_isValidLicense == false) {
        _isValidLicense = cachedStatus;
      }
    }
  }
}
