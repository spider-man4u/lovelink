import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/scene_model.dart';

class SceneDetectionService {
  final String _apiKey;
  final String _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  SceneDetectionService(this._apiKey);

  Future<SceneModel> analyzeMessage(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      'Analyze this roleplay/chat message and extract scene details. Return ONLY valid JSON without markdown formatting or code blocks:\n'
                          '{\n'
                          '  "scene": "one word location (cafe, park, bedroom, beach, balcony, etc.)",\n'
                          '  "emotion": "dominant emotion (romantic, happy, excited, comforting, emotional, funny, angry, sad)",\n'
                          '  "weather": "weather if mentioned or inferred (sunny, rainy, cloudy, snowy, night, clear) or null",\n'
                          '  "time": "time of day (morning, afternoon, evening, night) or null",\n'
                          '  "activity": "current activity if mentioned (walking, cooking, reading, hugging, etc.) or null",\n'
                          '  "tags": ["relevant", "keywords", "for", "image", "search"]\n'
                          '}\n\n'
                          'Message: "$text"',
                }
              ],
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 200,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final textResponse =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '{}';

        // Clean response - remove markdown formatting if present
        final cleanJson = textResponse
            .toString()
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final parsed = jsonDecode(cleanJson);
        return SceneModel(
          scene: parsed['scene']?.toString().toLowerCase() ?? 'unknown',
          emotion: parsed['emotion']?.toString().toLowerCase() ?? 'neutral',
          weather: parsed['weather']?.toString().toLowerCase(),
          time: parsed['time']?.toString().toLowerCase(),
          activity: parsed['activity']?.toString().toLowerCase(),
          tags: parsed['tags'] != null
              ? List<String>.from(parsed['tags'].map((t) => t.toString().toLowerCase()))
              : [],
        );
      } else {
        return _fallbackAnalysis(text);
      }
    } catch (e) {
      return _fallbackAnalysis(text);
    }
  }

  SceneModel _fallbackAnalysis(String text) {
    final lower = text.toLowerCase();
    final tags = <String>[];

    // Simple keyword-based fallback
    String scene = 'unknown';
    if (_containsAny(lower, ['cafe', 'coffee', 'restaurant', 'dinner', 'lunch'])) {
      scene = 'cafe';
    } else if (_containsAny(lower, ['bed', 'bedroom', 'sleep', 'blanket', 'pillow'])) {
      scene = 'bedroom';
    } else if (_containsAny(lower, ['park', 'walk', 'garden', 'tree'])) {
      scene = 'park';
    } else if (_containsAny(lower, ['beach', 'sea', 'ocean', 'sand', 'wave'])) {
      scene = 'beach';
    } else if (_containsAny(lower, ['rain', 'rainy', 'umbrella', 'puddle'])) {
      scene = 'rain';
    } else if (_containsAny(lower, ['kiss', 'hug', 'hold', 'embrace', 'cuddle'])) {
      scene = 'romantic';
    }

    String emotion = 'neutral';
    if (_containsAny(lower, ['love', 'miss', 'beautiful', 'romantic', 'sweet'])) {
      emotion = 'romantic';
    } else if (_containsAny(lower, ['happy', 'joy', 'excited', 'wonderful'])) {
      emotion = 'happy';
    } else if (_containsAny(lower, ['sad', 'cry', 'miss', 'lonely'])) {
      emotion = 'emotional';
    } else if (_containsAny(lower, ['angry', 'mad', 'frustrated'])) {
      emotion = 'angry';
    }

    if (scene != 'unknown') tags.add(scene);
    if (emotion != 'neutral') tags.add(emotion);

    return SceneModel(
      scene: scene,
      emotion: emotion,
      tags: tags,
    );
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  bool isImportantMoment(String text) {
    final lower = text.toLowerCase();
    final triggers = [
      'happy birthday',
      'love you',
      'i love',
      'propose',
      'marry',
      'anniversary',
      'kiss',
      'hug',
      'miss you',
      'airport',
      'reunion',
      'surprise',
      'gift',
      'date',
      'promise',
      'forever',
    ];
    return triggers.any((t) => lower.contains(t));
  }
}
