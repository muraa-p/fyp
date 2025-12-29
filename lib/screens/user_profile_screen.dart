import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

String _formatRelativeDate(String? isoString) {
  if (isoString == null) return 'Unknown date';
  final date = DateTime.tryParse(isoString);
  if (date == null) return 'Unknown date';

  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inDays == 0) return 'Today';
  if (difference.inDays == 1) return 'Yesterday';
  if (difference.inDays < 7) return '${difference.inDays} days ago';
  if (difference.inDays < 30)
    return '${(difference.inDays / 7).floor()} weeks ago';
  if (difference.inDays < 365)
    return '${(difference.inDays / 30).floor()} months ago';
  return '${(difference.inDays / 365).floor()} years ago';
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isFollowing = false;
  bool _isLoadingFollow = false;

  Map<String, dynamic>? fullUserData;
  List<Map<String, dynamic>> workshops = [];
  List<Map<String, dynamic>> skills = [];
  List<Map<String, dynamic>> reviews = [];
  List<Map<String, dynamic>> badges = [];
  bool _isLoading = true;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkIfFollowing();
    _fetchProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkIfFollowing() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == widget.user['id']) return;

    try {
      final response = await supabase
          .from('follows')
          .select()
          .eq('follower_id', currentUserId)
          .eq('following_id', widget.user['id'])
          .maybeSingle();

      if (mounted) {
        setState(() => isFollowing = response != null);
      }
    } catch (e) {
      print("Error checking follow status: $e");
    }
  }

  Future<void> _fetchProfileData() async {
    final userId = widget.user['id'];
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Full user data
      final userResponse =
          await supabase.from('users').select().eq('id', userId).single();

      // 2. Workshops taught by this user
      final workshopsResponse = await supabase
          .from('workshops')
          .select('id, title, created_at, max_participants')
          .eq('creator_id', userId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> processedWorkshops = [];
      for (var w in workshopsResponse) {
        // Get enrolled count
        final enrollments = await supabase
            .from('workshop_enrollments')
            .select()
            .eq('workshop_id', w['id']);
        final enrolledCount = enrollments.length;

        // Get average rating
        final ratingsResponse = await supabase
            .from('workshop_ratings')
            .select('rating')
            .eq('workshop_id', w['id']);

        final List<num> ratings =
            ratingsResponse.map((r) => r['rating'] as num).toList();
        final avgRating = ratings.isEmpty
            ? null
            : ratings.reduce((a, b) => a + b) / ratings.length;

        processedWorkshops.add({
          'title': w['title'],
          'participants': enrolledCount,
          'max_participants': w['max_participants'],
          'date': w['created_at'],
          'rating': avgRating,
        });
      }

      // 3. Skills + endorsements
      final skillsToTeach =
          List<String>.from(userResponse['skills_to_teach'] ?? []);
      final List<Map<String, dynamic>> processedSkills = [];
      for (var skill in skillsToTeach) {
        final endorsementsResponse = await supabase
            .from('endorsements')
            .select()
            .eq('endorsed_user', userId)
            .eq('skill', skill);

        processedSkills.add({
          'name': skill,
          'level': 'Expert', // Can be enhanced later
          'endorsements': endorsementsResponse.length,
        });
      }

      // 4. Reviews on their workshops
      final allReviews = await supabase.from('workshop_ratings').select('''
            rating, review, created_at,
            user_id,
            users!workshop_ratings_user_id_fkey(name, avatar_url),
            workshop_id,
            workshops!workshop_ratings_workshop_id_fkey(title, creator_id)
          ''').not('review', 'is', null).order('created_at', ascending: false);

      // Filter only reviews for workshops by this creator
      final userReviews = allReviews.where((r) {
        final workshop = r['workshops'] as Map<String, dynamic>?;
        return workshop?['creator_id'] == userId;
      }).toList();

      // 5. Badges
      final badgesResponse = await supabase
          .from('user_badges')
          .select('badge_definitions(name, icon, description, rarity)')
          .eq('user_id', userId)
          .eq('earned', true);

      final List<Map<String, dynamic>> processedBadges =
          badgesResponse.map((row) {
        final def = row['badge_definitions'] as Map<String, dynamic>;
        return {
          'badge_definitions': {
            'name': def['name'] ?? 'Unknown Badge',
            'icon': def['icon'] ?? '🏅',
            'description': def['description'] ?? '',
            'rarity': def['rarity'] ?? 'Common',
          }
        };
      }).toList();

      if (mounted) {
        setState(() {
          fullUserData = userResponse;
          workshops = processedWorkshops;
          skills = processedSkills;
          reviews = userReviews;
          badges = processedBadges; // ← use processedBadges here
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching profile data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load profile data")),
        );
      }
    }
  }

  Future<void> _followUser() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    setState(() => _isLoadingFollow = true);

    try {
      await supabase.from('follows').insert({
        'follower_id': currentUserId,
        'following_id': widget.user['id'],
      });

      setState(() => isFollowing = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Now following ${widget.user['name']}")),
      );
    } catch (e) {
      print("Error following user: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to follow")),
      );
    } finally {
      setState(() => _isLoadingFollow = false);
    }
  }

  Future<void> _unfollowUser() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    setState(() => _isLoadingFollow = true);

    try {
      await supabase
          .from('follows')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('following_id', widget.user['id']);

      setState(() => isFollowing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unfollowed ${widget.user['name']}")),
      );
    } catch (e) {
      print("Error unfollowing user: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to unfollow")),
      );
    } finally {
      setState(() => _isLoadingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show loading until we have full data (prevents fallback to partial widget.user)
    if (_isLoading || fullUserData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Now safe: fullUserData is guaranteed to exist
    final user = fullUserData!;

    // NEW (CORRECT) - Use DB level + match dashboard exactly
    final xp = (user['xp'] as num?)?.toInt() ?? 0;
    final level =
        (user['level'] as num?)?.toInt() ?? 1; // ← Use stored level from DB
    final nextLevelXP = (level + 1) * 500; // ← Exact dashboard formula
    final progress = xp / nextLevelXP; // ← Exact dashboard formula
    final xpToNextLevel = nextLevelXP - xp; // ← Exact dashboard formula

    final endorsementsCount =
        skills.fold<int>(0, (sum, s) => (s['endorsements'] ?? 0) + sum);

    final List<double> validRatings = workshops
        .where((w) => w['rating'] != null)
        .map((w) => w['rating'] as double)
        .toList();

    final double? overallRating = validRatings.isEmpty
        ? null
        : validRatings.reduce((a, b) => a + b) / validRatings.length;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text("Profile"),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                  icon: const Icon(Icons.share_outlined), onPressed: () {}),
              IconButton(
                  icon: const Icon(Icons.flag_outlined), onPressed: () {}),
              const SizedBox(width: 8),
            ],
          ),
        ],
        body: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.8)
                  ],
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white24,
                    backgroundImage:
                        user['avatar_url']?.toString().isNotEmpty == true
                            ? NetworkImage(user['avatar_url'])
                            : null,
                    child: user['avatar_url']?.toString().isNotEmpty != true
                        ? Text(
                            user['name']?.toString().isNotEmpty == true
                                ? user['name'][0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                fontSize: 28, color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user['name'] ?? 'New User',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  Text(
                    user['university'] ?? 'SkillX Community Member',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.yellow, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        overallRating != null
                            ? '${overallRating.toStringAsFixed(1)} rating'
                            : 'No ratings yet',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.people_alt_rounded,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text("$endorsementsCount endorsements",
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Text("Level $level",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: Colors.white24,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 4),
                      Text("$xpToNextLevel XP to next level",
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isFollowing ? Colors.grey[300] : Colors.white,
                            foregroundColor: theme.colorScheme.primary,
                          ),
                          onPressed: _isLoadingFollow
                              ? null
                              : () =>
                                  isFollowing ? _unfollowUser() : _followUser(),
                          child: _isLoadingFollow
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Text(isFollowing ? "Following" : "Follow"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: "About"),
                Tab(text: "Workshops"),
                Tab(text: "Skills"),
                Tab(text: "Reviews"),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAboutTab(user, badges, theme),
                  _buildWorkshopsTab(workshops),
                  _buildSkillsTab(skills),
                  _buildReviewsTab(reviews),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab(Map<String, dynamic> user,
      List<Map<String, dynamic>> badges, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "About ${user['name']}",
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            user['bio'] ??
                "Passionate about sharing knowledge and helping others grow.",
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            "Badges",
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          badges.isEmpty
              ? Text(
                  "No badges earned yet",
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: badges.map((b) {
                    final def = b['badge_definitions'];
                    return Chip(
                      avatar: Text(def['icon'] ?? '🏅',
                          style: const TextStyle(fontSize: 20)),
                      label: Text(def['name']),
                      labelStyle: theme.textTheme.labelLarge
                          ?.copyWith(color: Colors.white),
                      backgroundColor:
                          theme.colorScheme.primary.withOpacity(0.1),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildWorkshopsTab(List<Map<String, dynamic>> workshops) {
    if (workshops.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No workshops taught yet",
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workshops.length,
      itemBuilder: (_, i) {
        final w = workshops[i];
        final dateStr = _formatRelativeDate(w['date']);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(w['title'],
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                    "$dateStr • ${w['participants']}/${w['max_participants']} participants"),
              ],
            ),
            trailing: w['rating'] != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(w['rating'].toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  )
                : const Text("Upcoming",
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.w500)),
          ),
        );
      },
    );
  }

  Widget _buildSkillsTab(List<Map<String, dynamic>> skills) {
    if (skills.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No skills listed yet",
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: skills.length,
      itemBuilder: (_, i) {
        final s = skills[i];
        final endorsements = s['endorsements'] as int;
        final progress =
            (endorsements / 50).clamp(0.0, 1.0); // Full at 50 endorsements

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s['name'],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(s['level'], style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  color: Colors.green,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("$endorsements endorsements",
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey)),
                    Text("${(progress * 100).toInt()}% mastery",
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab(List<Map<String, dynamic>> reviews) {
    if (reviews.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No reviews yet",
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 8),
            Text("Reviews appear after workshops are completed",
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length,
      itemBuilder: (_, i) {
        final r = reviews[i];
        final reviewer = r['users'] as Map<String, dynamic>;
        final workshopTitle = r['workshops']?['title'] ?? 'Workshop';
        final dateStr = _formatRelativeDate(r['created_at']);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              radius: 24,
              backgroundImage: reviewer['avatar_url']?.isNotEmpty == true
                  ? NetworkImage(reviewer['avatar_url'])
                  : null,
              child: reviewer['avatar_url']?.isEmpty != false
                  ? Text((reviewer['name']?[0] ?? 'U').toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold))
                  : null,
            ),
            title: Text(reviewer['name'] ?? 'Anonymous',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: List.generate(
                      5,
                      (index) => Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: index < (r['rating'] ?? 0)
                                ? Colors.amber
                                : Colors.grey[400],
                          )),
                ),
                const SizedBox(height: 8),
                Text('"${r['review'] ?? 'Great workshop!'}"',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 4),
                Text("from \"$workshopTitle\" • $dateStr",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        );
      },
    );
  }
}
