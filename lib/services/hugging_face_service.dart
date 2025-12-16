import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class HuggingFaceService {
  static const String _apiKey = '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';
  static const String _baseUrl = 'https://router.huggingface.co/models';

  static Future<String> generateSummary({
    required String name,
    required List<String> skills,
    required int workshopCount,
    required String rating,
  }) async {
    try {
      // Using a better model for text generation
      final response = await http.post(
        Uri.parse('$_baseUrl/mistralai/Mistral-7B-Instruct-v0.1'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': '''<s>[INST] Generate a professional summary for a CV based on the following information:

Name: $name
Skills: ${skills.join(', ')}
Workshops conducted: $workshopCount
Average rating: $rating/5

The summary should be:
- Concise (2-3 sentences)
- Professional
- Highlight key achievements and expertise
- Focus on communication skills, teaching abilities, and technical knowledge
- Written in third person
- Suitable for a LinkedIn profile or professional CV [/INST]''',
          'parameters': {
            'max_new_tokens': 150,
            'temperature': 0.7,
            'do_sample': true,
          }
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          String generatedText = data[0]['generated_text'] ?? '';
          // Clean up the response to get just the summary
          if (generatedText.contains('[/INST]')) {
            generatedText = generatedText.split('[/INST]')[1].trim();
          }
          return generatedText;
        }
        return 'Failed to generate summary';
      } else {
        debugPrint('HuggingFace API error: ${response.statusCode} - ${response.body}');
        return 'Failed to generate summary';
      }
    } catch (e) {
      debugPrint('Error generating AI summary: $e');
      return 'Failed to generate summary';
    }
  }
}