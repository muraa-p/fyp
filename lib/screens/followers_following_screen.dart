import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_screen.dart';

class FollowersFollowingScreen extends StatefulWidget {
  const FollowersFollowingScreen({super.key});

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _followersFuture;
  late Future<List<Map<String, dynamic>>> _followingFuture;

  // Get the current user's ID from Supabase Auth
  final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Start fetching data
    _followersFuture = _fetchFollowers();
    _followingFuture = _fetchFollowing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Fetch users who are following the current user
  Future<List<Map<String, dynamic>>> _fetchFollowers() async {
    if (currentUserId == null) return [];
    try {
      // This query joins 'follows' with 'users'
      // It selects all columns from the 'users' table where the user is a follower
      final data = await Supabase.instance.client
          .from('follows')
          .select('users!follows_follower_id_fkey(*)') // Selects user data via the foreign key relationship
          .eq('following_id', currentUserId!);
      // The result is a list of maps, where each map contains a 'users' key with the user's data
      return data.map((follow) => follow['users'] as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error fetching followers: $e');
      return [];
    }
  }

  // Fetch users that the current user is following
  Future<List<Map<String, dynamic>>> _fetchFollowing() async {
    if (currentUserId == null) return [];
    try {
      final data = await Supabase.instance.client
          .from('follows')
          .select('users!follows_following_id_fkey(*)') // Selects user data via the foreign key relationship
          .eq('follower_id', currentUserId!);
      return data.map((follow) => follow['users'] as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error fetching following: $e');
      return [];
    }
  }

  Widget _buildUserList(Future<List<Map<String, dynamic>>> future) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No users found"));
        }
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
    );
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
          // Wrap the user list in a RefreshIndicator
          RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _followersFuture = _fetchFollowers();
              });
            },
            child: _buildUserList(_followersFuture),
          ),
          RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _followingFuture = _fetchFollowing();
              });
            },
            child: _buildUserList(_followingFuture),
          ),
        ],
      ),
    );
  }
}