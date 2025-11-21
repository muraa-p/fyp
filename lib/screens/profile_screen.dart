import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/user_model.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  final bool isCurrentUser;

  const ProfileScreen({
    super.key,
    required this.user,
    this.isCurrentUser = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isFollowing = false;
  late UserModel _user;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _user = widget.user;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final enrolled = appState.enrolledWorkshops;
    final created = appState.createdWorkshops;

    final stats = [
      {
        "label": "Workshops Taught",
        "value": created.length,
        "icon": Icons.book_outlined,
        "color": theme.colorScheme.primary
      },
      {
        "label": "Students Taught",
        "value": 420,
        "icon": Icons.group_outlined,
        "color": theme.colorScheme.secondary
      },
      {
        "label": "Total XP",
        "value": 5240,
        "icon": Icons.flash_on,
        "color": Colors.amber
      },
      {
        "label": "Badges Earned",
        "value": 4,
        "icon": Icons.emoji_events_outlined,
        "color": Colors.purple
      },
    ];

    final badges = [
      {"name": "Expert Instructor", "desc": "Taught over 20 workshops", "icon": "🎓"},
      {"name": "Community Star", "desc": "Highly rated by students", "icon": "⭐"},
      {"name": "Knowledge Sharer", "desc": "Shared expertise", "icon": "📚"},
      {"name": "Mentor", "desc": "Helped 50+ students", "icon": "🤝"},
    ];

    final mockSkills = [
      {"name": "JavaScript", "level": "Expert", "endorsements": 45, "workshops": 15},
      {"name": "React", "level": "Expert", "endorsements": 38, "workshops": 12},
      {"name": "Node.js", "level": "Advanced", "endorsements": 32, "workshops": 10},
      {"name": "Python", "level": "Intermediate", "endorsements": 15, "workshops": 5},
    ];

    final reviews = [
      {
        "reviewer": "Sarah Johnson",
        "workshop": "React Hooks Deep Dive",
        "rating": 5,
        "comment": "Excellent instructor!",
        "date": "1 week ago"
      },
      {
        "reviewer": "Mike Chen",
        "workshop": "JavaScript Fundamentals",
        "rating": 5,
        "comment": "Very knowledgeable.",
        "date": "2 weeks ago"
      },
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
            tabs: const [
              Tab(text: "About"),
              Tab(text: "Workshops"),
              Tab(text: "Skills"),
              Tab(text: "Reviews"),
              Tab(text: "Settings"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAboutTab(theme, badges),
                _buildWorkshopsTab(theme, created, enrolled),
                _buildSkillsTab(theme, mockSkills),
                _buildReviewsTab(theme, reviews),
                _buildSettingsTab(theme, appState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------
  // HEADER
  // ----------------------------------------------
  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.onPrimary.withOpacity(0.2),
                child: Text(
                  (_user.name?.isNotEmpty ?? false)
                      ? _user.name![0].toUpperCase()
                      : (_user.email?.isNotEmpty ?? false)
                      ? _user.email![0].toUpperCase()
                      : "U",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user.name?.isNotEmpty == true
                          ? _user.name!
                          : (_user.email ?? "User"),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _user.university?.isNotEmpty == true
                          ? _user.university!
                          : "Member since 2024",
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --- EDIT BUTTON ---
          if (widget.isCurrentUser)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        user: _user,
                        onUpdate: (newUser) {},
                      ),
                    ),
                  );

                  if (updated != null) {
                    setState(() => _user = updated);
                  }
                },
                icon: const Icon(Icons.edit),
                label: const Text("Edit Profile"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.onPrimary,
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => isFollowing = !isFollowing);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isFollowing
                                ? "Now following ${_user.name ?? 'User'}"
                                : "Unfollowed ${_user.name ?? 'User'}",
                          ),
                        ),
                      );
                    },
                    child: Text(isFollowing ? "Following" : "Follow"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("Messaging ${_user.name ?? 'User'}")),
                      );
                    },
                    child: const Text("Message"),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------
  // STATS
  // ----------------------------------------------
  Widget _buildStats(ThemeData theme, List stats) {
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
                  Text("${s["value"]}",
                      style: theme.textTheme.titleLarge!
                          .copyWith(fontWeight: FontWeight.bold)),
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

  // ----------------------------------------------
  // ABOUT TAB
  // ----------------------------------------------
  Widget _buildAboutTab(ThemeData theme, List badges) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("About ${_user.name}", style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(_user.bio ?? "", style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        Text("Achievements", style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: badges.map((b) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(b["icon"], style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(
                      b["name"],
                      style: theme.textTheme.bodyMedium!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(b["desc"], style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ----------------------------------------------
  // WORKSHOPS TAB
  // ----------------------------------------------
  Widget _buildWorkshopsTab(ThemeData theme, List created, List enrolled) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Workshops Conducted", style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (created.isEmpty)
          const Text("No workshops created yet.", style: TextStyle(color: Colors.grey)),
        ...created.map((ws) {
          final title = ws["title"] ?? "Untitled";
          final participants = ws["participants"] ?? 0;
          return Card(
            child: ListTile(
              title: Text(title),
              subtitle: Text("$participants participants"),
            ),
          );
        }),

        const SizedBox(height: 20),

        Text("Workshops Enrolled In", style: theme.textTheme.titleMedium),
        if (enrolled.isEmpty)
          const Text("No enrolled workshops.",
              style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  // ----------------------------------------------
  // SKILLS TAB
  // ----------------------------------------------
  Widget _buildSkillsTab(ThemeData theme, List skills) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: skills.map((s) {
        final name = s["name"];
        final level = s["level"];
        double progress = level == "Expert"
            ? 0.95
            : level == "Advanced"
            ? 0.75
            : level == "Intermediate"
            ? 0.5
            : 0.25;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                ),
                const SizedBox(height: 6),
                Text("${s["endorsements"]} endorsements • ${s["workshops"]} workshops"),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ----------------------------------------------
  // REVIEWS TAB
  // ----------------------------------------------
  Widget _buildReviewsTab(ThemeData theme, List reviews) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: reviews.map((r) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(r["reviewer"]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${r["workshop"]} • ${r["date"]}",
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(r["comment"]),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                    (i) => Icon(Icons.star,
                    size: 16,
                    color: i < r["rating"] ? Colors.amber : theme.disabledColor),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ----------------------------------------------
  // SETTINGS TAB
  // ----------------------------------------------
  Widget _buildSettingsTab(ThemeData theme, AppState appState) {
    bool isDarkMode = appState.isDarkMode;
    String language = "en";
    bool lowBandwidth = false;

    void showSnack(String text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(text)));
    }

    return StatefulBuilder(
      builder: (context, setState) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🌗 Appearance
          Text("Appearance",
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
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
                value: language,
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
                  setState(() => language = val ?? "en");
                  showSnack("Language changed to $language");
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
          _buildToggle("Show on Leaderboards", true,
              "Display your ranking publicly", theme),
          _buildToggle("Profile Visibility", true,
              "Allow others to view your profile", theme),
          _buildToggle("Workshop History", true,
              "Show workshops you’ve attended", theme),
          const Divider(height: 32),

          // 🔔 Notifications
          Text("Notifications",
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          _buildToggle("Workshop Reminders", true,
              "Get notified before workshops start", theme),
          _buildToggle("New Workshop Alerts", true,
              "Be alerted about new workshops", theme),
          _buildToggle("Achievement Updates", true,
              "Get notified when earning badges", theme),
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
            value: lowBandwidth,
            onChanged: (v) {
              setState(() => lowBandwidth = v);
              showSnack(v
                  ? "Low bandwidth mode enabled"
                  : "Low bandwidth mode disabled");
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
                          showSnack("Password updated (demo)");
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
                          showSnack("Email updated (demo)");
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
            onTap: () => showSnack("Profile data exported (demo)"),
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
                          showSnack("Account deletion initiated");
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
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(context, "/", (_) => false);
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


  Widget _buildToggle(String title, bool value, String subtitle, ThemeData theme) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: (v) {},
    );
  }
}
