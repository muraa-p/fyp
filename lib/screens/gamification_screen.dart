import 'package:flutter/material.dart';

import '../main.dart';

class GamificationScreen extends StatefulWidget {
  final Function(String) onNavigate;
  final int initialTab;
  const GamificationScreen({
    super.key,
    required this.onNavigate,
    this.initialTab = 0,
  });

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State variables for our data
  Map<String, dynamic>? _userStats;
  List<dynamic>? _leaderboard;
  List<dynamic>? _badges;
  List<dynamic>? _achievements;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadGamificationData();
  }

  Future<void> _refreshGamificationData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _loadGamificationData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGamificationData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _error = "User not logged in.";
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await supabase.rpc('get_user_gamification_data', params: {
        'current_user_id': userId,
      });

      final data = response is List ? response.first : response;

      if (data != null) {
        setState(() {
          _userStats = {
            "totalXP": data['user_xp'],
            "level": data['user_level'],
            "nextLevelXP": (data['user_level'] + 1) * 500,
            "badgesEarned": data['badges_earned'],
            "workshopsAttended": data['workshops_attended'],
            "workshopsTaught": data['workshops_taught'],
            "endorsements": data['endorsements_count'],
          };
          _leaderboard = data['leaderboard'];
          _badges = data['user_badges_data'];
          _achievements = data['user_achievements_data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Received no data from server.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Failed to load data: $e";
        _isLoading = false;
      });
    }
  }

  Color rarityColor(String rarity, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    switch (rarity.toLowerCase()) {
      case "common":
        return isDark ? Colors.grey.shade600 : Colors.grey;
      case "uncommon":
        return isDark ? Colors.green.shade600 : Colors.green;
      case "rare":
        return isDark ? Colors.blue.shade600 : Colors.blue;
      case "epic":
        return isDark ? Colors.purple.shade600 : Colors.purple;
      case "legendary":
        return isDark ? Colors.amber.shade600 : Colors.amber;
      default:
        return isDark ? Colors.grey.shade600 : Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("Gamification"),
          backgroundColor: Colors.transparent,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
        ),
        body: Center(
          child: Text(_error!, style: theme.textTheme.bodyLarge),
        ),
      );
    }

    if (_userStats == null || _leaderboard == null || _badges == null || _achievements == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("Gamification"),
          backgroundColor: Colors.transparent,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
        ),
        body: Center(
          child: Text("Could not load gamification data.", style: theme.textTheme.bodyLarge),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Gamification"),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.mounted) Navigator.pop(context);
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.emoji_events, color: theme.colorScheme.secondary),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Badges"),
            Tab(text: "Leaderboard"),
            Tab(text: "Achievements"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- Overview ---
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: theme.cardTheme.color,
                shape: theme.cardTheme.shape,
                elevation: theme.cardTheme.elevation,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Level ${_userStats!["level"]}", style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text("${_userStats!["totalXP"]} / ${_userStats!["nextLevelXP"]} XP",
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_userStats!["totalXP"]! / _userStats!["nextLevelXP"]!),
                        backgroundColor: theme.colorScheme.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${_userStats!["nextLevelXP"]! - _userStats!["totalXP"]!} XP to next level",
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.8,
                children: [
                  _StatCard("🎓", "Workshops Attended", "${_userStats!["workshopsAttended"]}", theme),
                  _StatCard("👨‍🏫", "Workshops Taught", "${_userStats!["workshopsTaught"]}", theme),
                  _StatCard("🏆", "Badges Earned", "${_userStats!["badgesEarned"]}", theme),
                  _StatCard("👍", "Endorsements", "${_userStats!["endorsements"]}", theme),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                color: theme.cardTheme.color,
                shape: theme.cardTheme.shape,
                elevation: theme.cardTheme.elevation,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Recent Achievements", style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ...(_badges!
                          .where((b) => b["earned"] == true)
                          .take(3)
                          .map((b) => ListTile(
                        leading: Text(b["icon"] as String, style: const TextStyle(fontSize: 24)),
                        title: Text(b["name"] as String, style: theme.textTheme.titleSmall),
                        subtitle: Text(b["description"] as String, style: theme.textTheme.bodySmall),
                        trailing: Chip(
                          label: Text(b["rarity"] as String),
                          backgroundColor: rarityColor(b["rarity"] as String, theme),
                          labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ))),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // --- Badges ---
          ListView(
            padding: const EdgeInsets.all(16),
            children: _badges!.map((b) {
              final bool earned = b["earned"] == true;
              final double progress = (b["progress"] as int? ?? 0) / (b["max"] as int? ?? 1);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: earned ? theme.cardTheme.color : theme.cardTheme.color?.withOpacity(0.5),
                shape: theme.cardTheme.shape,
                elevation: theme.cardTheme.elevation,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b["icon"] as String, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(b["name"] as String, style: theme.textTheme.titleSmall),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(b["rarity"] as String),
                                  backgroundColor: rarityColor(b["rarity"] as String, theme),
                                  labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                            Text(b["description"] as String, style: theme.textTheme.bodySmall),
                            if (!earned) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: theme.colorScheme.surface,
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                              ),
                              Text("${b["progress"]}/${b["max"]}", style: theme.textTheme.bodySmall),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // --- Leaderboard ---
          ListView(
            padding: const EdgeInsets.all(16),
            children: _leaderboard!.map((u) {
              final bool isMe = u["id"] == supabase.auth.currentUser?.id;
              return Card(
                color: isMe ? theme.colorScheme.primary.withOpacity(0.1) : theme.cardTheme.color,
                shape: theme.cardTheme.shape,
                elevation: theme.cardTheme.elevation,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    child: Text(u["rank"].toString()),
                  ),
                  title: Text(
                    u["name"] as String,
                    style: TextStyle(
                      fontWeight: isMe ? FontWeight.bold : null,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  subtitle: Text(
                    "${u["xp"]} XP • ${u["badges"]} Badges",
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Text(
                    "#${u["rank"]}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // --- Achievements ---
          ListView(
            padding: const EdgeInsets.all(16),
            children: _achievements!.map((a) {
              final progress = (a["progress"] as int? ?? 0) / (a["max"] as int? ?? 1);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: theme.cardTheme.color,
                shape: theme.cardTheme.shape,
                elevation: theme.cardTheme.elevation,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a["icon"] as String, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(a["title"] as String, style: theme.textTheme.titleSmall),
                                Chip(
                                  label: Text(a["reward"] as String),
                                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color: theme.colorScheme.secondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Text(a["description"] as String, style: theme.textTheme.bodySmall),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: theme.colorScheme.surface,
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                            ),
                            Text("${a["progress"]}/${a["max"]}", style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final ThemeData theme;

  const _StatCard(this.icon, this.title, this.value, this.theme);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: theme.cardTheme.color,
      shape: theme.cardTheme.shape,
      elevation: theme.cardTheme.elevation,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}