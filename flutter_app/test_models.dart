import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const apiKey = String.fromEnvironment('GEMINI_API_KEY');
  // Using the model we decided on
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-latest:generateContent?key=$apiKey');

  print('Testing generation with: $url');
  
  final headers = {'Content-Type': 'application/json'};
  final body = jsonEncode({
    "contents": [{
      "parts": [{"text": "Say 'Hello, World!' and nothing else."}]
    }]
  });

  try {
    final response = await http.post(url, headers: headers, body: body);
    print('Response Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      print("SUCCESS: Model is working.");
    } else {
      print("FAILURE: Model returned error.");
    }
  } catch (e) {
    print('Exception: $e');
  }
}
