import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EndorsementsScreen extends StatefulWidget {
  final Function(String)? onNavigate;
  const EndorsementsScreen({super.key, this.onNavigate});

  @override
  State<EndorsementsScreen> createState() => _EndorsementsScreenState();
}

class _EndorsementsScreenState extends State<EndorsementsScreen> {
  String? selectedSkill;
  final TextEditingController endorsementText = TextEditingController();
  final TextEditingController userSearchController = TextEditingController();
  final TextEditingController workshopSearchController =
      TextEditingController();
  final TextEditingController skillSearchController = TextEditingController();

  bool isLoading = true;
  bool isSearchingUsers = false;
  bool isSearchingWorkshops = false;
  bool isSearchingSkills = false;
  bool isLoadingUserDetails = false;
  bool isLoadingAllUsers = false;
  bool isSendingEndorsement = false;

  List<Map<String, dynamic>> mySkills = [];
  List<Map<String, dynamic>> endorsementsReceived = [];
  List<Map<String, dynamic>> endorsementsGiven = [];
  List<Map<String, dynamic>> pendingEndorsements = [];

  // For search functionality
  List<Map<String, dynamic>> allUsers = []; // Store all users
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> workshopSearchResults = [];
  List<Map<String, dynamic>> skillSearchResults = [];

  // For selected user details
  List<Map<String, dynamic>> userWorkshops = [];
  List<String> userSkills = [];

  // Selected values for endorsement
  Map<String, dynamic>? selectedUser;
  Map<String, dynamic>? selectedWorkshop;
  String? selectedSkillForEndorsement;

  // Timer for debouncing search
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Load user's skills from users table (skills_to_teach field)
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('skills_to_teach')
          .eq('id', user.id)
          .single();

      // Load endorsements received with explicit relationship names
      final receivedResponse = await Supabase.instance.client
          .from('endorsements')
          .select(
              '*, endorsed_by:users!endorsements_endorsed_by_fkey(name, avatar_url)')
          .eq('endorsed_user', user.id)
          .order('created_at', ascending: false);

      // Load endorsements given with explicit relationship names
      final givenResponse = await Supabase.instance.client
          .from('endorsements')
          .select(
              '*, endorsed_user:users!endorsements_endorsed_user_fkey(name, avatar_url), workshops(title)')
          .eq('endorsed_by', user.id)
          .order('created_at', ascending: false);

      // Load pending endorsements (workshop requests)
      final pendingResponse = await Supabase.instance.client
          .from('workshop_requests')
          .select(
              '*, requester:users(name, avatar_url), workshops!inner(title, skills, creator_id)')
          .eq('workshops.creator_id', user.id)
          .eq('status', 'pending');

      // Count endorsements by skill
      final skillCounts = <String, int>{};
      for (var endorsement in receivedResponse) {
        final skill = endorsement['skill'] as String;
        skillCounts[skill] = (skillCounts[skill] ?? 0) + 1;
      }

      // Convert skills_to_teach to mySkills format
      final List<Map<String, dynamic>> formattedSkills = [];
      if (userResponse['skills_to_teach'] != null) {
        for (var skill in userResponse['skills_to_teach']) {
          formattedSkills.add({
            'name': skill,
            'endorsements': skillCounts[skill] ?? 0,
            'level': _getSkillLevel(skillCounts[skill] ?? 0),
          });
        }
      }

