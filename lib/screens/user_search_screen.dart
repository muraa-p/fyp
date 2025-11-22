import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Assuming you still have this model
// import '../models/user_model.dart';
import 'user_profile_screen.dart';
import 'followers_following_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  late Future<List<Map<String, dynamic>>> _usersFuture;

  // Method to fetch users from Supabase based on a search query
  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    try {
      // Get the current user's ID
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      // Use .or() to search in both name and email fields
      // .ilike() is a case-insensitive 'LIKE'
      final queryBuilder = Supabase.instance.client
          .from('users')
          .select('id, name, email') // Only select the columns you need
          .or('name.ilike.%$query%,email.ilike.%$query%');

      // If a user is logged in, exclude them from the results
      if (currentUserId != null) {
        queryBuilder.neq('id', currentUserId);
      }

      final data = await queryBuilder.order('name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      // Handle errors, e.g., by showing a snackbar
      print('Error fetching users: $e');
      return []; // Return an empty list on error
    }
  }

  @override
  void initState() {
    super.initState();
    // Initial search with an empty query to get all users (except the current user)
    _usersFuture = _searchUsers('');
  }

  @override
  Widget build(BuildContext context) {
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
              // Trigger a new search whenever the text changes
              onChanged: (value) {
                setState(() {
                  _usersFuture = _searchUsers(value);
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                // Show a loading indicator while waiting for data
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Show an error message if something went wrong
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                // If there's no data, show a message
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No users found"));
                }
                // Display the list of users
                final users = snapshot.data!;
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final user = users[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(user["name"]?.isNotEmpty == true ? user["name"][0] : 'U'),
                      ),
                      title: Text(user["name"] ?? 'No Name'),
                      subtitle: Text(user["email"] ?? 'No Email'),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}