import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Fetch a user's profile data by their ID
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      final response =
          await _supabase.from('users').select().eq('id', userId).single();
      return response;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // No rows found
        return null;
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // Fetch user stats (workshops taught, students taught, XP, badges)
  Future<Map<String, int>> fetchUserStats(String userId) async {
    // 1. Workshops Taught
    final workshopsTaughtCount = await _supabase
        .from('workshops')
        .select('id')
        .eq('creator_id', userId)
        .count(CountOption.exact);

    // 2. Students Taught (Corrected Logic)
    // First, get the actual list of workshop IDs created by the user
    final workshopIdsData =
        await _supabase.from('workshops').select('id').eq('creator_id', userId);

    // Extract the IDs into a simple list of strings
    final List<String> workshopIdList =
        workshopIdsData.map((item) => item['id'] as String).toList();

    // Now, use that list in the main query
    final studentsTaughtCount = await _supabase
        .from('workshop_enrollments')
        .select('user_id')
        .inFilter(
            'workshop_id', workshopIdList) // ✅ FIX: Now it's a List<String>
        .count(CountOption.exact);

    // 3. Total XP
    final xpData = await _supabase
        .from('leaderboard')
        .select('xp')
        .eq('user_id', userId)
        .maybeSingle();

    // 4. Badges Earned
    final badgesEarnedCount = await _supabase
        .from('achievements')
        .select('id')
        .eq('user_id', userId)
        .eq('earned', true)
        .count(CountOption.exact);

    return {
      "workshopsTaught": workshopsTaughtCount.count,
      "studentsTaught": studentsTaughtCount.count,
      "totalXp": xpData?['xp'] ?? 0,
      "badgesEarned": badgesEarnedCount.count,
    };
  }

  // Fetch user achievements/badges
  Future<List<Map<String, dynamic>>> fetchAchievements(String userId) async {
    return await _supabase
        .from('achievements')
        .select()
        .eq('user_id', userId)
        .eq('earned', true);
  }

  // Fetch workshops created by the user
  Future<List<Map<String, dynamic>>> fetchCreatedWorkshops(
      String userId) async {
    final workshops = await _supabase
        .from('workshops')
        .select('id, title, workshop_enrollments(count)')
        .eq('creator_id', userId)
        .order('created_at', ascending: false);

    return workshops.map((ws) {
      return {
        "id": ws['id'],
        "title": ws['title'],
        "participants": ws['workshop_enrollments'][0]['count'] ?? 0,
      };
    }).toList();
  }

// Replace the fetchEnrolledWorkshops method in SupabaseService with this:
  Future<List<Map<String, dynamic>>> fetchEnrolledWorkshops(
      String userId) async {
    try {
      final data = await _supabase.from('workshop_enrollments').select('''
          workshops!inner(
            id,
            title,
            description,
            date,
            time,
            duration,
            image_url,
            status,
            creator_id,
            users!inner(
              id,
              name,
              avatar_url
            )
          ),
          enrolled_at,
          status
        ''').eq('user_id', userId).order('enrolled_at', ascending: false);

      // Transform the nested data to a flatter structure
      List<Map<String, dynamic>> workshops = [];
      for (var enrollment in data) {
        final workshop = Map<String, dynamic>.from(enrollment['workshops']);
        final creator = workshop['users'] as Map<String, dynamic>;

        // Add the creator info directly to the workshop object
        workshop['users'] = creator;

        // Add enrollment info
        workshop['enrollment_status'] = enrollment['status'];
        workshop['enrolled_at'] = enrollment['enrolled_at'];

        workshops.add(workshop);
      }

      return workshops;
    } catch (e) {
      print('Error fetching enrolled workshops: $e');
      return [];
    }
  }

  // Fetch user skills with endorsements
  Future<List<Map<String, dynamic>>> fetchUserSkills(String userId) async {
    final userData = await _supabase
        .from('users')
        .select('skills_to_teach')
        .eq('id', userId)
        .single();

    if (userData['skills_to_teach'] == null ||
        userData['skills_to_teach'].isEmpty) {
      return [];
    }

    final skillsToTeach = List<String>.from(userData['skills_to_teach']);
    List<Map<String, dynamic>> skillsWithEndorsements = [];

    for (String skillName in skillsToTeach) {
      final endorsementsCount = await _supabase
          .from('endorsements')
          .select('id')
          .eq('endorsed_user', userId)
          .eq('skill', skillName)
          .count(CountOption.exact);

      final workshopsCount = await _supabase
          .from('workshops')
          .select('id')
          .eq('creator_id', userId)
          .contains('skills', [skillName]).count(CountOption.exact);

      String level = "Beginner";
      if (endorsementsCount.count > 40) {
        level = "Expert";
      } else if (endorsementsCount.count > 20)
        level = "Advanced";
      else if (endorsementsCount.count > 5) level = "Intermediate";

      skillsWithEndorsements.add({
        "name": skillName,
        "level": level,
        "endorsements": endorsementsCount.count,
        "workshops": workshopsCount.count,
      });
    }
    return skillsWithEndorsements;
  }

// Replace the fetchReviews method in SupabaseService with this:
  Future<List<Map<String, dynamic>>> fetchReviews(String userId) async {
    try {
      final data = await _supabase
          .from('workshop_ratings')
          .select('''
          rating,
          review,
          created_at,
          workshops!inner(
            title
          ),
          users!inner(
            name
          )
        ''')
          .eq('workshops.creator_id', userId)
          .order('created_at', ascending: false);

      // Transform the nested data to a flatter structure
      List<Map<String, dynamic>> reviews = [];
      for (var review in data) {
        final workshop = review['workshops'] as Map<String, dynamic>;
        final user = review['users'] as Map<String, dynamic>;

        // Create a flattened review object
        final flattenedReview = {
          'rating': review['rating'],
          'review': review['review'],
          'created_at': review['created_at'],
          'workshops': workshop,
          'users': user,
        };

        reviews.add(flattenedReview);
      }

      return reviews;
    } catch (e) {
      print('Error fetching reviews: $e');
      return [];
    }
  }
}
