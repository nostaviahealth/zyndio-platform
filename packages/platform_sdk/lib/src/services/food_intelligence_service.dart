import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/zyndio_config.dart';
import '../models/food_analysis.dart';

class FoodIntelligenceService {
  static final FoodIntelligenceService _instance = FoodIntelligenceService._internal();
  factory FoodIntelligenceService() => _instance;
  FoodIntelligenceService._internal();

  /// Helper to extract clean JSON from a markdown-wrapped string
  String cleanJson(String text) {
    String cleaned = text.trim();
    if (cleaned.contains('```json')) {
      final start = cleaned.indexOf('```json') + 7;
      final end = cleaned.lastIndexOf('```');
      if (end > start) cleaned = cleaned.substring(start, end);
    } else if (cleaned.contains('```')) {
      final start = cleaned.indexOf('```') + 3;
      final end = cleaned.lastIndexOf('```');
      if (end > start) cleaned = cleaned.substring(start, end);
    }
    cleaned = cleaned.trim();
    if (!cleaned.startsWith('{')) {
      final firstBrace = cleaned.indexOf('{');
      final lastBrace = cleaned.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      }
    }
    return cleaned.trim();
  }

  /// Direct REST call using BYOK to Azure OpenAI
  Future<String?> _callAzureLLM(List<Map<String, dynamic>> messages, {bool jsonMode = true}) async {
    final sdk = BrandSDK();
    if (!sdk.isReady) throw Exception("Zyndio SDK License not verified.");
    if (sdk.azureOpenAiKey.isEmpty || sdk.azureEndpoint.isEmpty) {
      throw Exception("BYOK Missing: Azure OpenAI Key or Endpoint not configured.");
    }

    try {
      final url = Uri.parse(sdk.azureEndpoint);
      final body = <String, dynamic>{
        "messages": messages,
        "max_tokens": 4096,
        "temperature": 0.2,
      };
      
      if (jsonMode) {
        body["response_format"] = {"type": "json_object"};
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'api-key': sdk.azureOpenAiKey,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        debugPrint('Azure API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Azure API Exception: $e');
      return null;
    }
  }

  /// Analyze food from text log
  Future<FoodAnalysis?> analyzeFoodText(String description) async {
    final prompt = '''
    Analyze this food/meal description: "$description"
    
    Output strictly as JSON matching this structure:
    {"food_name":str,"calories":int,"macros":{"protein":int,"carbs":int,"fat":int},"metabolic_impact":{"digestion_time":"Rapid|Moderate|Slow","energy_curve":"Spike|Sustained|Crash"},"score":0-100,"intelligence_insight":"personalized, 3-4 lines","toxins":[{"name":str,"details":str,"severity":"High|Medium|Low"}],"upf_analysis":{"score":0-10,"level":"Whole Food|Minimally Processed|Processed|Ultra-Processed","additives":[str],"verdict":str},"circadian_match":{"meal_time":"Morning|Afternoon|Evening|Late Night","match":"Excellent|Good|Fair|Poor","match_score":0-100,"reason":str,"recommendation":str},"bio_hack":{"tip":str,"mechanism":str,"timing":str,"potency_percent":int},"hormonal_impact":{"insulin":{"name":"Insulin","response":"Spike|Moderate Rise|Stable|Decrease","impact":"positive|neutral|negative","detail":str},"leptin":{"name":"Leptin","response":"Increase|Stable|Blunted Response","impact":"positive|neutral|negative","detail":str},"ghrelin":{"name":"Ghrelin","response":"Suppressed|Stable|Elevated","impact":"positive|neutral|negative","detail":str}},"bioavailability":{"absorption_score":0-100,"tips":[{"type":"Synergy|Anti-Nutrient|Preparation","title":str,"description":str,"impact":"positive|negative"}]},"longevity_impact":{"longevity_score":0-100,"sirtuin_effect":"Activating|Neutral|Suppressing","mtor_effect":"Inhibiting|Neutral|Activating","inflammation_effect":"Anti-inflammatory|Neutral|Pro-inflammatory","longevity_summary":str,"longevity_credit":0}}
    ''';

    final messages = [
      {"role": "system", "content": "You are the Zyndio Food Intelligence AI. Strict JSON output only."},
      {"role": "user", "content": prompt}
    ];

    final response = await _callAzureLLM(messages);
    if (response != null) {
      try {
        final jsonMap = jsonDecode(cleanJson(response));
        return FoodAnalysis.fromJson(jsonMap);
      } catch (e) {
        debugPrint("Parse Error: $e");
      }
    }
    return null;
  }

  /// Analyze food from image using vision model
  Future<FoodAnalysis?> analyzeFoodImage(File image) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final prompt = '''
    Analyze this food image. Provide macronutrients, caloric estimates, and metabolic impact.
    Output strictly as JSON matching this structure:
    {"food_name":str,"calories":int,"macros":{"protein":int,"carbs":int,"fat":int},"metabolic_impact":{"digestion_time":"Rapid|Moderate|Slow","energy_curve":"Spike|Sustained|Crash"},"score":0-100,"intelligence_insight":"personalized, 3-4 lines","toxins":[{"name":str,"details":str,"severity":"High|Medium|Low"}],"upf_analysis":{"score":0-10,"level":"Whole Food|Minimally Processed|Processed|Ultra-Processed","additives":[str],"verdict":str},"circadian_match":{"meal_time":"Morning|Afternoon|Evening|Late Night","match":"Excellent|Good|Fair|Poor","match_score":0-100,"reason":str,"recommendation":str},"bio_hack":{"tip":str,"mechanism":str,"timing":str,"potency_percent":int},"hormonal_impact":{"insulin":{"name":"Insulin","response":"Spike|Moderate Rise|Stable|Decrease","impact":"positive|neutral|negative","detail":str},"leptin":{"name":"Leptin","response":"Increase|Stable|Blunted Response","impact":"positive|neutral|negative","detail":str},"ghrelin":{"name":"Ghrelin","response":"Suppressed|Stable|Elevated","impact":"positive|neutral|negative","detail":str}},"bioavailability":{"absorption_score":0-100,"tips":[{"type":"Synergy|Anti-Nutrient|Preparation","title":str,"description":str,"impact":"positive|negative"}]},"longevity_impact":{"longevity_score":0-100,"sirtuin_effect":"Activating|Neutral|Suppressing","mtor_effect":"Inhibiting|Neutral|Activating","inflammation_effect":"Anti-inflammatory|Neutral|Pro-inflammatory","longevity_summary":str,"longevity_credit":0}}
    ''';

    final messages = [
      {"role": "system", "content": "You are the Zyndio Food Intelligence AI. Strict JSON output only."},
      {
        "role": "user",
        "content": [
          {"type": "text", "text": prompt},
          {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,$base64Image"}}
        ]
      }
    ];

    final response = await _callAzureLLM(messages);
    if (response != null) {
      try {
        final jsonMap = jsonDecode(cleanJson(response));
        return FoodAnalysis.fromJson(jsonMap);
      } catch (e) {
        debugPrint("Parse Error: $e");
      }
    }
    return null;
  }
}
