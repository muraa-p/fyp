import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  // ---------------------------------------------------------
  // CREATE USER PROFILE
  // ---------------------------------------------------------
  Future<void> createUserProfile(Map<String, dynamic> data) async {
    await _client.from('users').insert({
      'id': data['id'],
      'email': data['email'],
      'name': data['name'],
      'phone': data['phone'],
      'bio': data['bio'],
      'university': data['university'],
      'major': data['major'],
      'year': data['year'],
      'location': data['location'],
      'website': data['website'],
      'avatar_url': data['avatarUrl'], // Use avatar_url instead of avatar
      'skills_to_teach': data['skillsToTeach'],
      'skills_to_learn': data['skillsToLearn'],
      'social': data['social'],
    });
  }

  // ---------------------------------------------------------
  // GET USER PROFILE
  // ---------------------------------------------------------
  Future<Map<String, dynamic>> getUserProfile(String id) async {
    final response = await _client.from('users').select().eq('id', id).single();

    return {
      "id": response['id'],
      "email": response['email'],
      "name": response['name'],
      "phone": response['phone'],
      "bio": response['bio'],
      "university": response['university'],
      "major": response['major'],
      "year": response['year'],
      "location": response['location'],
      "website": response['website'],
      "avatar_url": response['avatar_url'], // Make sure to use avatar_url
      "skillsToTeach": response['skills_to_teach'] ?? [],
      "skillsToLearn": response['skills_to_learn'] ?? [],
      "social": response['social'] ??
          {
            "instagram": "",
            "twitter": "",
            "linkedin": "",
            "github": "",
          }
    };
  }

  // ---------------------------------------------------------
  // UPDATE USER PROFILE
  // ---------------------------------------------------------
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    await _client.from('users').update({
      'email': data['email'],
      'name': data['name'],
      'phone': data['phone'],
      'bio': data['bio'],
      'university': data['university'],
      'major': data['major'],
      'year': data['year'],
      'location': data['location'],
      'website': data['website'],
      'avatar_url': data['avatarUrl'], // Updated to use avatar_url
      'skills_to_teach': data['skillsToTeach'],
      'skills_to_learn': data['skillsToLearn'],
      'social': data['social'],
    }).eq('id', data['id']);
  }

  // ---------------------------------------------------------
  // UPDATE AVATAR ONLY
  // ---------------------------------------------------------
  Future<void> updateAvatar(String userId, String url) async {
    await _client.from('users').update({
      'avatar': url, // FIXED
    }).eq('id', userId);
  }

  // ---------------------------------------------------------
  // SEARCH USERS
  // ---------------------------------------------------------
  Future<List<Map<String, dynamic>>> searchUsers(String keyword) async {
    final result = await _client
        .from('users')
        .select()
        .or("name.ilike.%$keyword%,skills_to_teach.cs.{$keyword}");

    return List<Map<String, dynamic>>.from(result);
  }
}
