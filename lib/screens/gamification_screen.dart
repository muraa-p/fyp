import 'package:flutter/material.dart';

import '../main.dart';

// This file now relies on the global `supabase` variable defined in main.dart

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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGamificationData() async {
    // The global 'supabase' variable is now accessible here
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

      // FIX: The response from an RPC that returns a table is a list.
      // We need to get the first element, which contains our data.
      final data = response is List ? response.first : response;

      if (data != null) {
        setState(() {
          _userStats = {
            "totalXP": data['user_xp'],
            "level": data['user_level'],
            // Note: nextLevelXP logic needs to be defined. For now, a placeholder.
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

  Color rarityColor(String rarity) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Gamification")),
        body: Center(
          child: Text(_error!),
        ),
      );
    }

    if (_userStats == null || _leaderboard == null || _badges == null || _achievements == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Gamification")),
        body: const Center(
          child: Text("Could not load gamification data."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gamification"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.mounted) Navigator.pop(context);
          },
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.emoji_events, color: Colors.amber),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Level ${_userStats!["level"]}", style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text("${_userStats!["totalXP"]} / ${_userStats!["nextLevelXP"]} XP"),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_userStats!["totalXP"]! / _userStats!["nextLevelXP"]!),
                        backgroundColor: Colors.grey[300],
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
                  _StatCard("🎓", "Workshops Attended", "${_userStats!["workshopsAttended"]}"),
                  _StatCard("👨‍🏫", "Workshops Taught", "${_userStats!["workshopsTaught"]}"),
                  _StatCard("🏆", "Badges Earned", "${_userStats!["badgesEarned"]}"),
                  _StatCard("👍", "Endorsements", "${_userStats!["endorsements"]}"),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Recent Achievements", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...(_badges!
                          .where((b) => b["earned"] == true)
                          .take(3)
                          .map((b) => ListTile(
                        leading: Text(b["icon"] as String, style: const TextStyle(fontSize: 24)),
                        title: Text(b["name"] as String),
                        subtitle: Text(b["description"] as String),
                        trailing: Chip(
                          label: Text(b["rarity"] as String),
                          backgroundColor: rarityColor(b["rarity"] as String),
                          labelStyle: const TextStyle(color: Colors.white),
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
                color: earned ? null : Colors.grey.shade100,
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
                                Text(b["name"] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(b["rarity"] as String),
                                  backgroundColor: rarityColor(b["rarity"] as String),
                                  labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                            Text(b["description"] as String, style: theme.textTheme.bodySmall),
                            if (!earned) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: progress),
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
              // The global 'supabase' variable is also accessible here
              final bool isMe = u["id"] == supabase.auth.currentUser?.id;
              return Card(
                color: isMe ? Colors.blue.shade50 : null,
                child: ListTile(
                  leading: CircleAvatar(child: Text(u["rank"].toString())),
                  title: Text(u["name"] as String,
                      style: TextStyle(fontWeight: isMe ? FontWeight.bold : null)),
                  subtitle: Text("${u["xp"]} XP • ${u["badges"]} Badges"),
                  trailing: Text("#${u["rank"]}", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                Text(a["title"] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Chip(label: Text(a["reward"] as String), labelStyle: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            Text(a["description"] as String, style: theme.textTheme.bodySmall),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: progress),
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
  const _StatCard(this.icon, this.title, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            Text(value,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}