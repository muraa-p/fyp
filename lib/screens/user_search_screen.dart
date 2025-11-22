import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'user_profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _controller = TextEditingController();

  // Replace this with Supabase fetch later
  final List<Map<String, dynamic>> mockUsers = [
    {"id": "1", "name": "Sarah Kim", "email": "sarah@example.com"},
    {"id": "2", "name": "Michael Chen", "email": "mike@example.com"},
    {"id": "3", "name": "Emma Rodriguez", "email": "emma@example.com"},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtered = mockUsers.where((u) {
      final q = _controller.text.toLowerCase();
      return u["name"]!.toLowerCase().contains(q) ||
          u["email"]!.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Find Users"),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FollowersFollowingScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: "Search users...",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text("No users found"))
                : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final user = filtered[i];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(user["name"][0]),
                  ),
                  title: Text(user["name"]),
                  subtitle: Text(user["email"]),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            UserProfileScreen(user: user), // YOUR screen
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// New screen to display followers and following
class FollowersFollowingScreen extends StatefulWidget {
  const FollowersFollowingScreen({super.key});

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock data for followers and following
  final List<Map<String, dynamic>> mockFollowers = [
    {"id": "4", "name": "John Doe", "email": "john@example.com"},
    {"id": "5", "name": "Jane Smith", "email": "jane@example.com"},
  ];

  final List<Map<String, dynamic>> mockFollowing = [
    {"id": "6", "name": "Alice Johnson", "email": "alice@example.com"},
    {"id": "7", "name": "Bob Williams", "email": "bob@example.com"},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Followers & Following"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Followers"),
            Tab(text: "Following"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Followers tab
          ListView.builder(
            itemCount: mockFollowers.length,
            itemBuilder: (context, i) {
              final user = mockFollowers[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(user["name"][0]),
                ),
                title: Text(user["name"]),
                subtitle: Text(user["email"]),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(user: user),
                    ),
                  );
                },
              );
            },
          ),
          // Following tab
          ListView.builder(
            itemCount: mockFollowing.length,
            itemBuilder: (context, i) {
              final user = mockFollowing[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(user["name"][0]),
                ),
                title: Text(user["name"]),
                subtitle: Text(user["email"]),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(user: user),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}