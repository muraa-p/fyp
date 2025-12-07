import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skillx/screens/chat_screen.dart' show ChatScreen;
import 'package:skillx/screens/endorsements_screen.dart';
import 'package:skillx/screens/gamification_screen.dart';
import 'package:skillx/screens/profile_screen.dart'; // Make sure this import is correct
import 'package:skillx/screens/schedule_screen.dart';
import '../main.dart';
import '../components/custom_bottom_nav.dart';
import 'search_screen.dart';
import 'workshop_detail_screen.dart';
import 'package:skillx/screens/cv_builder_screen.dart';
import 'create_workshop_screen.dart';

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
        // Handle the case where the user might not be loaded yet
        if (currentUser == null || currentUser.id.isEmpty) {
          // You might want to show a loading indicator or navigate to login
          page = const Center(child: CircularProgressIndicator());
        } else {
          // ✅ FIX IS HERE: Pass the user's ID, not the whole object
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AppState>().user;

    // Fake XP progress
    int currentXP = 120;
    int nextLevelXP = 300;
    double progress = currentXP / nextLevelXP;

    // Fake schedule
    final upcomingWorkshops = [
      {
        "title": "Python for Data Science",
        "date": "Today, 4:00 PM",
        "instructor": "David Park",
        "status": "Enrolled"
      },
      {
        "title": "Digital Marketing Basics",
        "date": "Wed, 7:00 PM",
        "instructor": "Lisa Zhang",
        "status": "Teaching"
      },
    ];

    // Fake recommended workshops
    final recommended = [
      {
        "title": "React Hooks Deep Dive",
        "instructor": "Sarah Kim",
        "rating": 4.9,
        "participants": "12/15",
        "duration": "2 hours"
      },
      {
        "title": "Public Speaking Confidence",
        "instructor": "Michael Chen",
        "rating": 4.8,
        "participants": "8/10",
        "duration": "1.5 hours"
      },
      {
        "title": "UI/UX Design Principles",
        "instructor": "Emma Rodriguez",
        "rating": 4.9,
        "participants": "15/20",
        "duration": "3 hours"
      },
    ];

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
                    "Welcome back, ${user?.name?.isNotEmpty == true ? user!.name : "Student"}!",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.email ?? "University",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  // Access the HomeScreen state directly via context
                  context.findAncestorStateOfType<_HomeScreenState>()?.onNavigate("profile");
                },
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Text(
                    (context.watch<AppState>().user?.name.isNotEmpty ?? false)
                        ? context.watch<AppState>().user!.name[0]
                        : "U",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )

            ],
          ),

          const SizedBox(height: 20),

          // XP Progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Your Progress",
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 8),
                Text(
                  "${nextLevelXP - currentXP} XP to next level",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onBackground.withOpacity(0.7),
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
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),

          const SizedBox(height: 20),

          // Stats cards
          Row(
            children: const [
              Expanded(
                  child: _StatCard(
                      label: "Workshops Attended",
                      value: "12",
                      icon: Icons.book_outlined,
                      color: Colors.blue)),
              SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      label: "Workshops Taught",
                      value: "5",
                      icon: Icons.group_outlined,
                      color: Colors.green)),
              SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      label: "Badges Earned",
                      value: "3",
                      icon: Icons.emoji_events_outlined,
                      color: Colors.amber)),
            ],
          ),

          const SizedBox(height: 28),

          // Upcoming workshops
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Your Schedule",
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScheduleScreen()),
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
          Column(
            children: upcomingWorkshops.map((ws) => _UpcomingCard(ws)).toList(),
          ),

          const SizedBox(height: 28),

          // Recommended workshops
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Recommended for You",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text("View All",
                  style: TextStyle(color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: recommended.map((ws) => _RecommendedCard(ws)).toList(),
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
                child: _QuickActionCard(
                  icon: Icons.emoji_events,
                  title: "Gamification",
                  subtitle: "View XP & Badges",
                  color: Colors.yellow,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GamificationScreen(
                          onNavigate: (_) {}, // safe dummy
                          initialTab: 2,
                        ),
                      ),
                    );

                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
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
                  },
                ),
              ),
            ],
          ),


          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
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
                            // Return to profile or home
                            if (screen == "profile") Navigator.pop(context);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: _QuickActionCard(
                    icon: Icons.description,
                    title: "CV Builder",
                    subtitle: "Export Skills",
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CVBuilderScreen()),
                      );
                    },
                  ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Achievements
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
            children: const [
              _AchievementCard(name: "First Workshop", icon: "🎯", earned: true),
              _AchievementCard(name: "Quick Learner", icon: "⚡", earned: true),
              _AchievementCard(
                  name: "Community Helper", icon: "🤝", earned: false),
              _AchievementCard(
                  name: "Workshop Master", icon: "🏆", earned: false),
            ],
          ),
        ],
      ),
    );
  }
}

//
// --- SUPPORTING WIDGETS ---
//
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
        required this.value,
        required this.icon,
        required this.color});

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
                color: theme.colorScheme.onBackground.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final Map ws;
  const _UpcomingCard(this.ws);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              ws["title"],
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),

            // Subtitle
            Text(
              "${ws["date"]} • with ${ws["instructor"]}",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 6),

            // Status Chip
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(ws["status"], style: theme.textTheme.bodySmall),
                backgroundColor: ws["status"] == "Teaching"
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : theme.colorScheme.secondary.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  final Map ws;
  const _RecommendedCard(this.ws);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkshopDetailScreen(workshop: {
              "title": ws["title"],
              "instructor": ws["instructor"],
              "rating": ws["rating"],
              "participants": ws["participants"],
              "duration": ws["duration"],
              "category": "General", // fallback if not provided
              "image": ws["image"] ??
                  "https://via.placeholder.com/400x200?text=Workshop",
              "tags": ["SkillX", "Workshop"],
            }),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Chip stacked vertically
              Text(
                ws["title"],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Chip(
                label: Text(
                  ws["duration"],
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),

              // Rating & Participants
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  Text("${ws["rating"]}",
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 12),
                  const Icon(Icons.group, size: 16),
                  Text("${ws["participants"]}",
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),

              // Instructor
              Text(
                "by ${ws["instructor"]}",
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionCard({
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
                  color: theme.colorScheme.onBackground.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _AchievementCard extends StatelessWidget {
  final String name;
  final String icon;
  final bool earned;

  const _AchievementCard({
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
          : theme.colorScheme.surfaceVariant,
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
                  : theme.colorScheme.surfaceVariant,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
