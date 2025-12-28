//
// --- DASHBOARD PAGE ---
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:skillx/screens/chat_screen.dart' show ChatScreen;
import 'package:skillx/screens/endorsements_screen.dart' show EndorsementsScreen;
import 'package:skillx/screens/gamification_screen.dart' show GamificationScreen;
import 'package:skillx/screens/profile_screen.dart' show ProfileScreen;
import 'package:skillx/screens/schedule_screen.dart' show ScheduleScreen;
import 'package:skillx/screens/cv_builder_screen.dart' show CVBuilderScreen;
import 'package:skillx/screens/create_workshop_screen.dart' show CreateWorkshopScreen;
import 'package:skillx/screens/search_screen.dart' show SearchScreen;
import 'package:skillx/screens/workshop_detail_screen.dart' show WorkshopDetailScreen;
import '../main.dart';
import '../components/custom_bottom_nav.dart';
// Add this import for Supabase
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentScreen = "home";
  DateTime? _lastBackPressTime;


  void onNavigate(String screen) {
    setState(() {
      _currentScreen = screen;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (_currentScreen) {
      case "home":
        page = const DashboardPage();
        break;
      case "search":
        page = const SearchScreen();
        break;
      case "create":
        page = CreateWorkshopScreen(onNavigate: onNavigate);
        break;
      case "chat":
        page = const ChatScreen();
        break;
      case "profile":
        final currentUser = context.read<AppState>().user;
        // Handle case where user might not be loaded yet
        if (currentUser == null || currentUser.id.isEmpty) {
          // You might want to show a loading indicator or navigate to login
          page = const Center(child: CircularProgressIndicator());
        } else {
          // ✅ FIX IS HERE: Pass user's ID, not whole object
          page = ProfileScreen(
            userId: currentUser.id, // Corrected line
            isCurrentUser: true,
          );
        }
        break;
      default:
        page = const DashboardPage();
    }



    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;

        final now = DateTime.now();
        const backPressInterval = Duration(seconds: 2);

        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > backPressInterval) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Press back again to exit"),
              duration: Duration(seconds: 2),
            ),
          );
          _lastBackPressTime = now;
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: page,
        bottomNavigationBar: CustomBottomNav(
          currentScreen: _currentScreen,
          onNavigate: onNavigate,
        ),
      ),
    );
  }
}

//
// --- DASHBOARD PAGE ---
//
class DashboardPage extends StatefulWidget {  // ← Changed to StatefulWidget
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime? _lastBackPressTime;

  // Function to fetch user workshops from database - moved outside build method
  Future<Map<String, List<Map<String, dynamic>>>> _fetchUserWorkshops(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return {'teaching': [], 'attending': []};
    }

