import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:skillx/screens/user_search_screen.dart';
import 'package:skillx/screens/workshop_detail_screen.dart';

// We no longer need Provider or AppState
// import 'package:provider/provider.dart';
// import '../main.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = "All";

  // State to hold the fetched workshops and the filtered list
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
    "Teach4Learn" // Added Teach4Learn as a category
  ];

  // Get the current user's ID to check for "Your Workshop" badge
  final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _fetchWorkshops();
  }

  // Function to fetch workshops from Supabase
  Future<void> _fetchWorkshops() async {
    setState(() => _isLoading = true);
    try {
      // Fetch workshops and join with the users table to get the instructor's name
      final data = await Supabase.instance.client
          .from('workshops')
          .select('''
            *,
            users!workshops_creator_id_fkey (
              name
            )
          ''')
          .order('created_at', ascending: false);

      // Process the data to flatten the user object
      final processedData = data.map((workshop) {
        return {
          ...workshop,
          'instructor': workshop['users']?['name'] ?? 'Unknown Instructor',
          // The 'participants' field in the old mock data is now derived from max_participants
          'participants': '0/${workshop['max_participants'] ?? 0}',
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
        // Optionally show an error message to the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching workshops: $e')),
        );
      }
    }
  }

  // Function to filter workshops based on search and category
  void _filterWorkshops() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredWorkshops = _allWorkshops.where((ws) {
        final matchesSearch = ws["title"]
            .toString()
            .toLowerCase()
            .contains(query);
        final matchesCategory = _selectedCategory == "All" ||
            ws["category"] == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
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
                MaterialPageRoute(
                  builder: (_) => const UserSearchScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Search workshops...",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => _filterWorkshops(), // Re-filter on text change
            ),
          ),

          // Categories filter
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
                  selectedColor:
                  theme.colorScheme.primary.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = category;
                    });
                    _filterWorkshops(); // Re-filter on category change
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredWorkshops.isEmpty
                ? Center(
              child: Text(
                "No workshops found",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                  theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredWorkshops.length,
              itemBuilder: (context, index) {
                final ws = _filteredWorkshops[index];
                // Pass the currentUserId to the card
                return _WorkshopCard(workshop: ws, currentUserId: currentUserId);
              },
            ),
          ),
        ],
      ),
    );
  }
}

//
// --- WORKSHOP CARD (Updated) ---
//
class _WorkshopCard extends StatelessWidget {
  final Map<String, dynamic> workshop;
  final String? currentUserId; // Accept the current user ID

  const _WorkshopCard({required this.workshop, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkshopDetailScreen(workshop: workshop),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Workshop image, category chip & "Your Workshop" badge ---
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.network(
                    workshop["image_url"] ?? "https://via.placeholder.com/160", // Use image_url from DB
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 40),
                      ),
                    ),
                  ),
                ),

                // 🟡 Add this badge for your own workshops
                if (workshop["creator_id"] == currentUserId)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Your Workshop",
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                // Category chip
                Positioned(
                  top: 12,
                  right: 12,
                  child: Chip(
                    label: Text(workshop["category"] ?? "General"),
                    backgroundColor:
                    theme.colorScheme.primary.withOpacity(0.8),
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            // --- Details ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    workshop["title"],
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Rating, participants, duration
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text("${workshop["rating"] ?? 0.0}",
                          style: theme.textTheme.bodySmall),
                      const SizedBox(width: 12),
                      const Icon(Icons.group, size: 16),
                      const SizedBox(width: 4),
                      Text("${workshop["participants"]}",
                          style: theme.textTheme.bodySmall),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      Text("${workshop["duration"]}",
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Instructor
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.2),
                        child: Text(
                          workshop["instructor"]?.isNotEmpty == true
                              ? workshop["instructor"][0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Instructor: ${workshop["instructor"]}",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.7),
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