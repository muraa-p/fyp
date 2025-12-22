import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import '../services/workshop_listener_service.dart';
import '../main.dart'; // For AppState
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  // We pass the userId to fetch data, and a flag for the current user.
  final String userId;
  final bool isCurrentUser;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.isCurrentUser = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _supabaseService = SupabaseService();
  final NotificationService _notificationService = NotificationService();


  // State variables to hold data from Supabase
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _gamificationData;
  List<Map<String, dynamic>>? _createdWorkshops;
  List<Map<String, dynamic>>? _enrolledWorkshops;
  List<Map<String, dynamic>>? _skills;
  List<Map<String, dynamic>>? _reviews;

  bool _isLoading = true;

  // --- State variables for the Settings Tab ---
  bool _workshopRemindersEnabled = true;
  bool _isLoggingOut = false;



  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadProfileData();
    _initializeNotifications();

  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();

    if (_workshopRemindersEnabled) {
      // Check if permissions are granted
      final hasPermission = await _notificationService.hasPermission();
      if (!hasPermission) {
        // Show a dialog explaining why permissions are needed
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Notification Permissions'),
            content: const Text(
              'To receive workshop reminders, please enable notifications in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Open app settings
                  _notificationService.openAppSettings();
                },
                child: const Text('Settings'),
              ),
            ],
          ),
        );
      } else {
        await _notificationService.checkAndScheduleReminders();
      }
    }
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _supabaseService.fetchProfile(widget.userId),
        _fetchGamificationData(widget.userId),
        _supabaseService.fetchCreatedWorkshops(widget.userId),
        _supabaseService.fetchEnrolledWorkshops(widget.userId),
        _supabaseService.fetchUserSkills(widget.userId),
        _supabaseService.fetchReviews(widget.userId),
      ]);

      if (!mounted) return;
      setState(() {
        _profileData = results[0] as Map<String, dynamic>?;
        _gamificationData = results[1] as Map<String, dynamic>?;
        _createdWorkshops = results[2] as List<Map<String, dynamic>>?;
        _enrolledWorkshops = results[3] as List<Map<String, dynamic>>?;
        _skills = results[4] as List<Map<String, dynamic>>?;
        _reviews = results[5] as List<Map<String, dynamic>>?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack("Error loading profile: ${e.toString()}");
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper function to show snack bars
  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading || _profileData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Profile")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Extract gamification data or use defaults
    final userXP = _gamificationData?['user_xp'] ?? 0;
    final userLevel = _gamificationData?['user_level'] ?? 1;
    final workshopsAttended = _gamificationData?['workshops_attended'] ?? 0;
    final workshopsTaught = _gamificationData?['workshops_taught'] ?? 0;
    final badgesEarned = _gamificationData?['badges_earned'] ?? 0;
    final endorsements = _gamificationData?['endorsements_count'] ?? 0;

    // Extract user badges
    final userBadges = _gamificationData?['user_badges_data'] as List<dynamic>? ?? [];

    // Extract user achievements
    final userAchievements = _gamificationData?['user_achievements_data'] as List<dynamic>? ?? [];

    final stats = [
      {"label": "Workshops Taught", "value": workshopsTaught, "icon": Icons.book_outlined, "color": theme.colorScheme.primary},
      {"label": "Workshops Attended", "value": workshopsAttended, "icon": Icons.school_outlined, "color": theme.colorScheme.secondary},
      {"label": "Total XP", "value": userXP, "icon": Icons.flash_on, "color": Colors.amber},
      {"label": "Badges Earned", "value": badgesEarned, "icon": Icons.emoji_events_outlined, "color": Colors.purple},
    ];

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(theme, userLevel, userXP),
          _buildStats(theme, stats),
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
            tabs: const [Tab(text: "About"), Tab(text: "Workshops"), Tab(text: "Skills"), Tab(text: "Reviews"), Tab(text: "Settings")],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAboutTab(theme, userBadges, userAchievements),
                _buildWorkshopsTab(theme, _createdWorkshops ?? [], _enrolledWorkshops ?? []),
                _buildSkillsTab(theme, _skills ?? []),
                _buildReviewsTab(theme, _reviews ?? []),
                _buildSettingsTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(ThemeData theme, int userLevel, int userXP) {
    final userName = _profileData?['name'] ?? 'User';
    final userUniversity = _profileData?['university'] ?? 'Member since 2024';
    final userAvatarUrl = _profileData?['avatar_url'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.onPrimary.withOpacity(0.2),
                backgroundImage: userAvatarUrl != null ? NetworkImage(userAvatarUrl) : null,
                child: userAvatarUrl == null
                    ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimary))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(userName, style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onPrimary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "Level $userLevel",
                            style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(userUniversity, style: TextStyle(color: theme.colorScheme.onPrimary.withOpacity(0.7))),
                    const SizedBox(height: 4),
                    Text("$userXP XP", style: TextStyle(color: theme.colorScheme.onPrimary.withOpacity(0.9))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.isCurrentUser)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Create a UserModel from the fetched data to pass to EditProfileScreen
                  final userModel = UserModel.fromJson(_profileData!);

                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        user: userModel,
                        onUpdate: (updatedUser) {
                          // The EditProfileScreen already saves to Supabase.
                          // We just need to refresh our local data.
                          _loadProfileData();
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text("Edit Profile"),
                style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.onPrimary, foregroundColor: theme.colorScheme.primary),
              ),
            )
          else
            Container(), // Placeholder for Follow/Message buttons
        ],
      ),
    );
  }

  Widget _buildStats(ThemeData theme, List<Map<String, dynamic>> stats) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: stats.map((s) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(s["icon"], color: s["color"], size: 28),
                  const SizedBox(height: 8),
                  Text("${s["value"]}", style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(s["label"], textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAboutTab(ThemeData theme, List<dynamic> badges, List<dynamic> achievements) {
    final userBio = _profileData?['bio'] ?? 'No bio available.';
    final userName = _profileData?['name'] ?? 'User';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("About $userName", style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(userBio, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),

        // Badges Section
        Text("Badges", style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (badges.isEmpty)
          const Text("No badges earned yet.")
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: badges.where((b) => b["earned"] == true).map((badge) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(badge["icon"] ?? "🏆", style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(badge["name"] ?? "Badge", style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
                      Text(badge["description"] ?? "No description", style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(badge["rarity"] ?? "Common"),
                        backgroundColor: _getRarityColor(badge["rarity"] ?? "Common"),
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 20),

        // Achievements Section
        Text("Achievements", style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (achievements.isEmpty)
          const Text("No achievements in progress.")
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: achievements.map((achievement) {
              final progress = (achievement["progress"] as int? ?? 0) / (achievement["max"] as int? ?? 1);
              final isCompleted = progress >= 1.0;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(achievement["icon"] ?? "🎯", style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(achievement["title"] ?? "Achievement", style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
                      Text(achievement["description"] ?? "No description", style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Text("${achievement["progress"]}/${achievement["max"]}", style: theme.textTheme.bodySmall),
                      if (isCompleted)
                        const Chip(
                          label: Text("Completed"),
                          backgroundColor: Colors.green,
                          labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case "common":
        return Colors.grey;
      case "uncommon":
        return Colors.green;
      case "rare":
        return Colors.blue;
      case "epic":
        return Colors.purple;
      case "legendary":
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Widget _buildWorkshopsTab(ThemeData theme, List created, List enrolled) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Workshops Conducted", style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (created.isEmpty)
          const Text("No workshops created yet.", style: TextStyle(color: Colors.grey))
        else
          ...created.map((ws) => Card(child: ListTile(title: Text(ws["title"]), subtitle: Text("${ws["participants"]} participants")))),
        const SizedBox(height: 20),
        Text("Workshops Enrolled In", style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (enrolled.isEmpty)
          const Text("No enrolled workshops.", style: TextStyle(color: Colors.grey))
        else
          ...enrolled.map((ws) => Card(
            child: ListTile(
              title: Text(ws['title'] ?? "Untitled Workshop"),
              subtitle: Text("by ${ws['users']['name'] ?? 'Unknown Creator'}"),
            ),
          )),
      ],
    );
  }

  Widget _buildSkillsTab(ThemeData theme, List skills) {
    // Create a map to store workshop counts for each skill
    Map<String, int> skillWorkshopCounts = {};

    // Initialize all skills with 0 workshops
    for (var skill in skills) {
      skillWorkshopCounts[skill["name"]] = 0;
    }

    // Count workshops for each skill
    if (_createdWorkshops != null) {
      for (var workshop in _createdWorkshops!) {
        // Check if workshop title contains any skill name
        for (var skill in skills) {
          String skillName = skill["name"].toLowerCase();

          // Check in title
          if (workshop["title"] != null &&
              workshop["title"].toString().toLowerCase().contains(skillName)) {
            skillWorkshopCounts[skill["name"]] = (skillWorkshopCounts[skill["name"]] ?? 0) + 1;
            continue;
          }

          // Check in tags
          if (workshop["tags"] != null && workshop["tags"] is List) {
            for (var tag in workshop["tags"]) {
              if (tag.toString().toLowerCase() == skillName) {
                skillWorkshopCounts[skill["name"]] = (skillWorkshopCounts[skill["name"]] ?? 0) + 1;
                continue;
              }
            }
          }

          // Check in skills field
          if (workshop["skills"] != null && workshop["skills"] is List) {
            for (var skillField in workshop["skills"]) {
              if (skillField.toString().toLowerCase() == skillName) {
                skillWorkshopCounts[skill["name"]] = (skillWorkshopCounts[skill["name"]] ?? 0) + 1;
                continue;
              }
            }
          }

          // Check in description
          if (workshop["description"] != null &&
              workshop["description"].toString().toLowerCase().contains(skillName)) {
            skillWorkshopCounts[skill["name"]] = (skillWorkshopCounts[skill["name"]] ?? 0) + 1;
          }
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: skills.isEmpty
          ? [const Text("No skills to display.")]
          : skills.map((s) {
        double progress = 0.25;
        if (s["level"] == "Expert") progress = 0.95;
        if (s["level"] == "Advanced") progress = 0.75;
        if (s["level"] == "Intermediate") progress = 0.5;

        // Use the calculated workshop count instead of the one from the database
        int workshopCount = skillWorkshopCounts[s["name"]] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s["name"], style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: progress, minHeight: 6),
                const SizedBox(height: 6),
                Text("${s["endorsements"]} endorsements • $workshopCount workshops"),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReviewsTab(ThemeData theme, List reviews) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: reviews.isEmpty
          ? [const Text("No reviews yet.")]
          : reviews.map((r) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(r['users']['name'] ?? "Anonymous"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${r['workshops']['title']} • ${_formatDate(r['created_at'])}", style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(r['review'] ?? "No comment."),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) => Icon(Icons.star, size: 16, color: i < r["rating"] ? Colors.amber : theme.disabledColor)),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return "Unknown date";
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      if (difference.inDays > 0) return "${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago";
      if (difference.inHours > 0) return "${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago";
      if (difference.inMinutes > 0) return "${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago";
      return "Just now";
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildSettingsTab(ThemeData theme) {
    final appState = context.watch<AppState>();
    bool isDarkMode = appState.isDarkMode;
    return StatefulBuilder(
      builder: (context, setState) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text("Dark Mode"),
            subtitle: const Text("Switch between light and dark themes"),
            value: isDarkMode,
            onChanged: (_) => appState.toggleDarkMode(),
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
          const Divider(height: 32),

          // 🌍 Language
          Text("Language",
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.language_outlined),
                      const SizedBox(width: 12),
                      const Text("English", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Currently only English is supported. More languages coming soon!",
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 32),

          // 🔔 Notifications
          Text("Notifications",
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text("Workshop Reminders"),
            subtitle: const Text("Get notified 15 minutes before workshops start"),
            value: _workshopRemindersEnabled,
            onChanged: (value) {
              setState(() {
                _workshopRemindersEnabled = value;
                _notificationService.setWorkshopReminders(value);

                if (value) {
                  _notificationService.checkAndScheduleReminders();
                  _showSnack("Workshop reminders enabled");
                } else {
                  _notificationService.cancelAllWorkshopReminders();
                  _showSnack("Workshop reminders disabled");
                }
              });
            },
            secondary: const Icon(Icons.notifications_outlined),
          ),
          SwitchListTile(
            title: const Text("New Workshop Alerts"),
            subtitle: const Text("Get notified when new workshops are added"),
            value: context.watch<AppState>().newWorkshopAlertsEnabled,
            onChanged: (value) {
              final appState = context.read<AppState>();
              appState.setNewWorkshopAlerts(value);

              if (value) {
                WorkshopListenerService().startListening();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("New workshop alerts enabled")),
                );
              } else {
                WorkshopListenerService().stopListening();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("New workshop alerts disabled")),
                );
              }
            },
            secondary: const Icon(Icons.notifications_active_outlined),
          ),

          // 🧾 Account Management
          Text("Account Management",
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary)),
          const SizedBox(height: 8),

          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text("Update Password"),
            subtitle: const Text("Change your account password"),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Update Password"),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        obscureText: true,
                        decoration: InputDecoration(labelText: "Current Password"),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        obscureText: true,
                        decoration: InputDecoration(labelText: "New Password"),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel")),
                    TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showSnack("Password updated (demo)");
                        },
                        child: const Text("Update")),
                  ],
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text("Delete Account"),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Confirm Deletion"),
                  content: const Text(
                      "Are you sure you want to delete your account? This cannot be undone."),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel")),
                    TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showSnack("Account deletion initiated");
                        },
                        child: const Text("Delete",
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
            },
          ),

          ListTile(
            leading: _isLoggingOut
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.red,
                strokeWidth: 2.0,
              ),
            )
                : const Icon(Icons.logout, color: Colors.red),
            title: Text(_isLoggingOut ? "Logging Out..." : "Log Out"),
            onTap: _isLoggingOut
                ? null
                : () async {
              setState(() {
                _isLoggingOut = true;
              });

              try {
                await Supabase.instance.client.auth.signOut();

                if (mounted) {
                  context.read<AppState>().setUser(null);
                }

                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                        (Route<dynamic> route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  _showSnack("Error logging out: ${e.toString()}");
                  setState(() {
                    _isLoggingOut = false;
                  });
                }
              }
            },
          ),

          const Divider(height: 32),

          // ℹ️ App Info
          Center(
            child: Column(
              children: [
                Text("SkillX",
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Text("Version 1.0.0",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                const Text("Supporting SDG 4: Quality Education",
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String title, bool value, String subtitle, ThemeData theme, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}