      // Force a complete state update
      if (mounted) {
        setState(() {
          mySkills = formattedSkills;
          endorsementsReceived =
              List<Map<String, dynamic>>.from(receivedResponse);
          endorsementsGiven = List<Map<String, dynamic>>.from(givenResponse);
          pendingEndorsements =
              List<Map<String, dynamic>>.from(pendingResponse);
          isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $error')),
        );
      }
    }
  }

  String _getSkillLevel(int endorsements) {
    if (endorsements >= 15) return 'Expert';
    if (endorsements >= 8) return 'Advanced';
    if (endorsements >= 3) return 'Intermediate';
    return 'Beginner';
  }

  // Function to load all users
  Future<void> _loadAllUsers() async {
    if (allUsers.isNotEmpty) return; // Already loaded

    setState(() {
      isLoadingAllUsers = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, name, avatar_url, skills_to_teach')
          .order('name')
          .limit(100); // Limit to prevent loading too many users at once

      setState(() {
        allUsers = List<Map<String, dynamic>>.from(response);
        searchResults = allUsers; // Initially show all users
        isLoadingAllUsers = false;
      });
    } catch (error) {
      setState(() {
        isLoadingAllUsers = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: $error')),
      );
    }
  }

  // Reduce debounce time and improve search responsiveness

  void _onWorkshopSearchChanged(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 200), () {
      // Reduced from 300ms
      _searchWorkshops(query);
    });
  }

  void _onSkillSearchChanged(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 200), () {
      // Reduced from 300ms
      _searchSkills(query);
    });
  }

  // Filter users from the already loaded list

  Future<void> _searchWorkshops(String query) async {
    if (query.isEmpty) {
      setState(() {
        workshopSearchResults = [];
        isSearchingWorkshops = false;
      });
      return;
    }

    setState(() {
      isSearchingWorkshops = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('workshops')
          .select('id, title, creator_id, creator:users(name), skills')
          .ilike('title', '%$query%')
          .limit(10);

      setState(() {
        workshopSearchResults = List<Map<String, dynamic>>.from(response);
        isSearchingWorkshops = false;
      });
    } catch (error) {
      setState(() {
        isSearchingWorkshops = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching workshops: $error')),
      );
    }
  }

  Future<void> _searchSkills(String query) async {
    if (query.isEmpty) {
      setState(() {
        skillSearchResults = [];
        isSearchingSkills = false;
      });
      return;
    }

    setState(() {
      isSearchingSkills = true;
    });

    try {
      // Get skills from the skills table
      final skillsResponse = await Supabase.instance.client
          .from('skills')
          .select('id, name')
          .ilike('name', '%$query%')
          .limit(10);

      // Also get skills from users' skills_to_teach field
      final usersResponse = await Supabase.instance.client
          .from('users')
          .select('skills_to_teach')
          .not('skills_to_teach', 'is', null);

      // Extract unique skills from users
      final Set<String> userSkills = {};
      for (var user in usersResponse) {
        if (user['skills_to_teach'] != null) {
          for (var skill in user['skills_to_teach']) {
            if (skill.toLowerCase().contains(query.toLowerCase())) {
              userSkills.add(skill);
            }
          }
        }
      }

      // Combine results
      final List<Map<String, dynamic>> combinedResults = [];
      combinedResults.addAll(List<Map<String, dynamic>>.from(skillsResponse));

      for (var skill in userSkills) {
        combinedResults.add({
          'id': null, // No ID for skills from users table
          'name': skill,
        });
      }

      setState(() {
        skillSearchResults = combinedResults;
        isSearchingSkills = false;
      });
    } catch (error) {
      setState(() {
        isSearchingSkills = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching skills: $error')),
      );
    }
  }

  // Function to load user details (workshops and skills)
  Future<void> _loadUserDetails(String userId) async {
    setState(() {
      isLoadingUserDetails = true;
      userWorkshops = [];
      userSkills = [];
    });

    try {
      // Get workshops conducted by the user
      final workshopsResponse = await Supabase.instance.client
          .from('workshops')
          .select('id, title, skills')
          .eq('creator_id', userId)
          .order('created_at', ascending: false);

      // Get user details to extract skills
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('skills_to_teach')
          .eq('id', userId)
          .single();

      setState(() {
        userWorkshops = List<Map<String, dynamic>>.from(workshopsResponse);
        if (userResponse['skills_to_teach'] != null) {
          userSkills = List<String>.from(userResponse['skills_to_teach']);
        }
        isLoadingUserDetails = false;
      });
    } catch (error) {
      setState(() {
        isLoadingUserDetails = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user details: $error')),
      );
    }
  }

  Future<void> sendEndorsement() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (selectedUser == null ||
        selectedSkillForEndorsement == null ||
        endorsementText.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() {
      isSendingEndorsement = true;
    });

    try {
      await Supabase.instance.client.from('endorsements').insert({
        'endorsed_user': selectedUser!['id'],
        'endorsed_by': user.id,
        'skill': selectedSkillForEndorsement,
        'workshop_id': selectedWorkshop?['id'],
        'text': endorsementText.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Endorsement sent successfully!")),
      );

      // Reset form
      setState(() {
        selectedUser = null;
        selectedWorkshop = null;
        selectedSkillForEndorsement = null;
        userWorkshops = [];
        userSkills = [];
        endorsementText.clear();
        userSearchController.clear();
        workshopSearchController.clear();
        skillSearchController.clear();
        // searchResults = []; // Removed clearing this to keep UI in sync
        workshopSearchResults = [];
        skillSearchResults = [];
        isSendingEndorsement = false;

        // DO NOT clear allUsers here anymore.
        // Keeping the cache allows the dialog to open instantly next time.
      });

      Navigator.pop(context);

      // Refresh all data
      await _loadData();
    } catch (error) {
      setState(() {
        isSendingEndorsement = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending endorsement: $error')),
      );
    }
  }

  Future<void> requestEndorsement(String skill) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // This would create a request for endorsement
      // Implementation depends on your specific workflow
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Endorsement request sent for $skill")),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error requesting endorsement: $error')),
      );
    }
  }

  Future<void> respondToEndorsement(int id, bool approve) async {
    try {
      await Supabase.instance.client
          .from('workshop_requests')
          .update({'status': approve ? 'approved' : 'declined'}).eq('id', id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(approve ? "Endorsement approved!" : "Endorsement declined."),
        ),
      );

      _loadData(); // Refresh the data
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error responding to endorsement: $error')),
      );
    }
  }

  Color getLevelColor(String level) {
    switch (level) {
      case "Expert":
        return Colors.amber;
      case "Advanced":
        return Colors.blue;
      case "Intermediate":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Endorsements"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // In the build method, inside AppBar actions:
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Give Endorsement",
            onPressed: () async {
              // Ensure data is loaded before opening the dialog
              await _loadAllUsers();
              if (mounted) {
                _showGiveEndorsementDialog();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: Theme.of(context).colorScheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: true,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(
                                  icon: Icon(Icons.thumb_up_alt_outlined),
                                  text: "Received"),
                              Tab(
                                  icon: Icon(Icons.person_outline),
                                  text: "Given"),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // --- TAB 1: Received ---
                                ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    if (pendingEndorsements.isNotEmpty)
                                      Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(Icons.workspace_premium,
                                                      color: Colors.amber),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    "Pending Requests",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              ...pendingEndorsements
                                                  .map((req) => Container(
                                                        margin: const EdgeInsets
                                                            .only(bottom: 12),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(12),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.amber
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            CircleAvatar(
                                                              backgroundImage:
                                                                  NetworkImage(
                                                                      req['requester']
                                                                              [
                                                                              'avatar_url'] ??
                                                                          ''),
                                                              child: req['requester']
                                                                          [
                                                                          'avatar_url'] ==
                                                                      null
                                                                  ? Text(req[
                                                                          'requester']
                                                                      [
                                                                      'name'][0])
                                                                  : null,
                                                            ),
                                                            const SizedBox(
                                                                width: 8),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                      req['requester']
                                                                          [
                                                                          'name'],
                                                                      style: const TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold)),
                                                                  Text(
                                                                      "Requesting endorsement for ${req['workshop']['skills']}"),
                                                                  Text(
                                                                    "Workshop: ${req['workshop']['title']}",
                                                                    style: theme
                                                                        .textTheme
                                                                        .bodySmall,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            Column(
                                                              children: [
                                                                ElevatedButton(
                                                                  onPressed: () =>
                                                                      respondToEndorsement(
                                                                          req['id'],
                                                                          true),
                                                                  child: const Text(
                                                                      "Approve"),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      respondToEndorsement(
                                                                          req['id'],
                                                                          false),
                                                                  child: const Text(
                                                                      "Decline"),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      )),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 16),

                                    // My Skills
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                                "My Skills & Endorsements",
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 12),
                                            ...mySkills.map((s) => Card(
                                                  margin: const EdgeInsets.only(
                                                      bottom: 12),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Text(s['name'],
                                                                    style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold)),
                                                                const SizedBox(
                                                                    width: 8),
                                                                Chip(
                                                                  label: Text(s[
                                                                      'level']),
                                                                  backgroundColor:
                                                                      getLevelColor(
                                                                          s['level']),
                                                                  labelStyle:
                                                                      const TextStyle(
                                                                          color:
                                                                              Colors.white),
                                                                ),
                                                              ],
                                                            ),
                                                            Row(
                                                              children: [
                                                                const Icon(
                                                                    Icons
                                                                        .thumb_up,
                                                                    color: Colors
                                                                        .blue,
                                                                    size: 18),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Text(
                                                                    "${s['endorsements']}"),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        TextButton(
                                                          onPressed: () =>
                                                              requestEndorsement(
                                                                  s['name']),
                                                          child: const Text(
                                                              "Request More"),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Endorsements Received
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                                "Recent Endorsements Received",
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 12),
                                            ...endorsementsReceived.map((e) =>
                                                ListTile(
                                                  leading: CircleAvatar(
                                                    backgroundImage: NetworkImage(
                                                        e['endorsed_by'][
                                                                'avatar_url'] ??
                                                            ''),
                                                    child: e['endorsed_by'][
                                                                'avatar_url'] ==
                                                            null
                                                        ? Text(e['endorsed_by']
                                                            ['name'][0])
                                                        : null,
                                                  ),
                                                  title: Text(
                                                      "${e['endorsed_by']['name']} endorsed you for ${e['skill']}"),
                                                  subtitle: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      if (e['text'] != null)
                                                        Text("\"${e['text']}\"",
                                                            style: const TextStyle(
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic)),
                                                      Text(
                                                        DateTime.parse(
                                                                e['created_at'])
                                                            .toString()
                                                            .substring(0, 10),
                                                        style: theme.textTheme
                                                            .bodySmall,
                                                      ),
                                                    ],
                                                  ),
                                                )),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // --- TAB 2: Given ---
                                ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: endorsementsGiven.map((e) {
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: NetworkImage(
                                              e['endorsed_user']
                                                      ['avatar_url'] ??
                                                  ''),
                                          child: e['endorsed_user']
                                                      ['avatar_url'] ==
                                                  null
                                              ? Text(
                                                  e['endorsed_user']['name'][0])
                                              : null,
                                        ),
                                        title: Text(
                                            "You endorsed ${e['endorsed_user']['name']} for ${e['skill']}"),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (e['workshops'] != null)
                                              Text(
                                                  "Workshop: ${e['workshops']['title']}",
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            if (e['text'] != null)
                                              Text("\"${e['text']}\"",
                                                  style: const TextStyle(
                                                      fontStyle:
                                                          FontStyle.italic)),
                                            Text(
                                              DateTime.parse(e['created_at'])
                                                  .toString()
                                                  .substring(0, 10),
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGiveEndorsementDialog() {
    // We don't need to call _loadAllUsers here anymore because
    // we are awaiting it in the button onPressed before calling this.

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Give Endorsement"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User search
                  const Text("Select User",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: userSearchController,
                    decoration: InputDecoration(
                      labelText: "Search users...",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_search),
                      suffixIcon: userSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                userSearchController.clear();
                                setDialogState(() {
                                  searchResults =
                                      List.from(allUsers); // Reset to all users
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      // Real-time filtering logic inside the dialog
                      _searchTimer?.cancel();
                      _searchTimer =
                          Timer(const Duration(milliseconds: 200), () {
                        if (value.isEmpty) {
                          setDialogState(() {
                            searchResults = List.from(allUsers);
                          });
                          return;
                        }

                        final filteredUsers = allUsers.where((user) {
                          final name =
                              user['name']?.toString().toLowerCase() ?? '';
                          final searchLower = value.toLowerCase();
                          return name.contains(searchLower);
                        }).toList();

                        setDialogState(() {
                          searchResults = filteredUsers;
                        });
                      });
                    },
                    onTap: () {
                      // Show all users when tapped if empty
                      if (userSearchController.text.isEmpty) {
                        setDialogState(() {
                          searchResults = List.from(allUsers);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // User List
                  if (isLoadingAllUsers)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (searchResults.isNotEmpty)
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final user = searchResults[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  NetworkImage(user['avatar_url'] ?? ''),
                              child: user['avatar_url'] == null
                                  ? Text(user['name'][0])
                                  : null,
                            ),
                            title: Text(user['name']),
                            subtitle: user['skills_to_teach'] != null &&
                                    user['skills_to_teach'].isNotEmpty
                                ? Text(
                                    "Teaches: ${user['skills_to_teach'].join(', ')}")
                                : null,
                            onTap: () async {
                              setDialogState(() {
                                selectedUser = user;
                                userSearchController.text = user['name'];
                                searchResults = []; // Hide list after selection
                                isLoadingUserDetails = true;
                              });

                              // Load details
                              await _loadUserDetails(user['id']);

                              // Force rebuild to show loaded details
                              if (mounted) {
                                setDialogState(() {
                                  isLoadingUserDetails = false;
                                });
                              }
                            },
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(child: Text("No users found")),
                    ),

                  // Selected User Details
                  if (selectedUser != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundImage: NetworkImage(
                                    selectedUser!['avatar_url'] ?? ''),
                                child: selectedUser!['avatar_url'] == null
                                    ? Text(selectedUser!['name'][0])
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Selected: ${selectedUser!['name']}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setDialogState(() {
                                    selectedUser = null;
                                    userWorkshops = [];
                                    userSkills = [];
                                    userSearchController.clear();
                                    searchResults = List.from(allUsers);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        if (isLoadingUserDetails)
                          const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator()))
                        else ...[
                          if (userWorkshops.isNotEmpty) ...[
                            const Text("Workshops Conducted",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: userWorkshops.length,
                                itemBuilder: (context, index) {
                                  final workshop = userWorkshops[index];
                                  return Container(
                                    width: 150,
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(workshop['title'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        if (workshop['skills'] != null)
                                          Wrap(
                                            spacing: 4,
                                            children: (workshop['skills']
                                                    as List)
                                                .take(2)
                                                .map((skill) => Chip(
                                                    label: Text(skill,
                                                        style: const TextStyle(
                                                            fontSize: 10)),
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    visualDensity:
                                                        VisualDensity.compact))
                                                .toList(),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (userSkills.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text("Skills They Teach",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: userSkills
                                  .map((skill) => Chip(
                                      label: Text(skill),
                                      backgroundColor:
                                          Colors.green.withOpacity(0.1)))
                                  .toList(),
                            ),
                          ],
                        ],
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Workshop Search (Similar pattern for search results)
                  const Text("Search Workshop (Optional)",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: workshopSearchController,
                    decoration: InputDecoration(
                      labelText: "Workshop title",
                      hintText: "Search for a workshop...",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: workshopSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                workshopSearchController.clear();
                                setDialogState(() {
                                  workshopSearchResults = [];
                                });
                              })
                          : null,
                    ),
                    onChanged: (value) {
                      _onWorkshopSearchChanged(value);
                      // Manually trigger dialog update for results since _onWorkshopSearchChanged uses class setState
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  if (workshopSearchResults.isNotEmpty)
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        itemCount: workshopSearchResults.length,
                        itemBuilder: (context, index) {
                          final workshop = workshopSearchResults[index];
                          return ListTile(
                            title: Text(workshop['title']),
                            subtitle:
                                Text("By: ${workshop['creator']['name']}"),
                            onTap: () {
                              setDialogState(() {
                                selectedWorkshop = workshop;
                                workshopSearchController.text =
                                    workshop['title'];
                                workshopSearchResults = [];
                              });
                            },
                          );
                        },
                      ),
                    ),

                  if (selectedWorkshop != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.workspaces, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  "Selected: ${selectedWorkshop!['title']}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))),
                          IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setDialogState(() {
                                  selectedWorkshop = null;
                                  workshopSearchController.clear();
                                });
                              }),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Skill Search
                  const Text("Search Skill",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: skillSearchController,
                    decoration: InputDecoration(
                      labelText: "Skill name",
                      hintText: "Search for a skill...",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.psychology),
                      suffixIcon: skillSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                skillSearchController.clear();
                                setDialogState(() {
                                  skillSearchResults = [];
                                });
                              })
                          : null,
                    ),
                    onChanged: (value) {
                      _onSkillSearchChanged(value);
                      setDialogState(() {}); // Update UI for search results
                    },
                  ),
                  const SizedBox(height: 8),
                  if (skillSearchResults.isNotEmpty)
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        itemCount: skillSearchResults.length,
                        itemBuilder: (context, index) {
                          final skill = skillSearchResults[index];
                          return ListTile(
                            title: Text(skill['name']),
                            onTap: () {
                              setDialogState(() {
                                selectedSkillForEndorsement = skill['name'];
                                skillSearchController.text = skill['name'];
                                skillSearchResults = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                  if (selectedSkillForEndorsement != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.psychology, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  "Selected: $selectedSkillForEndorsement",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))),
                          IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setDialogState(() {
                                  selectedSkillForEndorsement = null;
                                  skillSearchController.clear();
                                });
                              }),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Endorsement text
                  const Text("Endorsement Message",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: endorsementText,
                    decoration: const InputDecoration(
                      labelText: "Your endorsement",
                      hintText: "Write your endorsement...",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isSendingEndorsement ? null : sendEndorsement,
              child: isSendingEndorsement
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Send"),
            ),
          ],
        ),
      ),
    );
  }
}
