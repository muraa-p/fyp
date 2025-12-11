//
// --- DASHBOARD PAGE ---
//
import 'package:flutter/material.dart';
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

    return Scaffold(
      body: page,
      bottomNavigationBar: CustomBottomNav(
        currentScreen: _currentScreen,
        onNavigate: onNavigate,
      ),
    );
  }
}

//
// --- DASHBOARD PAGE ---
//
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  // Function to fetch user workshops from database - moved outside build method
  Future<List<Map<String, dynamic>>> _fetchUserWorkshops(String? userId) async {
    if (userId == null || userId.isEmpty) return [];

    try {
      print('Fetching workshops for user: $userId');

      // First, fetch workshops where the user is the creator
      final createdWorkshopsResponse = await Supabase.instance.client
          .from('workshops')
          .select('''
          id, title, creator_id, date, time, status, 
          max_participants, rating, duration, image_url, tags
        ''')
          .eq('creator_id', userId)
          .order('date', ascending: true);

      // Second, fetch workshop IDs where the user is enrolled
      final enrollmentsResponse = await Supabase.instance.client
          .from('workshop_enrollments')
          .select('workshop_id')
          .eq('user_id', userId);

      // Extract workshop IDs from enrollments
      final enrolledWorkshopIds = enrollmentsResponse
          .map((e) => e['workshop_id'] as String)
          .toList();

      // Fetch the actual workshops for those IDs
      List<Map<String, dynamic>> enrolledWorkshops = [];
      if (enrolledWorkshopIds.isNotEmpty) {
        // Build the filter manually
        var query = Supabase.instance.client.from('workshops').select('''
            id, title, creator_id, date, time, status, 
            max_participants, rating, duration, image_url, tags
          ''');

        for (int i = 0; i < enrolledWorkshopIds.length; i++) {
          if (i == 0) {
            query = query.eq('id', enrolledWorkshopIds[i]);
          } else {
            query = query.or('id.eq.${enrolledWorkshopIds[i]}');
          }
        }

        final enrolledWorkshopsResponse = await query.order('date', ascending: true);
        enrolledWorkshops = List<Map<String, dynamic>>.from(enrolledWorkshopsResponse);
      }

      // Combine both lists
      List<Map<String, dynamic>> allWorkshops = [
        ...List<Map<String, dynamic>>.from(createdWorkshopsResponse),
        ...enrolledWorkshops
      ];

      // Remove duplicates (in case a user is both creator and enrolled)
      final uniqueWorkshopIds = <String>{};
      final uniqueWorkshops = allWorkshops.where((workshop) {
        final id = workshop['id'] as String;
        if (uniqueWorkshopIds.contains(id)) {
          return false;
        } else {
          uniqueWorkshopIds.add(id);
          return true;
        }
      }).toList();

      // Sort by date
      uniqueWorkshops.sort((a, b) {
        final aDate = a['date'] as String?;
        final bDate = b['date'] as String?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });

      // Debug: Print the workshops to see what we're getting
      print('Fetched ${uniqueWorkshops.length} workshops');
      for (var workshop in uniqueWorkshops) {
        print('Workshop: ${workshop['title']}, Date: ${workshop['date']}, Status: ${workshop['status']}');
      }

      return uniqueWorkshops;
    } catch (e) {
      print('Error fetching workshops: $e');
      return [];
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

    // Fetch workshops and gamification data from database
    return FutureBuilder(
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

          final workshops = snapshot.data?[0] as List<Map<String, dynamic>>? ?? [];
          final gamificationData = snapshot.data?[1] as Map<String, dynamic>?;

          // Debug: Print the number of workshops
          print('Total workshops: ${workshops.length}');

          // Separate workshops into upcoming and teaching
          final upcomingWorkshops = workshops.where((w) {
            try {
              // Check status first
              if (w['status'] == 'upcoming') return true;

              // Then check date if status is not upcoming
              if (w['date'] != null && w['date'].toString().isNotEmpty) {
                final workshopDate = DateTime.parse(w['date'].toString());
                return workshopDate.isAfter(DateTime.now());
              }
              return false;
            } catch (e) {
              print('Error parsing date for workshop ${w['id']}: $e');
              return false;
            }
          }).toList();

          final teachingWorkshops = workshops.where((w) {
            try {
              // Check status first
              if (w['status'] == 'teaching') return true;

              // Then check date if status is not teaching
              if (w['date'] != null && w['date'].toString().isNotEmpty) {
                final workshopDate = DateTime.parse(w['date'].toString());
                return workshopDate.isBefore(DateTime.now());
              }
              return false;
            } catch (e) {
              print('Error parsing date for workshop ${w['id']}: $e');
              return false;
            }
          }).toList();

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

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome back, ${user?.name.isNotEmpty == true ? user!.name : "Student"}!",
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user?.email ?? "University",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        // Access HomeScreen state directly via context
                        context.findAncestorStateOfType<_HomeScreenState>()?.onNavigate("profile");
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                        child: Text(
                          (context.watch<AppState>().user?.name.isNotEmpty ?? false)
                              ? context.watch<AppState>().user!.name[0]
                              : "U",
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // XP Progress - Now using real data
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Your Progress",
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text("Level $userLevel",
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0), // Ensure value is between 0 and 1
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "$userXP XP • ${nextLevelXP - userXP} XP to next level",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Search bar
                TextField(
                  decoration: InputDecoration(
                    hintText: "Search workshops, skills, or instructors...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Stats cards - Now using real data
                Row(
                  children: [
                    Expanded(
                        child: StatCard(
                            label: "Workshops Attended",
                            value: workshopsAttended.toString(),
                            icon: Icons.book_outlined,
                            color: Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: StatCard(
                            label: "Workshops Taught",
                            value: workshopsTaught.toString(),
                            icon: Icons.group_outlined,
                            color: Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: StatCard(
                            label: "Badges Earned",
                            value: badgesEarned.toString(),
                            icon: Icons.emoji_events_outlined,
                            color: Colors.amber)),
                  ],
                ),
                const SizedBox(height: 28),

                // Unified Schedule section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        "Your Schedule",
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ScheduleScreen(
                            upcomingWorkshops: upcomingWorkshops,
                            teachingWorkshops: teachingWorkshops,
                          )),
                        );
                      },
                      child: Text(
                        "View All",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Combined horizontal scrollable list with auto-sizing
                SizedBox(
                  height: 185, // Further reduced height
                  child: allScheduledWorkshops.isEmpty
                      ? const Center(child: Text("No workshops scheduled",
                      style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: allScheduledWorkshops.length,
                    itemBuilder: (context, index) {
                      final workshop = allScheduledWorkshops[index];
                      final isTeaching = teachingWorkshops.contains(workshop);

                      return Container(
                        width: 280, // Fixed width for each card
                        margin: const EdgeInsets.only(right: 12),
                        child: WorkshopCard(
                          workshop: workshop,
                          isTeaching: isTeaching,
                          fetchCreatorName: _fetchCreatorName,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),

                // Quick Actions
                Text("Quick Actions",
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: QuickActionCard(
                            icon: Icons.emoji_events,
                            title: "Gamification",
                            subtitle: "View XP & Badges",
                            color: Colors.yellow,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GamificationScreen(
                                    onNavigate: (screen) {
                                      Navigator.pop(context);
                                    },
                                    initialTab: 0, // 0 = Overview tab
                                  ),
                                ),
                              );
                            })),
                    const SizedBox(width: 12),
                    Expanded(
                        child: QuickActionCard(
                            icon: Icons.leaderboard,
                            title: "Leaderboard",
                            subtitle: "Global Rankings",
                            color: Colors.blue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GamificationScreen(
                                    onNavigate: (screen) {
                                      Navigator.pop(context);
                                    },
                                    initialTab: 2, // 2 = Leaderboard tab
                                  ),
                                ),
                              );
                            })),
                    const SizedBox(width: 12),
                    Expanded(
                        child: QuickActionCard(
                            icon: Icons.star,
                            title: "Endorsements",
                            subtitle: "Skill Recognition",
                            color: Colors.purple,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EndorsementsScreen(
                                    onNavigate: (screen) {
                                      Navigator.pop(context);
                                    },
                                  ),
                                ),
                              );
                            })),
                    const SizedBox(width: 12),
                    Expanded(
                        child: QuickActionCard(
                            icon: Icons.description,
                            title: "CV Builder",
                            subtitle: "Export Skills",
                            color: Colors.green,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CVBuilderScreen()),
                              );
                            })),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: QuickActionCard(
                            icon: Icons.emoji_events,
                            title: "Achievements",
                            subtitle: "View All",
                            color: Colors.amber,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GamificationScreen(
                                    onNavigate: (screen) {
                                      Navigator.pop(context);
                                    },
                                    initialTab: 3, // 3 = Achievements tab
                                  ),
                                ),
                              );
                            })),
                    const SizedBox(width: 12),
                    Expanded(
                        child: QuickActionCard(
                            icon: Icons.chat,
                            title: "Messages",
                            subtitle: "View All",
                            color: Colors.blue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ChatScreen()),
                              );
                            })),
                  ],
                ),
                const SizedBox(height: 28),

                // Recent Achievements - Now using real data
                Text("Recent Achievements",
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: recentBadges.isEmpty
                      ? [
                    const AchievementCard(name: "No badges earned yet", icon: "🔒", earned: false),
                    const AchievementCard(name: "Keep learning!", icon: "📚", earned: false),
                  ]
                      : recentBadges.map((badge) {
                    return AchievementCard(
                      name: badge["name"] as String,
                      icon: badge["icon"] as String,
                      earned: badge["earned"] as bool,
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }
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
  final String title, subtitle;
  final Color color;
  final VoidCallback? onTap;

  const QuickActionCard({super.key, 
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
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