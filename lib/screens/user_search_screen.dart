import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    // First, ensure a user is logged in. If not, return an empty list.
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      // You could also navigate to a login screen here if desired
      print('User is not authenticated. Cannot fetch users.');
      return [];
    }

    try {
      // This query is more explicit. It first filters OUT the current user,
      // and then applies the search filter to the remaining users.
      final data = await Supabase.instance.client
          .from('users')
          .select('id, name, email, avatar_url') // Select avatar_url for better UI
          .neq('id', currentUserId) // Exclude the current user FIRST
          .or('name.ilike.%$query%,email.ilike.%$query%') // Then search
          .order('name');
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
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _usersFuture = _searchUsers(_controller.text);
          });
        },
        color: Theme.of(context).colorScheme.primary,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: "Search users...",
                  prefixIcon: Icon(Icons.search),
                ),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    // This makes pull-to-refresh work even when empty
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 300), // Gives space to pull down
                        Center(child: Text("No users found")),
                      ],
                    );
                  }

                  final users = snapshot.data!;
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(), // Ensures refresh works even on short lists
                    itemCount: users.length,
                    itemBuilder: (context, i) {
                      final user = users[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['avatar_url'] != null
                              ? NetworkImage(user['avatar_url'])
                              : null,
                          child: user['avatar_url'] == null
                              ? Text(user["name"]?.isNotEmpty == true
                              ? user["name"][0].toUpperCase()
                              : 'U')
                              : null,
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
      ),
    );
  }
}