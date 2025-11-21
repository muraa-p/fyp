import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skillx/screens/user_search_screen.dart';
import 'package:skillx/screens/workshop_detail_screen.dart';

import '../main.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = "All";

  final List<String> _categories = [
    "All",
    "Programming",
    "Design",
    "Marketing",
    "Soft Skills",
    "Music",
    "Languages",
  ];

  final List<Map<String, dynamic>> _workshops = [
    {
      "title": "React Hooks Deep Dive",
      "instructor": "Sarah Kim",
      "rating": 4.9,
      "participants": "12/15",
      "duration": "2 hours",
      "category": "Programming",
      "image":
      "https://images.unsplash.com/photo-1618761714954-0b8cd0026356?auto=format&fit=crop&w=1080&q=80",
    },
    {
      "title": "Public Speaking Confidence",
      "instructor": "Michael Chen",
      "rating": 4.8,
      "participants": "8/10",
      "duration": "1.5 hours",
      "category": "Soft Skills",
      "image":
      "https://images.unsplash.com/photo-1603575448362-1fefdeee4389?auto=format&fit=crop&w=1080&q=80",
    },
    {
      "title": "UI/UX Design Principles",
      "instructor": "Emma Rodriguez",
      "rating": 4.9,
      "participants": "15/20",
      "duration": "3 hours",
      "category": "Design",
      "image":
      "https://images.unsplash.com/photo-1600585154526-990dced4db0d?auto=format&fit=crop&w=1080&q=80",
    },
    {
      "title": "Digital Marketing Basics",
      "instructor": "Lisa Zhang",
      "rating": 4.7,
      "participants": "10/12",
      "duration": "2 hours",
      "category": "Marketing",
      "image":
      "https://images.unsplash.com/photo-1559526324-593bc073d938?auto=format&fit=crop&w=1080&q=80",
    },

// 👇 UPDATED Teach4Learn example workshop
    {
      "type": "Teach4Learn",
      "title": "🎨 Skill Exchange: Learn Digital Illustration for Web Dev",
      "instructor": "Yasir Mohamed",
      "rating": 4.9,
      "participants": "0/1",
      "duration": "Flexible",
      "category": "Teach4Learn",
      "image":
      "https://images.unsplash.com/photo-1509099836639-18ba1795216d?auto=format&fit=crop&w=1080&q=80",

      // 🔹 About / Description
      "description":
      "I’m looking to improve my digital illustration skills — character design, composition, and coloring. "
          "In return, I can teach you Web Development fundamentals, React basics, or help you build your own website. "
          "Let’s collaborate and exchange knowledge!",

      // 🔹 Skill swap fields
      "skillRequested": "Digital Illustration",
      "skillOffered": "Web Development",

      // 🔹 Status
      "status": "open",
    },
  ];


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter workshops by search + category
    final appState = Provider.of<AppState>(context);
    final allWorkshops = [..._workshops, ...appState.createdWorkshops];

    final filtered = allWorkshops.where((ws) {
      final matchesSearch = ws["title"]
          .toString()
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
      final matchesCategory = _selectedCategory == "All"
          ? true
          : ws["category"] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();


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
              decoration: InputDecoration(
                hintText: "Search workshops...",
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
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
                    setState(() => _selectedCategory = category);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Results
          Expanded(
            child: filtered.isEmpty
                ? Center(
              child: Text(
                "No workshops found",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                  theme.colorScheme.onBackground.withOpacity(0.7),
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final ws = filtered[index];
                return _WorkshopCard(workshop: ws);
              },
            ),
          ),
        ],
      ),
    );
  }
}

//
// --- WORKSHOP CARD ---
//
class _WorkshopCard extends StatelessWidget {
  final Map<String, dynamic> workshop;
  const _WorkshopCard({required this.workshop});

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
                    workshop["image"] ?? "",
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 40),
                      ),
                    ),
                  ),
                ),

                // 🟡 Add this badge for your own workshops
                if (workshop["creatorId"] == "currentUser")
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

                // Category chip (already in your code)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Chip(
                    label: Text(workshop["category"]),
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
                      Text("${workshop["rating"]}",
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
                          workshop["instructor"][0],
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
                          color: theme.colorScheme.onBackground
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