    try {
      // 1. Fetch workshops created by the user (Teaching)
      final teachingResponse = await Supabase.instance.client
          .from('workshops')
          .select('''
          id, title, creator_id, date, time, status, 
          max_participants, rating, duration, image_url, tags,
          users!creator_id(name, avatar_url)
        ''')
          .eq('creator_id', userId)
          .order('date', ascending: true);

      final List<Map<String, dynamic>> teachingWorkshops =
      List<Map<String, dynamic>>.from(teachingResponse);

      // 2. Fetch workshops the user is enrolled in (Attending)
      final enrollmentsResponse = await Supabase.instance.client
          .from('workshop_enrollments')
          .select('workshop_id')
          .eq('user_id', userId);

      final List<String> enrolledWorkshopIds = enrollmentsResponse
          .map((e) => e['workshop_id'] as String)
          .toList();

      List<Map<String, dynamic>> attendingWorkshops = [];
      if (enrolledWorkshopIds.isNotEmpty) {
        var query = Supabase.instance.client
            .from('workshops')
            .select('''
            id, title, creator_id, date, time, status, 
            max_participants, rating, duration, image_url, tags,
            users!creator_id(name, avatar_url)
          ''');

        // Build OR filter for multiple IDs
        String orFilter = enrolledWorkshopIds
            .map((id) => 'id.eq.$id')
            .join(',');

        final attendingResponse = await query
            .or(orFilter)
            .order('date', ascending: true);

        attendingWorkshops = List<Map<String, dynamic>>.from(attendingResponse);

        // Remove any workshop where creator is the current user (avoid duplicates)
        attendingWorkshops.removeWhere((w) => w['creator_id'] == userId);
      }

      return {
        'teaching': teachingWorkshops,
        'attending': attendingWorkshops,
      };
    } catch (e) {
      print('Error fetching workshops: $e');
      return {'teaching': [], 'attending': []};
    }
  }

  // Function to fetch creator name for a workshop
  Future<String> _fetchCreatorName(String creatorId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('id', creatorId)
          .single();

      return response['name'] as String? ?? "Unknown creator";
    } catch (e) {
      print('Error fetching creator name: $e');
      return "Unknown creator";
    }
  }

  // Function to fetch gamification data
  Future<Map<String, dynamic>?> _fetchGamificationData(String? userId) async {
    if (userId == null || userId.isEmpty) return null;

    try {
      final response = await Supabase.instance.client.rpc('get_user_gamification_data',
          params: {'current_user_id': userId});

      // The response from an RPC that returns a table is a list.
      // We need to get the first element, which contains our data.
      final data = response is List ? response.first : response;

      return data;
    } catch (e) {
      print('Error fetching gamification data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AppState>().user;

    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;

          final now = DateTime.now();
          const backPressInterval = Duration(seconds: 2);

          if (_lastBackPressTime == null ||
              now.difference(_lastBackPressTime!) > backPressInterval) {
            // First press
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Press back again to exit"),
                duration: Duration(seconds: 2),
              ),
            );
            _lastBackPressTime = now;
          } else {
            // Second press → exit app
            SystemNavigator.pop();
          }
        },
        child: FutureBuilder(
            future: Future.wait([
              _fetchUserWorkshops(user?.id),
              _fetchGamificationData(user?.id)
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final workshopData = snapshot.data?[0] as Map<String, List<Map<String, dynamic>>>? ??
                  {'teaching': [], 'attending': []};
              final gamificationData = snapshot.data?[1] as Map<String, dynamic>?;


          // Debug: Print the number of workshops
          print('Total workshops: ${workshopData.length}');

          // Separate workshops into upcoming and teaching
          final List<Map<String, dynamic>> teachingWorkshops = workshopData['teaching'] ?? [];
          final List<Map<String, dynamic>> upcomingWorkshops = workshopData['attending'] ?? [];

          // Combine both lists for the unified schedule
          final allScheduledWorkshops = [...upcomingWorkshops, ...teachingWorkshops];

          // Debug: Print the number of workshops in each category
          print('Upcoming workshops: ${upcomingWorkshops.length}');
          print('Teaching workshops: ${teachingWorkshops.length}');

          // Extract gamification data or use defaults
          final userXP = gamificationData?['user_xp'] ?? 0;
          final userLevel = gamificationData?['user_level'] ?? 1;
          final workshopsAttended = gamificationData?['workshops_attended'] ?? 0;
          final workshopsTaught = gamificationData?['workshops_taught'] ?? 0;
          final badgesEarned = gamificationData?['badges_earned'] ?? 0;
          final endorsements = gamificationData?['endorsements_count'] ?? 0;

          // Calculate progress for next level
          final nextLevelXP = (userLevel + 1) * 500; // Based on your gamification system
          final progress = userXP / nextLevelXP;

          // Extract user badges
          final userBadges = gamificationData?['user_badges_data'] as List<dynamic>? ?? [];

          // Get recent earned badges (up to 4)
          final recentBadges = userBadges
              .where((b) => b["earned"] == true)
              .take(4)
              .toList();

// Replace the entire DashboardPage build method content with this:

              return RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    _fetchUserWorkshops(user?.id),
                    _fetchGamificationData(user?.id),
                  ]);
                },
                color: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SafeArea(
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            // Header
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Welcome back,",
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      Text(
                                        user?.name.isNotEmpty == true ? user!.name : "Student",
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user?.university ?? "SkillX Community",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                GestureDetector(
                                  onTap: () => context.findAncestorStateOfType<_HomeScreenState>()?.onNavigate("profile"),
                                  child: CircleAvatar(
                                    radius: 28,
                                    backgroundColor: const Color(0xFF60A5FA).withOpacity(0.2),
                                    child: Text(
                                      user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : "U",
                                      style: const TextStyle(
                                        color: Color(0xFF60A5FA),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Your Progress Card
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.2),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Your Progress",
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      Text(
                                        "Level $userLevel",
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  LinearProgressIndicator(
                                    value: progress.clamp(0.0, 1.0),
                                    minHeight: 12,
                                    borderRadius: BorderRadius.circular(8),
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "$userXP / $nextLevelXP XP • ${nextLevelXP - userXP} to next level",
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Search bar
                            TextField(
                              readOnly: true,
                              onTap: () => context.findAncestorStateOfType<_HomeScreenState>()?.onNavigate("search"),
                              decoration: InputDecoration(
                                hintText: "Search workshops, skills, or people...",
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 32),

                            // Stat Cards
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 3,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 1.3,
                              children: [
                                _GlassStatCard("Workshops Attended", workshopsAttended.toString(), Icons.school_rounded, Colors.blue),
                                _GlassStatCard("Workshops Taught", workshopsTaught.toString(), Icons.record_voice_over, Colors.green),
                                _GlassStatCard("Badges Earned", badgesEarned.toString(), Icons.emoji_events_rounded, Colors.amber),
                              ],
                            ),
                            const SizedBox(height: 40),

                            // Your Schedule
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Your Schedule", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ScheduleScreen(
                                        upcomingWorkshops: upcomingWorkshops,
                                        teachingWorkshops: teachingWorkshops,
                                      ),
                                    ),
                                  ),
                                  child: Text("View All", style: TextStyle(color: const Color(0xFF60A5FA), fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: allScheduledWorkshops.isEmpty
                                  ? Center(child: Text("No workshops scheduled yet", style: TextStyle(color: Colors.white.withOpacity(0.6))))
                                  : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: allScheduledWorkshops.length,
                                itemBuilder: (context, index) {
                                  final workshop = allScheduledWorkshops[index];
                                  final isTeaching = teachingWorkshops.contains(workshop);
                                  return Container(
                                    width: 300,
                                    margin: const EdgeInsets.only(right: 16),
                                    child: WorkshopCard(
                                      workshop: workshop,
                                      isTeaching: isTeaching,
                                      fetchCreatorName: _fetchCreatorName,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Quick Actions
                            const Text("Quick Actions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 16),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 1.4,
                              children: [
                                QuickActionCard(
                                  icon: Icons.emoji_events_rounded,
                                  title: "Gamification",
                                  color: Colors.amber,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GamificationScreen(onNavigate: (_) {}, initialTab: 0),
                                    ),
                                  ),
                                ),
                                QuickActionCard(
                                  icon: Icons.leaderboard_rounded,
                                  title: "Leaderboard",
                                  color: Colors.blue,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GamificationScreen(onNavigate: (_) {}, initialTab: 2),
                                    ),
                                  ),
                                ),
                                QuickActionCard(
                                  icon: Icons.star_rounded,
                                  title: "Endorsements",
                                  color: Colors.purple,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EndorsementsScreen()),
                                  ),
                                ),
                                QuickActionCard(
                                  icon: Icons.description_rounded,
                                  title: "CV Builder",
                                  color: Colors.green,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CVBuilderScreen()),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),

                            // Recent Achievements
                            const Text("Recent Achievements", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 16),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 1.4,
                              children: recentBadges.isEmpty
                                  ? [
                                _GlassAchievementCard("Keep learning!", "📚", false),
                                _GlassAchievementCard("Your first badge awaits", "✨", false),
                              ]
                                  : recentBadges.map((b) => _GlassAchievementCard(b["name"], b["icon"], true)).toList(),
                            ),
                            const SizedBox(height: 80), // Extra space at bottom for comfortable scrolling
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
        }
    )
    );
  }
}

class StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const StatCard({super.key, required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Unified workshop card that can handle both upcoming and teaching workshops
class WorkshopCard extends StatefulWidget {
  final Map<String, dynamic> workshop;
  final bool isTeaching;
  final Future<String> Function(String) fetchCreatorName;

  const WorkshopCard({
    super.key,
    required this.workshop,
    required this.isTeaching,
    required this.fetchCreatorName,
  });

  @override
  State<WorkshopCard> createState() => _WorkshopCardState();
}

class _WorkshopCardState extends State<WorkshopCard> {
  late Future<String> creatorNameFuture;

  @override
  void initState() {
    super.initState();
    creatorNameFuture = widget.fetchCreatorName(widget.workshop['creator_id']);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Safely parse the date
    DateTime? date;
    try {
      if (widget.workshop['date'] != null && widget.workshop['date'].toString().isNotEmpty) {
        date = DateTime.parse(widget.workshop['date'].toString());
      }
    } catch (e) {
      print('Error parsing date for workshop ${widget.workshop['id']}: $e');
    }

    final time = widget.workshop['time']?.toString();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkshopDetailScreen(workshop: widget.workshop),
          ),
        );
      },
      child: Card(
        margin: EdgeInsets.zero, // Remove margin since we're handling it in the parent
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(8), // Reduced padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title & Chip stacked vertically
              Text(
                widget.workshop["title"]?.toString() ?? "Untitled Workshop",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), // Slightly smaller font
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4), // Reduced spacing
              Chip(
                label: Text(
                  widget.workshop["duration"]?.toString() ?? "Unknown duration",
                  style: const TextStyle(fontSize: 11), // Smaller font
                ),
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Smaller padding
              ),
              const SizedBox(height: 4), // Reduced spacing

              // Date & Time - Side by side
              if (date != null || time != null)
                Row(
                  children: [
                    if (date != null)
                      Text(
                        "${date.day}/${date.month}/${date.year}",
                        style: const TextStyle(fontSize: 11, color: Colors.grey), // Smaller font
                      ),
                    if (date != null && time != null)
                      const Text(
                        " • ",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    if (time != null)
                      Text(
                        time,
                        style: const TextStyle(fontSize: 11, color: Colors.grey), // Smaller font
                      ),
                  ],
                ),
              if (date != null || time != null)
                const SizedBox(height: 6), // Reduced spacing

              // Different content based on workshop type
              if (widget.isTeaching)
                Text(
                  "${widget.workshop["workshop_enrollments"]?.length ?? 0}/${widget.workshop["max_participants"] ?? 0} participants",
                  style: const TextStyle(fontSize: 11, color: Colors.grey), // Smaller font
                )
              else
                FutureBuilder<String>(
                  future: creatorNameFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text(
                        "Loading...",
                        style: TextStyle(fontSize: 11, color: Colors.grey), // Smaller font
                      );
                    } else if (snapshot.hasError) {
                      return const Text(
                        "Unknown creator",
                        style: TextStyle(fontSize: 11, color: Colors.grey), // Smaller font
                      );
                    } else {
                      return Text(
                        "by ${snapshot.data ?? "Unknown creator"}",
                        style: const TextStyle(fontSize: 11, color: Colors.grey), // Smaller font
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }
                  },
                ),
              const SizedBox(height: 6), // Reduced spacing

              // Status Chip
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(
                    widget.isTeaching ? "Teaching" : (widget.workshop["status"]?.toString() ?? "Unknown"),
                    style: const TextStyle(fontSize: 11), // Smaller font
                  ),
                  backgroundColor: widget.isTeaching
                      ? theme.colorScheme.primary.withOpacity(0.2)
                      : theme.colorScheme.secondary.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Smaller padding
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback? onTap;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AchievementCard extends StatelessWidget {
  final String name;
  final String icon;
  final bool earned;

  const AchievementCard({super.key, 
    required this.name,
    required this.icon,
    required this.earned,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: earned
          ? theme.colorScheme.secondary.withOpacity(0.15)
          : theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Chip(
              label: Text(
                earned ? "Earned" : "Locked",
                style: TextStyle(
                  fontSize: 11,
                  color: earned
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              backgroundColor: earned
                  ? theme.colorScheme.secondary.withOpacity(0.2)
                  : theme.colorScheme.surfaceContainerHighest,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassStatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color accentColor;

  const _GlassStatCard(this.title, this.value, this.icon, this.accentColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: constraints.maxHeight * 0.25, color: accentColor), // Responsive icon
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: constraints.maxHeight * 0.22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 6),
              Expanded( // ← Takes remaining space safely
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: constraints.maxHeight * 0.12,
                    color: Colors.white.withOpacity(0.85),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlassAchievementCard extends StatelessWidget {
  final String name, icon;
  final bool earned;

  const _GlassAchievementCard(this.name, this.icon, this.earned);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: earned ? const Color(0xFF34D399).withOpacity(0.15) : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: earned ? const Color(0xFF34D399).withOpacity(0.3) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: TextStyle(fontSize: constraints.maxHeight * 0.28)),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: constraints.maxHeight * 0.14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                earned ? "Earned ✓" : "Locked",
                style: TextStyle(
                  fontSize: constraints.maxHeight * 0.11,
                  color: earned ? const Color(0xFF34D399) : Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}