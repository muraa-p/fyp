import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skillx/screens/user_search_screen.dart';
import 'package:skillx/screens/workshop_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = "All";

  List<Map<String, dynamic>> _allWorkshops = [];
  List<Map<String, dynamic>> _filteredWorkshops = [];
  bool _isLoading = true;

  final List<String> _categories = [
    "All",
    "Programming",
    "Design",
    "Marketing",
    "Soft Skills",
    "Music",
    "Languages",
    "Teach4Learn"
  ];

  final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;

  // User profile data for matching
  List<String> _userSkillsToLearn = [];
  List<String> _userSkillsToTeach = [];

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserProfile();
    _fetchWorkshops();
  }

  Future<void> _fetchCurrentUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('skills_to_learn, skills_to_teach')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _userSkillsToLearn = List<String>.from(response['skills_to_learn'] ?? []);
          _userSkillsToTeach = List<String>.from(response['skills_to_teach'] ?? []);
        });
      }
    } catch (e) {
      // Silent fail – user may not have profile skills yet
      if (mounted) {
        setState(() {
          _userSkillsToLearn = [];
          _userSkillsToTeach = [];
        });
      }
    }
  }

  Future<void> _fetchWorkshops() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('workshops')
          .select('''
            *,
            users!workshops_creator_id_fkey (
              name
            )
          ''')
          .order('created_at', ascending: false);

      final processedData = data.map((workshop) {
        final matchPercentage = _calculateMatchPercentage(workshop);

        return {
          ...workshop,
          'instructor': workshop['users']?['name'] ?? 'Unknown Instructor',
          'participants': '0/${workshop['max_participants'] ?? 0}',
          'match_percentage': matchPercentage,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _allWorkshops = processedData;
          _filteredWorkshops = processedData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching workshops: $e')),
        );
      }
    }
  }

  double _calculateMatchPercentage(Map<String, dynamic> workshop) {
    // If user has no skills set, give neutral score
    if (_userSkillsToLearn.isEmpty && _userSkillsToTeach.isEmpty) {
      return 50.0;
    }

    double score = 0.0;

    final String category = workshop['category'] ?? '';
    final String difficulty = workshop['difficulty'] ?? 'Beginner';
    final List<String> tags = List<String>.from(workshop['tags'] ?? []);
    final List<String> outcomes = List<String>.from(workshop['outcomes'] ?? []);
    final List<String> prerequisites = List<String>.from(workshop['prerequisites'] ?? []);
    final String skillRequested = (workshop['skill_requested'] ?? '').toString().toLowerCase();
    final String skillOffered = (workshop['skill_offered'] ?? '').toString().toLowerCase();
    final String type = workshop['type'] ?? 'Free Workshop';

    // Helper: case-insensitive partial match count
    int overlapCount(List<String> userList, List<String> workshopList) {
      if (userList.isEmpty || workshopList.isEmpty) return 0;
      final lowerUser = userList.map((s) => s.toLowerCase()).toSet();
      final lowerWorkshop = workshopList.map((s) => s.toLowerCase()).toSet();
      return lowerUser.intersection(lowerWorkshop).length;
    }

    bool userCanTeachRequested() {
      if (skillRequested.isEmpty) return false;
      return _userSkillsToTeach.any((s) =>
      s.toLowerCase().contains(skillRequested) ||
          skillRequested.contains(s.toLowerCase()));
    }

    // 1. Category match (20%)
    if (_selectedCategory == "All" || category == _selectedCategory) {
      score += 20;
    }

    // 2. Difficulty suitability (15%)
    if (difficulty == 'Beginner' || difficulty == 'Intermediate') {
      score += 15;
    } else if (difficulty == 'Advanced') {
      score += 7.5; // Advanced is harder to match perfectly
    }

    // 3. User's desired skills match workshop content (25%)
    final learnMatchesTags = overlapCount(_userSkillsToLearn, tags);
    final learnMatchesOutcomes = overlapCount(_userSkillsToLearn, outcomes);
    final learnsOfferedSkill = _userSkillsToLearn.any((s) => skillOffered.contains(s.toLowerCase()));

    if (learnMatchesTags > 0 || learnMatchesOutcomes > 0 || learnsOfferedSkill) {
      score += 25;
    }

    // 4. Teach4Learn: Can user teach what creator wants? (20%)
    if (type == 'Teach4Learn') {
      if (userCanTeachRequested()) {
        score += 20;
      }
      // Reduce general learning importance for swaps
      score -= 10; // Adjust balance
    }

    // 5. Prerequisites roughly met via user's taught skills (10%)
    if (prerequisites.isEmpty) {
      score += 10;
    } else {
      final met = overlapCount(_userSkillsToTeach, prerequisites);
      score += (met / prerequisites.length).clamp(0.0, 1.0) * 10;
    }

    // 6. Tag bonus (10%)
    if (learnMatchesTags > 0) {
      score += 10;
    }

    return score.clamp(0.0, 100.0);
  }

  void _filterWorkshops() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredWorkshops = _allWorkshops.where((ws) {
        final matchesSearch = ws["title"].toString().toLowerCase().contains(query);
        final matchesCategory = _selectedCategory == "All" || ws["category"] == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();

      // Sort by match percentage when no search query (recommended view)
      if (query.isEmpty) {
        _filteredWorkshops.sort((a, b) =>
            (b['match_percentage'] ?? 0).compareTo(a['match_percentage'] ?? 0));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Explore Workshops"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSearchScreen()),
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
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Search workshops...",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => _filterWorkshops(),
            ),
          ),

          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = _selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = category;
                    });
                    _filterWorkshops();
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredWorkshops.isEmpty
                ? Center(
              child: Text(
                "No workshops found",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredWorkshops.length,
              itemBuilder: (context, index) {
                final ws = _filteredWorkshops[index];
                return _WorkshopCard(workshop: ws, currentUserId: currentUserId);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkshopCard extends StatelessWidget {
  final Map<String, dynamic> workshop;
  final String? currentUserId;

  const _WorkshopCard({required this.workshop, this.currentUserId});

  // Extract reasons for the match – we'll build this dynamically
  List<String> _getMatchReasons(BuildContext context, double matchPercentage) {
    final List<String> reasons = [];

    final String category = workshop['category'] ?? '';
    final String difficulty = workshop['difficulty'] ?? 'Beginner';
    final List<String> tags = List<String>.from(workshop['tags'] ?? []);
    final List<String> outcomes = List<String>.from(workshop['outcomes'] ?? []);
    final String skillRequested = (workshop['skill_requested'] ?? '').toString();
    final String skillOffered = (workshop['skill_offered'] ?? '').toString();
    final String type = workshop['type'] ?? 'Free Workshop';

    // You'll need access to user skills – we pass them via a parent lookup or context
    // But since this is a stateless card, we'll recompute lightly here (safe since small data)
    // Alternatively, you can pass user skills as parameters if preferred

    // For simplicity, we'll describe generically – but to make it accurate, we need user skills.
    // Best: move the full _calculateMatchPercentage logic here with user skills injected.
    // But to avoid duplication, I'll show a clean way below.

    if (_selectedCategoryFromContext(context) == "All" || category == _selectedCategoryFromContext(context)) {
      reasons.add("✔ Matches your selected category ($category)");
    }

    if (difficulty == 'Beginner' || difficulty == 'Intermediate') {
      reasons.add("✔ Suitable difficulty level ($difficulty)");
    } else if (difficulty == 'Advanced') {
      reasons.add("ℹ Advanced level – good if you're experienced");
    }

    if (tags.isNotEmpty) {
      final tagMatches = tags.where((t) =>
          _userSkillsToLearnFromContext(context).any((s) => s.toLowerCase().contains(t.toLowerCase()) || t.toLowerCase().contains(s.toLowerCase()))
      );
      if (tagMatches.isNotEmpty) {
        reasons.add("✔ Tags match your interests: ${tagMatches.take(3).join(", ")}${tagMatches.length > 3 ? "..." : ""}");
      }
    }

    if (outcomes.isNotEmpty) {
      final outcomeMatches = outcomes.where((o) =>
          _userSkillsToLearnFromContext(context).any((s) => o.toLowerCase().contains(s.toLowerCase()))
      );
      if (outcomeMatches.isNotEmpty) {
        reasons.add("✔ You'll learn skills you want: ${outcomeMatches.take(2).join(", ")}${outcomeMatches.length > 2 ? "..." : ""}");
      }
    }

    if (type == 'Teach4Learn') {
      if (skillRequested.isNotEmpty &&
          _userSkillsToTeachFromContext(context).any((s) =>
          s.toLowerCase().contains(skillRequested.toLowerCase()) ||
              skillRequested.toLowerCase().contains(s.toLowerCase()))) {
        reasons.add("✔ You can teach the skill they're looking for: $skillRequested");
      } else {
        reasons.add("ℹ Teach4Learn swap – check if you can offer $skillRequested");
      }
    }

    if ((workshop['prerequisites'] as List?)?.isEmpty ?? true) {
      reasons.add("✔ No prerequisites required");
    }

    return reasons;
  }

  // Temporary helpers – we'll fix this properly below
  String _selectedCategoryFromContext(BuildContext context) {
    return context.findAncestorStateOfType<_SearchScreenState>()?._selectedCategory ?? "All";
  }

  List<String> _userSkillsToLearnFromContext(BuildContext context) {
    return context.findAncestorStateOfType<_SearchScreenState>()?._userSkillsToLearn ?? [];
  }

  List<String> _userSkillsToTeachFromContext(BuildContext context) {
    return context.findAncestorStateOfType<_SearchScreenState>()?._userSkillsToTeach ?? [];
  }

  void _showMatchDetails(BuildContext context, double matchPercentage) {
    final reasons = _getMatchReasons(context, matchPercentage);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.purple),
            const SizedBox(width: 8),
            Text("Match Details: ${matchPercentage.toStringAsFixed(0)}%"),
          ],
        ),
        content: reasons.isEmpty
            ? const Text("No specific matches detected yet. Add skills to your profile for better recommendations!")
            : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: reasons
              .map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(r, style: const TextStyle(fontSize: 15)),
          ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double? matchPercentage = workshop['match_percentage'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WorkshopDetailScreen(workshop: workshop)),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.network(
                    workshop["image_url"] ?? "https://via.placeholder.com/160",
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(child: Icon(Icons.broken_image, size: 40)),
                    ),
                  ),
                ),

                if (workshop["creator_id"] == currentUserId)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Your Workshop",
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ),

                Positioned(
                  top: 12,
                  right: 12,
                  child: Chip(
                    label: Text(workshop["category"] ?? "General"),
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.8),
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),

                // Clickable Match Badge
                if (matchPercentage != null && matchPercentage > 20)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: GestureDetector(
                      onTap: () => _showMatchDetails(context, matchPercentage),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              "Match: ${matchPercentage.toStringAsFixed(0)}%",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.info_outline, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workshop["title"],
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text("${workshop["rating"] ?? 0.0}", style: theme.textTheme.bodySmall),
                      const SizedBox(width: 12),
                      const Icon(Icons.group, size: 16),
                      const SizedBox(width: 4),
                      Text("${workshop["participants"]}", style: theme.textTheme.bodySmall),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      Text("${workshop["duration"]}", style: theme.textTheme.bodySmall),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                        child: Text(
                          workshop["instructor"]?.isNotEmpty == true
                              ? workshop["instructor"][0].toUpperCase()
                              : 'U',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Instructor: ${workshop["instructor"]}",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}