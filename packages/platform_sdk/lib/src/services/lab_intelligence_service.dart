import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/zyndio_config.dart';
import 'pdf_to_image_service.dart';

class LabIntelligenceService {
  static final LabIntelligenceService _instance = LabIntelligenceService._internal();
  factory LabIntelligenceService() => _instance;
  LabIntelligenceService._internal();

  /// Direct REST call using BYOK to Azure OpenAI for vision parsing
  Future<String?> _callAzureLLM(List<Map<String, dynamic>> messages) async {
    final sdk = BrandSDK();
    if (!sdk.isReady) throw Exception("Zyndio SDK License not verified.");
    if (sdk.azureOpenAiKey.isEmpty || sdk.azureEndpoint.isEmpty) {
      throw Exception("BYOK Missing: Azure OpenAI Key or Endpoint not configured.");
    }

    try {
      final url = Uri.parse(sdk.azureEndpoint);
      final body = <String, dynamic>{
        "messages": messages,
        "max_tokens": 4096, // Or higher if endpoint allows
        "temperature": 0.0, // Strict extraction
        "response_format": {"type": "json_object"},
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'api-key': sdk.azureOpenAiKey,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 120));

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

  /// Master function: takes a PDF file, converts it to images, and extracts structured biomarkers.
  Future<Map<String, dynamic>?> extractLabReport(File pdfFile, {Function(int, int)? onProgress}) async {
    try {
      // 1. PDF to Image Conversion
      final List<File> images = await PdfToImageService.convertPdfToImages(
        pdfFile.path, 
        onProgress: onProgress,
      );

      if (images.isEmpty) {
        debugPrint("No images extracted from PDF.");
        return null;
      }

      // 2. Build the Azure Payload
      const String systemPrompt = '''
You are a meticulous clinical medical data extraction assistant. Your job is to extract EVERY single test result from the provided lab report images with surgical precision.

CRITICAL RULES:
1. READ EVERY PAGE from start to finish. Do NOT skip any test result.
2. Extract EXACTLY what the lab printed — do not invent, assume, or normalize values.
3. Preserve the lab's own SECTION HEADERS as categories (e.g. "Complete Blood Count", "Liver Function Test", "Lipid Profile", "Thyroid Profile", "Renal Function Test", "Urine Routine", etc.).
4. For each biomarker, extract:
   - name: The exact test name as printed on the report
   - value: The numeric or text value as printed
   - unit: The unit as printed (e.g. mg/dL, U/L, %, g/dL)
   - referenceRange: The reference range AS PRINTED on the report (e.g. "70-100", "<150", ">40"). This is CRITICAL. Perform a surgical search: look at headers, footnotes, or distant columns. If it is on the page, you MUST find it.
   - status: MUST be strictly either 'Outlier' (if the value is flagged as High, Low, Abnormal, or Critical) or 'In-range' (if the value is Normal or within the reference range). DO NOT use any other words like 'Normal' or 'High' for this field.
5. Find the report title/lab name, collection date ("Sample Date", "Collection Date", "Drawn Date"), patient age, and gender.
6. If a biomarker appears under multiple sections, include it in the FIRST section where it appears.
7. Use strictly professional medical terminology. Preserve original test names. Aggressively search for reference ranges even in small print or footnotes.

OUTPUT FORMAT (strict JSON):
{
  "title": "Report title or lab name",
  "date": "YYYY-MM-DD (collection/sample date)",
  "age": number | null,
  "gender": "Male" | "Female" | null,
  "labName": "Name of the laboratory if visible" | null,
  "categories": [
    {
      "name": "Section header as printed (e.g. Complete Blood Count)",
      "markers": [
        {
          "name": "Test name as printed",
          "value": "Value as printed (number or text)",
          "unit": "Unit as printed",
          "referenceRange": "Reference range as printed on report",
          "status": "Outlier" | "In-range"
        }
      ]
    }
  ]
}

If a test does not clearly belong to any section header, group it under "General" or "Other Tests".
''';

      final List<Map<String, dynamic>> messages = [
        {"role": "system", "content": systemPrompt},
        {
          "role": "user",
          "content": [
            {"type": "text", "text": "Extract every single test result from these lab report pages. Preserve the lab's own section headers, reference ranges, units, and flags exactly as printed."},
            ...await Future.wait(images.map((image) async {
              final bytes = await image.readAsBytes();
              final base64Image = base64Encode(bytes);
              return {
                "type": "image_url",
                "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
              };
            }))
          ]
        }
      ];

      // 3. Make the BYOK Call
      final responseText = await _callAzureLLM(messages);

      // Clean up temporary images
      for (var file in images) {
        if (file.existsSync()) file.deleteSync();
      }

      if (responseText != null) {
        return jsonDecode(responseText);
      }
      return null;
    } catch (e) {
      debugPrint("ExtractLabReport Error: \$e");
      return null;
    }
  }
}
