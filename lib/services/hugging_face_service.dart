import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class HuggingFaceService {
  // Your Hugging Face API token (keep it secure!)
  static const String _apiKey = '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';

  // Correct router endpoint for chat completions (OpenAI-compatible)
  static const String _baseUrl = 'https://router.huggingface.co/v1/chat/completions';

  // Updated list of free models with active Inference Providers (as of Dec 2025)
  static const List<String> _models = [
    'meta-llama/Llama-3.1-8B-Instruct',      // Best quality, highly recommended
    'Qwen/Qwen2.5-7B-Instruct',              // Excellent multilingual & fast
    'google/gemma-2-9b-it',                  // Solid Google model
    'HuggingFaceTB/SmolLM2-1.7B-Instruct',   // Small & fast fallback
  ];

  // Retry settings
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _requestTimeout = Duration(seconds: 20);

  static Future<String> generateSummary({
    required String name,
    required List<String> skills,
    required int workshopCount,
    required String rating,
  }) async {
    debugPrint('Starting AI summary generation');

    for (String model in _models) {
      debugPrint('Trying model: $model');

      String? result = await _tryGenerateWithModel(
        model,
        name: name,
        skills: skills,
        workshopCount: workshopCount,
        rating: rating,
      );

      if (result != null && result.trim().isNotEmpty) {
        debugPrint('Successfully generated summary using: $model');
        return result.trim();
      }

      debugPrint('Model $model failed or returned empty result, trying next...');
    }

    debugPrint('All models failed, using template fallback');
    return _generateTemplateSummary(name, skills, workshopCount, rating);
  }

  static Future<String?> _tryGenerateWithModel(
      String model, {
        required String name,
        required List<String> skills,
        required int workshopCount,
        required String rating,
      }) async {
    final String prompt = '''
You are an expert CV and LinkedIn profile writer specializing in educators, trainers, and workshop facilitators.

Write ONLY the professional summary itself (2-3 sentences, third person). Do NOT add any introduction, explanation, header, or extra text like "Here is your summary", "Professional Summary:", or "Here's a concise summary".

Directly start with the person's name or expertise.

Details to include:
- Name: $name
- Key skills/expertise: ${skills.join(', ')}
- Workshops conducted: $workshopCount
- Average participant rating: $rating out of 5

Style:
- Professional, confident, achievement-oriented
- Highlight teaching expertise, engaging delivery, and participant impact
- Avoid clichés like "passionate educator", "dedicated professional", or "committed to learning"
- Natural and concise tone

Example of exact desired output format:
John Doe is an accomplished workshop facilitator specializing in Flutter development and public speaking. He has delivered 12 interactive workshops on mobile app development and communication skills, consistently achieving an average participant rating of 4.8/5. John excels at breaking down complex topics into practical, hands-on learning experiences that drive real skill growth.
''';

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        debugPrint('Attempt ${attempt + 1} with model: $model');

        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
            'User-Agent': 'SkillX-App/1.0',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'max_tokens': 200,
            'temperature': 0.7,
            'top_p': 0.9,
            'stream': false,
          }),
        ).timeout(_requestTimeout);

        debugPrint('Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          // OpenAI-compatible response format
          String generatedText = data['choices']?[0]?['message']?['content'] ?? '';

          if (generatedText.isNotEmpty) {
            generatedText = _cleanGeneratedText(generatedText);

            if (generatedText.length > 20) {
              debugPrint('Generated summary: $generatedText');
              return generatedText;
            }
          }
        } else if (response.statusCode == 429) {
          debugPrint('Rate limited (429), retrying after delay...');
          await Future.delayed(const Duration(seconds: 5));
          continue;
        } else if (response.statusCode == 503) {
          debugPrint('Model loading (503), retrying...');
          await Future.delayed(const Duration(seconds: 8));
          continue;
        } else {
          debugPrint('API error: ${response.statusCode}');
          debugPrint('Response body: ${response.body}');
        }
      } catch (e) {
        debugPrint('Exception during request (attempt ${attempt + 1}): $e');
      }

      // Delay before next retry
      if (attempt < _maxRetries - 1) {
        await Future.delayed(_retryDelay * (attempt + 1));
      }
    }

    return null;
  }

  static String _cleanGeneratedText(String text) {
    text = text.trim();

    // Remove any leftover prompt parts
    if (text.contains('Person\'s name:')) {
      text = text.split('Person\'s name:').last;
    }

    // Limit to first 3 sentences
    final sentences = text.split(RegExp(r'[.!?]+'));
    if (sentences.length > 3) {
      text = sentences.take(3).join('. ').trim();
      if (!text.endsWith('.') && !text.endsWith('!') && !text.endsWith('?')) {
        text += '.';
      }
    }

    // Remove quotes if wrapped
    if (text.startsWith('"') && text.endsWith('"')) {
      text = text.substring(1, text.length - 1);
    }

    return text.trim();
  }

  static String _generateTemplateSummary(
      String name, List<String> skills, int workshopCount, String rating) {
    String summary = "$name is a passionate educator";

    if (skills.isNotEmpty) {
      final skillText = skills.length > 3
          ? "${skills.take(3).join(', ')} and more"
          : skills.join(', ');
      summary += " with expertise in $skillText";
    }

    summary += ". ";

    if (workshopCount > 0) {
      summary += "They have conducted $workshopCount workshops, earning an average rating of $rating out of 5. ";
    }

    summary += "Committed to sharing knowledge and fostering engaging learning experiences.";

    return summary;
  }
}