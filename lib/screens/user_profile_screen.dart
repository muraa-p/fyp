import 'package:flutter/material.dart';
import 'dart:math';

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isFollowing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final theme = Theme.of(context);
    final xp = user['xp'] ?? 5240;
    final level = ((xp ~/ 500) + 1);
    final currentXP = xp % 500;
    final progress = currentXP / 500;

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
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Share coming soon")));
                  }),
              IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Report coming soon")));
                  }),
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
                  // ✅ Only ONE CircleAvatar (duplicate removed)
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white24,
                    backgroundImage: (user['avatar'] != null && user['avatar'].toString().isNotEmpty)
                        ? NetworkImage(user['avatar'])
                        : null,
                    child: (user['avatar'] == null || user['avatar'].toString().isEmpty)
                        ? Text(
                      (user['name'] != null && user['name'].toString().isNotEmpty)
                          ? user['name'].toString().substring(0, 1).toUpperCase()
                          : (user['email'] != null && user['email'].toString().isNotEmpty)
                          ? user['email'].toString().substring(0, 1).toUpperCase()
                          : 'U',
                      style: const TextStyle(fontSize: 28, color: Colors.white),
                    )
                        : null,
                  ),
                  const SizedBox(height: 10),

                  // ✅ Name and University
                  Text(
                    (user['name'] != null && user['name'].toString().isNotEmpty)
                        ? user['name']
                        : (user['email'] ?? 'New User'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    (user['university'] != null && user['university'].toString().isNotEmpty)
                        ? user['university']
                        : 'Member since ${DateTime.now().year}',
                    style: const TextStyle(color: Colors.white70),
                  ),

                  const SizedBox(height: 8),

                  // ✅ Rating + Endorsements (restored)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.yellow, size: 16),
                      const SizedBox(width: 4),
                      Text("${user['rating'] ?? 4.8} rating",
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(width: 16),
                      const Icon(Icons.people_alt_rounded,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text("${user['endorsements'] ?? 127} endorsements",
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ✅ XP Progress
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Level $level",
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: Colors.white24,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${500 - currentXP} XP to next level",
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ✅ Follow + Conditional Message Button
                  Row(
                    children: [
                      // Follow/Unfollow button
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            isFollowing ? Colors.grey[300] : Colors.white,
                            foregroundColor: theme.colorScheme.primary,
                          ),
                          onPressed: () {
                            setState(() => isFollowing = !isFollowing);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(isFollowing
                                    ? "Now following ${user['name']}"
                                    : "Unfollowed ${user['name']}")));
                          },
                          child: Text(isFollowing ? "Following" : "Follow"),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // ✅ Message button visible only if both follow each other
                      if (isFollowing && (user['followsYou'] == true))
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.message_outlined, size: 18),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                  "Starting chat with ${user['name']}...",
                                ),
                              ));
                            },
                            label: const Text("Message"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Tabs
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

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAboutTab(user),
                  _buildWorkshopsTab(),
                  _buildSkillsTab(),
                  _buildReviewsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab(Map<String, dynamic> user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("About ${user['name']}",
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          user['bio'] ??
              "${user['name']} is an experienced instructor passionate about sharing knowledge and helping students grow.",
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        const Text("Achievements",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ["🎓 Expert Instructor", "⭐ Community Star", "📚 Knowledge Sharer"]
              .map((b) => Chip(label: Text(b)))
              .toList(),
        ),
        const SizedBox(height: 16),
        const Text("Specialties",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: (user['skills'] ??
              ['React', 'JavaScript', 'Node.js'])
              .map<Widget>((s) => Chip(label: Text(s)))
              .toList(),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildWorkshopsTab() {
    final workshops = [
      {'title': 'Advanced React Patterns', 'participants': 24, 'date': '2 weeks ago', 'rating': 4.9},
      {'title': 'Node.js for Beginners', 'participants': 18, 'date': '1 month ago', 'rating': 4.8},
      {'title': 'Flutter for Web', 'participants': 12, 'date': 'Next week', 'rating': null},
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workshops.length,
      itemBuilder: (_, i) {
        final w = workshops[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(w['title']?.toString() ?? ''),
            subtitle: Text("${w['participants']?.toString() ?? '0'} participants • ${w['date']?.toString() ?? ''}"),
            trailing: w['rating'] != null
                ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                Text(w['rating'].toString()),
              ],
            )
                : const Text("Upcoming"),
          ),
        );
      },
    );
  }

  Widget _buildSkillsTab() {
    final skills = [
      {'name': 'React', 'level': 'Expert', 'endorsements': 38},
      {'name': 'Node.js', 'level': 'Advanced', 'endorsements': 32},
      {'name': 'Python', 'level': 'Intermediate', 'endorsements': 15},
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: skills.length,
      itemBuilder: (_, i) {
        final s = skills[i];
        final levels = {'Beginner': 25, 'Intermediate': 50, 'Advanced': 75, 'Expert': 100};
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s['name']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(s['level']?.toString() ?? '',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (levels[s['level']] ?? 0) / 100,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
                color: Colors.green,
              ),
              const SizedBox(height: 4),
              Text("${s['endorsements']} endorsements",
                  style: const TextStyle(fontSize: 12)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    final reviews = [
      {
        'reviewer': 'Sarah Johnson',
        'comment': 'Excellent instructor!',
        'rating': 5,
        'date': '1 week ago'
      },
      {
        'reviewer': 'Mike Chen',
        'comment': 'Very knowledgeable and patient.',
        'rating': 4,
        'date': '2 weeks ago'
      },
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length,
      itemBuilder: (_, i) {
        final r = reviews[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              child: Text((r['reviewer']?.toString() ?? 'U')[0]),
            ),
            title: Text(r['reviewer']?.toString() ?? ''),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    5,
                        (index) => Icon(
                      Icons.star,
                      size: 16,
                      color: index < ((r['rating'] as num?) ?? 0)
                          ? Colors.amber
                          : Colors.grey[300],
                    ),
                  ),
                ),
                Text(r['comment']?.toString() ?? ''),
                Text(r['date']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}
