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
