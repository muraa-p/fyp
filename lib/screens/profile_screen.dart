import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart'; // For AppState
import '../models/user_model.dart';
import '../services/supabase_service.dart'; // Import the new service
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

  // State variables to hold data from Supabase
  Map<String, dynamic>? _profileData;
  Map<String, int>? _userStats;
  List<Map<String, dynamic>>? _achievements;
  List<Map<String, dynamic>>? _createdWorkshops;
  List<Map<String, dynamic>>? _enrolledWorkshops;
  List<Map<String, dynamic>>? _skills;
  List<Map<String, dynamic>>? _reviews;

  bool _isLoading = true;

  // --- State variables for the Settings Tab ---
  bool _lowBandwidth = false;
  String _language = "en";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _supabaseService.fetchProfile(widget.userId),
        _supabaseService.fetchUserStats(widget.userId),
        _supabaseService.fetchAchievements(widget.userId),
        _supabaseService.fetchCreatedWorkshops(widget.userId),
        _supabaseService.fetchEnrolledWorkshops(widget.userId),
        _supabaseService.fetchUserSkills(widget.userId),
        _supabaseService.fetchReviews(widget.userId),
      ]);

      if (!mounted) return;
      setState(() {
        _profileData = results[0] as Map<String, dynamic>?;
        _userStats = results[1] as Map<String, int>?;
        _achievements = results[2] as List<Map<String, dynamic>>?;
        _createdWorkshops = results[3] as List<Map<String, dynamic>>?;
        _enrolledWorkshops = results[4] as List<Map<String, dynamic>>?;
        _skills = results[5] as List<Map<String, dynamic>>?;
        _reviews = results[6] as List<Map<String, dynamic>>?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack("Error loading profile: ${e.toString()}");
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

    final stats = [
      {"label": "Workshops Taught", "value": _userStats?['workshopsTaught'] ?? 0, "icon": Icons.book_outlined, "color": theme.colorScheme.primary},
      {"label": "Students Taught", "value": _userStats?['studentsTaught'] ?? 0, "icon": Icons.group_outlined, "color": theme.colorScheme.secondary},
      {"label": "Total XP", "value": _userStats?['totalXp'] ?? 0, "icon": Icons.flash_on, "color": Colors.amber},
      {"label": "Badges Earned", "value": _userStats?['badgesEarned'] ?? 0, "icon": Icons.emoji_events_outlined, "color": Colors.purple},
    ];

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(theme),
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
                _buildAboutTab(theme, _achievements ?? []),
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

  Widget _buildHeader(ThemeData theme) {
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
                    Text(userName, style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(userUniversity, style: TextStyle(color: theme.colorScheme.onPrimary.withOpacity(0.7))),
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

  Widget _buildAboutTab(ThemeData theme, List<Map<String, dynamic>> achievements) {
    final userBio = _profileData?['bio'] ?? 'No bio available.';
    final userName = _profileData?['name'] ?? 'User';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("About $userName", style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(userBio, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        Text("Achievements", style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (achievements.isEmpty)
          const Text("No achievements earned yet.")
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: achievements.map((b) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(b["icon"] ?? "🏆", style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(b["name"] ?? "Achievement", style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
                      Text(b["description"] ?? "No description", style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: skills.isEmpty
          ? [const Text("No skills to display.")]
          : skills.map((s) {
        double progress = 0.25;
        if (s["level"] == "Expert") progress = 0.95;
        if (s["level"] == "Advanced") progress = 0.75;
        if (s["level"] == "Intermediate") progress = 0.5;

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
                Text("${s["endorsements"]} endorsements • ${s["workshops"]} workshops"),
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
              padding: const EdgeInsets.all(8),
              child: DropdownButtonFormField<String>(
                value: _language,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: "en", child: Text("English 🇺🇸")),
                  DropdownMenuItem(value: "es", child: Text("Español 🇪🇸")),
                  DropdownMenuItem(value: "zh", child: Text("中文 🇨🇳")),
                  DropdownMenuItem(value: "fr", child: Text("Français 🇫🇷")),
                  DropdownMenuItem(value: "de", child: Text("Deutsch 🇩🇪")),
                  DropdownMenuItem(value: "pt", child: Text("Português 🇧🇷")),
                ],
                onChanged: (val) {
                  setState(() => _language = val ?? "en");
                  _showSnack("Language changed to $_language");
                },
              ),
            ),
          ),
          const Divider(height: 32),

          // 🔒 Privacy & Security
          Text("Privacy & Security",
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          _buildToggle("Show on Leaderboards", true, "Display your ranking publicly", theme, (val) {}),
          _buildToggle("Profile Visibility", true, "Allow others to view your profile", theme, (val) {}),
          _buildToggle("Workshop History", true, "Show workshops you’ve attended", theme, (val) {}),
          const Divider(height: 32),

          // 🔔 Notifications
          Text("Notifications",
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          _buildToggle("Workshop Reminders", true, "Get notified before workshops start", theme, (val) {}),
          _buildToggle("New Workshop Alerts", true, "Be alerted about new workshops", theme, (val) {}),
          _buildToggle("Achievement Updates", true, "Get notified when earning badges", theme, (val) {}),
          const Divider(height: 32),

          // ⚙️ Performance
          Text("Performance",
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text("Low Bandwidth Mode (Beta)"),
            subtitle: const Text("Reduce image quality for slow connections"),
            value: _lowBandwidth,
            onChanged: (v) {
              setState(() => _lowBandwidth = v);
              _showSnack(v ? "Low bandwidth mode enabled" : "Low bandwidth mode disabled");
            },
            secondary: const Icon(Icons.network_check_outlined),
          ),
          const Divider(height: 32),

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
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
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
            leading: const Icon(Icons.email_outlined),
            title: const Text("Change Email"),
            subtitle: const Text("Update your login email address"),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Change Email"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      TextField(
                        decoration: InputDecoration(labelText: "New Email Address"),
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
                          _showSnack("Email updated (demo)");
                        },
                        child: const Text("Update")),
                  ],
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text("Export Data"),
            onTap: () => _showSnack("Profile data exported (demo)"),
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
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Log Out"),
            onTap: () async {
              try {
                await Supabase.instance.client.auth.signOut();
                // After sign out, the listener in main.dart should handle navigation
              } catch (e) {
                _showSnack("Error logging out: ${e.toString()}");
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