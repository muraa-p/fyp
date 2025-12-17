import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class HuggingFaceService {
  static const String _apiKey = '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';
  static const String _baseUrl = 'https://router.huggingface.co/v1/chat/completions';

  static const List<String> _models = [
    'meta-llama/Llama-3.1-8B-Instruct',
    'Qwen/Qwen2.5-7B-Instruct',
    'google/gemma-2-9b-it',
    'HuggingFaceTB/SmolLM2-1.7B-Instruct',
  ];

  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _requestTimeout = Duration(seconds: 20);

  // Professional Summary
  static Future<String> generateSummary({
    required String name,
    required List<String> skills,
    required int workshopCount,
    required String rating,
  }) async {
    debugPrint('Starting AI professional summary generation');
    for (String model in _models) {
      String? result = await _tryGenerateWithModel(
        model: model,
        prompt: '''
You are an expert CV and LinkedIn profile writer specializing in educators, trainers, and workshop facilitators.

Write ONLY the professional summary itself (2-3 sentences, third person). Do NOT add any introduction, explanation, header, or extra text.

Directly start with the person's name.

Details:
- Name: $name
- Key skills: ${skills.join(', ')}
- Workshops conducted: $workshopCount
- Average rating: $rating/5

Style: Professional, confident, achievement-focused. Highlight teaching expertise and impact.

Example:
$name is an accomplished workshop facilitator specializing in ${skills.take(3).join(', ')}. With a track record of delivering $workshopCount engaging workshops earning an average rating of $rating/5, $name excels at translating complex concepts into practical, hands-on learning experiences that drive participant growth.
''',
      );

      if (result != null && result.trim().isNotEmpty) return result.trim();
    }
    return _generateTemplateSummary(name, skills, workshopCount, rating);
  }

  // Skills Section
  static Future<String> generateSkillsSection({
    required List<Map<String, dynamic>> skillsData,
  }) async {
    debugPrint('Starting AI skills section generation');

    final skillsText = skillsData.map((s) =>
    '${s['name']} (${s['level']}, ${s['endorsements']} endorsements, ${s['workshops'].length} workshops)')
        .join('\n');

    for (String model in _models) {
      String? result = await _tryGenerateWithModel(
        model: model,
        prompt: '''
You are a professional CV writer. Generate ONLY a bullet-point list for the Skills section of a CV.

Do NOT add any introduction, header, explanation, or extra text. Start directly with bullets (- or •).

Input skills:
$skillsText

Output format:
• Skill Name — Level: Description of proficiency and evidence (e.g., taught in X workshops, Y endorsements)

Make descriptions concise, professional, and evidence-based. Use strong verbs.
''',
      );

      if (result != null && result.trim().isNotEmpty) return result.trim();
    }

    return skillsData.map((s) => '• ${s['name']} (${s['level']})').join('\n');
  }

  // Experience Section
  static Future<String> generateExperienceSection({
    required List<Map<String, dynamic>> taughtWorkshops,
    required String name,
  }) async {
    debugPrint('Starting AI experience section generation');

    final workshopsText = taughtWorkshops.map((w) =>
    'Title: ${w['title']}\nDate: ${w['date']}\nCategory: ${w['category'] ?? 'General'}\nDuration: ${w['duration'] ?? 'N/A'}\nDescription: ${w['description'] ?? ''}\nSkills: ${(w['skills'] as List?)?.join(', ') ?? ''}\nRating: ${w['rating'] ?? 0}')
        .join('\n\n');

    for (String model in _models) {
      String? result = await _tryGenerateWithModel(
        model: model,
        prompt: '''
You are a professional CV writer. Generate ONLY the Experience section content for a CV (bullet-point descriptions under each workshop).

Do NOT add headers, introductions, or extra text. Output in this exact format:

Workshop Title | Dates
Workshop Instructor
• Bullet point achievement/impact
• Another bullet

Input workshops:
$workshopsText

For each workshop, create 2-4 strong, quantifiable bullet points highlighting teaching impact, participant engagement, and outcomes. Use action verbs (Delivered, Facilitated, Designed).
''',
      );

      if (result != null && result.trim().isNotEmpty) return result.trim();
    }

    return taughtWorkshops.map((w) =>
    '${w['title']} | ${_formatDate(w['date'])}\nWorkshop Instructor\n• Delivered interactive workshop on ${(w['skills'] as List?)?.join(', ') ?? 'relevant skills'}')
        .join('\n\n');
  }

  // Education Section
  static Future<String> generateEducationSection({
    required Map<String, dynamic> userProfile,
  }) async {
    debugPrint('Starting AI education section generation');

    final university = userProfile['university'] ?? '';
    final major = userProfile['major'] ?? '';
    final year = userProfile['year'] ?? '';

    if (university.isEmpty && major.isEmpty && year.isEmpty) {
      return 'Education details not provided.';
    }

    for (String model in _models) {
      String? result = await _tryGenerateWithModel(
        model: model,
        prompt: '''
You are a professional CV writer. Generate ONLY the Education section content.

Do NOT add any introduction or header. Output directly:

$university
$major${year.isNotEmpty ? ', Graduated $year' : ''}

If limited info, enhance professionally but stay factual.
''',
      );

      if (result != null && result.trim().isNotEmpty) return result.trim();
    }

    return '$university\n$major${year.isNotEmpty ? ', Graduated $year' : ''}';
  }

  // Achievements Section
  static Future<String> generateAchievementsSection({
    required List<Map<String, dynamic>> achievements,
  }) async {
    debugPrint('Starting AI achievements section generation');

    final achievementsText = achievements
        .map((a) => '${a['title']}: ${a['desc']} (Earned: ${a['earned']})')
        .join('\n');

    for (String model in _models) {
      String? result = await _tryGenerateWithModel(
        model: model,
        prompt: '''
You are a professional CV writer. Generate ONLY bullet points for the Achievements/Awards section.

Do NOT add introduction or header. Start directly with bullets.

Input:
$achievementsText

Output:
• Achievement Title — Brief impactful description (Earned Date)

Enhance phrasing to be more professional and quantifiable where possible.
''',
      );

      if (result != null && result.trim().isNotEmpty) return result.trim();
    }

    return achievements
        .map((a) => '• ${a['title']} — ${a['desc']} (Earned: ${a['earned']})')
        .join('\n');
  }

  // NEW: Workshop Summary for WorkshopDetailScreen
  static Future<String> summarizeWorkshop({
    required String title,
    required String description,
    required List<String> skills,
    required String duration,
    required String difficulty,
  }) async {
    debugPrint('Generating workshop summary...');

    final prompt = '''
You are an expert at summarizing educational workshops.

Create a concise, engaging summary (3-5 sentences) of this workshop for potential participants.

Workshop Title: $title
Duration: $duration
Difficulty: $difficulty
Skills Covered: ${skills.join(', ')}
Full Description: $description

Summary should be:
- Exciting and inviting
- Highlight key benefits and what participants will learn
- Professional yet friendly tone
- Start directly with the content (no "Here is a summary" or headers)

Example:
"$title is a hands-on workshop where you'll master ${skills.take(3).join(', ')} through practical projects. Perfect for $difficulty learners, this $duration session will guide you from fundamentals to building real applications with expert instruction."
''';

    for (String model in _models) {
      String? result = await _tryGenerateWithModel(model: model, prompt: prompt);
      if (result != null && result.trim().isNotEmpty) {
        return _cleanGeneratedText(result);
      }
    }

    // Fallback summary
    return "Join this $difficulty-level workshop on $title! You'll learn ${skills.take(3).join(', ')} in just $duration through interactive, hands-on practice.";
  }

  // Core generation method (shared)
  static Future<String?> _tryGenerateWithModel({
    required String model,
    required String prompt,
  }) async {
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
            'messages': [{'role': 'user', 'content': prompt}],
            'max_tokens': 400,
            'temperature': 0.7,
            'top_p': 0.9,
          }),
        ).timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          String text = data['choices']?[0]?['message']?['content'] ?? '';

          if (text.isNotEmpty) {
            text = _cleanGeneratedText(text);
            if (text.length > 10) return text;
          }
        } else if ([429, 503].contains(response.statusCode)) {
          await Future.delayed(Duration(seconds: response.statusCode == 429 ? 5 : 8));
          continue;
        }
      } catch (e) {
        debugPrint('Error: $e');
      }

      if (attempt < _maxRetries - 1) {
        await Future.delayed(_retryDelay * (attempt + 1));
      }
    }
    return null;
  }

  static String _cleanGeneratedText(String text) {
    text = text.trim();
    final prefixes = [
      'Here is',
      'Here are',
      'Skills Section:',
      'Experience:',
      'Education:',
      'Achievements:',
      'Professional Summary:',
      'The skills section',
      'Below is'
    ];
    for (var prefix in prefixes) {
      if (text.toLowerCase().startsWith(prefix.toLowerCase())) {
        text = text.substring(prefix.length).trim();
        if (text.startsWith(':')) text = text.substring(1).trim();
      }
    }
    if (text.startsWith('"') && text.endsWith('"')) {
      text = text.substring(1, text.length - 1);
    }
    return text.trim();
  }

  static String _generateTemplateSummary(String name, List<String> skills, int workshopCount, String rating) {
    return "$name is a skilled workshop facilitator with expertise in ${skills.join(', ')}. Conducted $workshopCount workshops with an average rating of $rating/5.";
  }

  static String _formatDate(dynamic date) {
    if (date == null) return 'Date TBD';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.month}/${d.year}';
    } catch (e) {
      return 'Date TBD';
    }
  }
}