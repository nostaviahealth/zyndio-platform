import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final voiceServiceProvider = Provider((ref) => VoiceService());

class VoiceService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // ElevenLabs Configuration
  String _apiKey = const String.fromEnvironment('ELEVENLABS_API_KEY');
  String _voiceId = 'oO7sLA3dWfQXsKeSAjpA';
  
  void setApiKey(String key) => _apiKey = key;
  void setVoiceId(String id) => _voiceId = id;

  Future<void> speak(String text) async {
    if (_apiKey.isEmpty) {
      debugPrint('ElevenLabs API Key is missing. Skipping voice.');
      return;
    }

    if (text.isEmpty) return;

    try {
      // 1. Prepare ElevenLabs API call
      final url = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId/stream');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': _apiKey,
          'accept': 'audio/mpeg',
        },
        body: jsonEncode({
          "text": text,
          "model_id": "eleven_monolingual_v1",
          "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.75
          }
        }),
      );

      if (response.statusCode == 200) {
        // 2. Save to temporary file for just_audio
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/voice_response.mp3';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // 3. Play the audio
        await _audioPlayer.setFilePath(filePath);
        await _audioPlayer.play();
      } else {
        debugPrint('ElevenLabs Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('VoiceService Exception: $e');
    }
  }

  void stop() {
    _audioPlayer.stop();
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
