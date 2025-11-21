import 'package:flutter/material.dart';

class GamificationScreen extends StatefulWidget {
  final Function(String) onNavigate;
  final int initialTab; // NEW: allows opening directly to a specific tab
  const GamificationScreen({
    super.key,
    required this.onNavigate,
    this.initialTab = 0, // default: Overview tab
  });

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen>
    with SingleTickerProviderStateMixin { // ✅ FIX

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this, // ✅ FIX — safe and correct
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Map<String, int> userStats = {
      "totalXP": 2340,
      "level": 7,
      "nextLevelXP": 2800,
      "badgesEarned": 12,
      "workshopsAttended": 18,
      "workshopsTaught": 5,
      "endorsements": 23,
      "rank": 15,
      "totalUsers": 1247,
    };

    final List<Map<String, dynamic>> badges = [
      {
        "name": "First Steps",
        "desc": "Complete your first workshop",
        "icon": "🎯",
        "earned": true,
        "rarity": "Common"
      },
      {
        "name": "Knowledge Seeker",
        "desc": "Attend 10 workshops",
        "icon": "📚",
        "earned": true,
        "rarity": "Common"
      },
      {
        "name": "Rising Star",
        "desc": "Teach your first workshop",
        "icon": "⭐",
        "earned": true,
        "rarity": "Uncommon"
      },
      {
        "name": "Community Leader",
        "desc": "Teach 10 workshops",
        "icon": "👑",
        "earned": false,
        "progress": 5,
        "max": 10,
        "rarity": "Rare"
      },
      {
        "name": "Skill Master",
        "desc": "Earn endorsements in 5 skills",
        "icon": "🏆",
        "earned": true,
        "rarity": "Epic"
      },
      {
        "name": "Legendary Mentor",
        "desc": "Teach 50 workshops",
        "icon": "🌟",
        "earned": false,
        "progress": 5,
        "max": 50,
        "rarity": "Legendary"
      },
    ];

    final List<Map<String, dynamic>> leaderboard = [
      {"rank": 1, "name": "Emma Wilson", "avatar": "👩‍💼", "xp": 5240, "badges": 28},
      {"rank": 2, "name": "James Chen", "avatar": "👨‍💻", "xp": 4980, "badges": 25},
      {"rank": 3, "name": "Sofia Rodriguez", "avatar": "👩‍🎓", "xp": 4650, "badges": 23},
      {"rank": 4, "name": "Michael Park", "avatar": "👨‍🏫", "xp": 4320, "badges": 21},
      {"rank": 5, "name": "Lisa Anderson", "avatar": "👩‍🔬", "xp": 3990, "badges": 19},
      {"rank": 15, "name": "You", "avatar": "👤", "xp": 2340, "badges": 12, "isMe": true},
    ];

    final List<Map<String, dynamic>> achievements = [
      {
        "title": "Perfect Attendance",
        "desc": "Attend 5 workshops this month",
        "progress": 3,
        "max": 5,
        "reward": "+150 XP",
        "icon": "🎯"
      },
      {
        "title": "Social Butterfly",
        "desc": "Start chats with 10 new people",
        "progress": 7,
        "max": 10,
        "reward": "+100 XP",
        "icon": "🦋"
      },
      {
        "title": "Skill Collector",
        "desc": "Learn 3 new skills this month",
        "progress": 1,
        "max": 3,
        "reward": "Skill Explorer Badge",
        "icon": "🎪"
      },
    ];

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
                      Text("Level ${userStats["level"]}", style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text("${userStats["totalXP"]} / ${userStats["nextLevelXP"]} XP"),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (userStats["totalXP"]! / userStats["nextLevelXP"]!),
                        backgroundColor: Colors.grey[300],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${userStats["nextLevelXP"]! - userStats["totalXP"]!} XP to next level",
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
                  _StatCard("🎓", "Workshops Attended", "${userStats["workshopsAttended"]}"),
                  _StatCard("👨‍🏫", "Workshops Taught", "${userStats["workshopsTaught"]}"),
                  _StatCard("🏆", "Badges Earned", "${userStats["badgesEarned"]}"),
                  _StatCard("👍", "Endorsements", "${userStats["endorsements"]}"),
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
                      ...badges
                          .where((b) => b["earned"] == true)
                          .take(3)
                          .map((b) => ListTile(
                        leading: Text(b["icon"] as String, style: const TextStyle(fontSize: 24)),
                        title: Text(b["name"] as String),
                        subtitle: Text(b["desc"] as String),
                        trailing: Chip(
                          label: Text(b["rarity"] as String),
                          backgroundColor: rarityColor(b["rarity"] as String),
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // --- Badges ---
          ListView(
            padding: const EdgeInsets.all(16),
            children: badges.map((b) {
              final bool earned = b["earned"] == true;
              final double? progress = (!earned && b["progress"] != null && b["max"] != null)
                  ? (((b["progress"] as num?) ?? 0) / ((b["max"] as num?) ?? 1))
                  : null;

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
                            Text(b["desc"] as String, style: theme.textTheme.bodySmall),
                            if (progress != null) ...[
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
            children: leaderboard.map((u) {
              final bool isMe = u["isMe"] == true;
              return Card(
                color: isMe ? Colors.blue.shade50 : null,
                child: ListTile(
                  leading: Text(u["avatar"] as String, style: const TextStyle(fontSize: 28)),
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
            children: achievements.map((a) {
              final progress = ((a["progress"] as num?) ?? 0) / ((a["max"] as num?) ?? 1);
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
                            Text(a["desc"] as String, style: theme.textTheme.bodySmall),
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
  const _StatCard(this.icon, this.title, this.value, {super.key});

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
