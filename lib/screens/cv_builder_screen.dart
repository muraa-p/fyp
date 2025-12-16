import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../components/custom_button.dart';
import '../main.dart';

class CVBuilderScreen extends StatefulWidget {
  final Function(String, {Map<String, dynamic>? data})? onNavigate;

  const CVBuilderScreen({super.key, this.onNavigate});

  @override
  State<CVBuilderScreen> createState() => _CVBuilderScreenState();
}

class _CVBuilderScreenState extends State<CVBuilderScreen>
    with SingleTickerProviderStateMixin {
  bool isLinkedInConnected = false;
  late TabController _tabController;

  // DB-backed data
  bool _isLoading = true;
  int completenessScore = 0;
  List<String> suggestions = [];
  List<Map<String, dynamic>> achievements = [];
  List<Map<String, dynamic>> skills = [];
  List<Map<String, dynamic>> testimonials = [];

  // Add this to store workshops taught by the user
  List<Map<String, dynamic>> taughtWorkshops = [];

  // Quick stats
  int workshopsCompleted = 0;
  int workshopsTaught = 0;
  int badgesEarned = 0;
  double averageRating = 0.0;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = supabase.auth.currentSession?.user.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch user profile
      final userRes = await supabase
          .from('users')
          .select(
          'name,phone,bio,website,skills_to_teach,avatar_url,xp,level')
          .eq('id', userId)
          .single();

      final user = userRes;

      // 2. Calculate completeness & suggestions
      _calculateCompletenessAndSuggestions(user);

      // 3. Fetch gamification data
      final gamificationRes = await supabase
          .rpc('get_user_gamification_data', params: {'current_user_id': userId})
          .single();

      final gamification = gamificationRes;
      badgesEarned = (gamification['badges_earned'] as num).toInt();

      // 4. Workshops taught - Modified to fetch more fields
      final taughtWorkshopsRes = await supabase
          .from('workshops')
          .select('id, title, date, rating, skills, category, duration, difficulty')
          .eq('creator_id', userId);

      // Store the workshops in state
      taughtWorkshops = taughtWorkshopsRes;
      workshopsTaught = taughtWorkshopsRes.length;

      // 5. Average rating
      if (workshopsTaught > 0) {
        double total = 0;
        int count = 0;
        for (var w in taughtWorkshopsRes) {
          if (w['rating'] is num && (w['rating'] as num) > 0) {
            total += (w['rating'] as num).toDouble();
            count++;
          }
        }
        averageRating = count > 0 ? total / count : 0.0;
      } else {
        averageRating = 0.0;
      }

      // 6. Workshops completed
      final completedCountResult = await supabase
          .from('workshop_enrollments')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'completed');

      workshopsCompleted = completedCountResult.length;

      // 7. Achievements (earned badges)
      final badgesJson = gamification['user_badges_data'] as List?;
      achievements = (badgesJson ?? [])
          .where((b) => b['earned'] == true)
          .map((b) => {
        'title': b['name'],
        'desc': b['description'],
        'icon': b['icon'],
        'earned': (b['earned_at'] as String?)?.split('T')[0] ?? 'N/A',
      })
          .toList();

      // 8. Skills: endorsements + taught
      final endorsementsRes = await supabase
          .from('endorsements')
          .select('skill')
          .eq('endorsed_user', userId);

      final endorsementCounts = <String, int>{};
      for (var e in endorsementsRes) {
        final skill = e['skill'] as String?;
        if (skill != null) {
          endorsementCounts[skill] = (endorsementCounts[skill] ?? 0) + 1;
        }
      }

      final taughtSkills = <String>{};
      for (var w in taughtWorkshopsRes) {
        final skillsList = w['skills'] as List?;
        if (skillsList != null) {
          taughtSkills.addAll(skillsList.cast<String>());
        }
      }

      final allSkills = <String>{...taughtSkills, ...endorsementCounts.keys};
      skills = allSkills.map((skillName) {
        int endorsements = endorsementCounts[skillName] ?? 0;
        bool isTaught = taughtSkills.contains(skillName);

        String level;
        if (endorsements >= 10) {
          level = "Expert";
        } else if (endorsements >= 5) {
          level = "Advanced";
        } else {
          level = "Intermediate";
        }

        return {
          "name": skillName,
          "level": level,
          "endorsements": endorsements,
          "taught": isTaught ? 1 : 0,
          "attended": workshopsCompleted,
          "certs": <String>[],
          "projects": <String>[],
        };
      }).toList();

      // 9. Testimonials & Reviews (IMPROVED & COMPATIBLE)
      testimonials = [];
      if (taughtWorkshopsRes.isNotEmpty) {
        // Get a list of IDs for workshops taught by the user
        final taughtWorkshopIds = taughtWorkshopsRes.map((w) => w['id'] as String).toList();

        // Fetch ratings only for those specific workshops
        final ratingsRes = await supabase
            .from('workshop_ratings')
            .select('rating, review, user_id, workshop_id')
            .not('review', 'is', null)
            .not('review', 'eq', '')
        // CORRECTED: Use .filter() for older library versions
            .filter('workshop_id', 'in', taughtWorkshopIds)
            .limit(5);

        if (ratingsRes.isNotEmpty) {
          // Get all unique reviewer IDs to fetch their names in one query
          final reviewerIds = ratingsRes.map((r) => r['user_id'] as String).toSet().toList();
          final authorsRes = await supabase
              .from('users')
              .select('id, name')
          // CORRECTED: Use .filter() here as well
              .filter('id', 'in', reviewerIds);
          final authorsMap = {for (var a in authorsRes) a['id'] as String: a['name'] as String?};

          // Create a map for quick lookup of workshop skills
          final workshopSkillsMap = {
            for (var w in taughtWorkshopsRes) w['id'] as String: w['skills'] as List?
          };

          testimonials = ratingsRes.map((r) {
            final skillList = workshopSkillsMap[r['workshop_id']];
            final skill = (skillList?.isNotEmpty == true) ? skillList![0] : "General";

            return {
              "author": authorsMap[r['user_id']] ?? "Anonymous",
              "role": "Workshop Participant",
              "text": r['review'],
              "rating": r['rating'],
              "skill": skill,
            };
          }).toList();
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, st) {
      debugPrint('Error loading CV: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load CV: ${e.toString()}")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateCompletenessAndSuggestions(Map<String, dynamic> user) {
    int filled = 0;
    int total = 6;

    List<String> missing = [];

    final name = user['name'] as String?;
    if (name != null && name.isNotEmpty) {
      filled++;
    } else {
      missing.add("Full name");
    }

    final bio = user['bio'] as String?;
    if (bio != null && bio.isNotEmpty) {
      filled++;
    } else {
      missing.add("Bio");
    }

    final phone = user['phone'] as String?;
    if (phone != null && phone.isNotEmpty) {
      filled++;
    } else {
      missing.add("Phone");
    }

    final website = user['website'] as String?;
    if (website != null && website.isNotEmpty) {
      filled++;
    } else {
      missing.add("Website");
    }

    final skillsToTeach = user['skills_to_teach'] as List?;
    if (skillsToTeach != null && skillsToTeach.isNotEmpty) {
      filled++;
    } else {
      missing.add("Skills to teach");
    }

    final avatarUrl = user['avatar_url'] as String?;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      filled++;
    } else {
      missing.add("Profile photo");
    }

    completenessScore = (filled * 100) ~/ total;
    suggestions = missing.map((m) => "Add $m").toList();
    if (suggestions.isEmpty) {
      suggestions = ["Great job! Your profile is nearly complete."];
    }
  }

  void connectLinkedIn() {
    setState(() {
      isLinkedInConnected = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("LinkedIn account connected successfully")),
    );
  }

  void addToLinkedInProfile(String item) {
    if (!isLinkedInConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please connect LinkedIn first")),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$item added to LinkedIn profile")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("CV Builder")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("CV Builder"),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onNavigate != null) {
              widget.onNavigate!("profile");
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("CV exported to PDF!")),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.linked_camera_outlined),
            onPressed: () => addToLinkedInProfile("CV"),
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(153),
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: "Overview"),
              Tab(text: "Skills"),
              Tab(text: "Experience"),
              Tab(text: "LinkedIn"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(context),
                _buildSkillsTab(context),
                _buildExperienceTab(context), // Removed appState.createdWorkshops parameter
                _buildLinkedInTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("Profile Completeness",
                      style: theme.textTheme.titleMedium),
                  Text("$completenessScore%"),
                ]),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: completenessScore / 100,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text("Suggestions:",
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ...suggestions.map((s) => Row(
                  children: [
                    Icon(Icons.circle,
                        size: 6, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(s, style: theme.textTheme.bodyMedium),
                  ],
                )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildQuickStats(context),
        const SizedBox(height: 12),
        _buildAchievements(context),
        const SizedBox(height: 12),
        _buildCVPreview(context),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final theme = Theme.of(context);
    final stats = [
      {
        "icon": "🎓",
        "label": "Workshops Completed",
        "value": workshopsCompleted.toString(),
      },
      {
        "icon": "👨‍🏫",
        "label": "Workshops Taught",
        "value": workshopsTaught.toString(),
      },
      {
        "icon": "🏆",
        "label": "Badges Earned",
        "value": badgesEarned.toString(),
      },
      {
        "icon": "⭐",
        "label": "Average Rating",
        "value": averageRating > 0 ? averageRating.toStringAsFixed(1) : "N/A",
      },
    ];

    return GridView.builder(
      itemCount: stats.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
      itemBuilder: (context, i) {
        final item = stats[i];
        return Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item["icon"]!, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  item["value"]!,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  item["label"]!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(179),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAchievements(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Recent Achievements", style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...achievements.map((a) => ListTile(
            leading: Text(a["icon"], style: const TextStyle(fontSize: 24)),
            title: Text(a["title"], style: theme.textTheme.bodyLarge),
            subtitle: Text("${a["desc"]}\nEarned: ${a["earned"]}",
                style: theme.textTheme.bodySmall),
            trailing: IconButton(
              icon: const Icon(Icons.link),
              color: theme.colorScheme.primary,
              onPressed: () => addToLinkedInProfile(a["title"]),
            ),
          ))
        ]),
      ),
    );
  }

  Widget _buildCVPreview(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("CV Preview", style: theme.textTheme.titleMedium),
            TextButton(
              onPressed: () {},
              child: Text("View Full",
                  style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Your CV is dynamically generated from your real activity on SkillX.",
              style: theme.textTheme.bodyMedium,
            ),
          )
        ]),
      ),
    );
  }

  Widget _buildSkillsTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...skills.map((s) => Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${s["name"]} (${s["level"]})",
                            style: theme.textTheme.titleMedium),
                        IconButton(
                          onPressed: () => addToLinkedInProfile(s["name"]),
                          icon: const Icon(Icons.link),
                          color: theme.colorScheme.primary,
                        ),
                      ]),
                  const SizedBox(height: 6),
                  Text(
                    "Endorsements: ${s["endorsements"]} | Taught: ${s["taught"]} | Attended: ${s["attended"]}",
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: (s["certs"] as List)
                        .map((c) => Chip(
                      label: Text(c),
                      backgroundColor:
                      theme.colorScheme.surface.withAlpha(128),
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: (s["projects"] as List)
                        .map((p) => Chip(
                      label: Text(p),
                      backgroundColor:
                      theme.colorScheme.surface.withAlpha(128),
                    ))
                        .toList(),
                  ),
                ]),
          ),
        )),
        const SizedBox(height: 12),
        CustomButton(label: "Add New Skill", onPressed: () {}),
      ],
    );
  }

  Widget _buildExperienceTab(BuildContext context) { // Modified to use taughtWorkshops state
    final theme = Theme.of(context);
    final hasCreated = taughtWorkshops.isNotEmpty; // Use taughtWorkshops instead of created

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Workshop Experience Timeline",
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (!hasCreated)
                    const Text("No workshops created yet.",
                        style: TextStyle(color: Colors.grey)),
                  ...taughtWorkshops.map((w) => ListTile( // Use taughtWorkshops instead of created
                    title: Text(w["title"] ?? "Untitled",
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      "Instructor • ${_formatDate(w["date"])} • ${w["category"] ?? "General"} • ${w["duration"] ?? "N/A"}",
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.link),
                      color: theme.colorScheme.primary,
                      onPressed: () =>
                          addToLinkedInProfile(w["title"] ?? "Workshop"),
                    ),
                  )),
                ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Testimonials & Reviews",
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (testimonials.isEmpty)
                    const Text("No reviews yet.",
                        style: TextStyle(color: Colors.grey)),
                  ...testimonials.map((t) {
                    final int rating = t["rating"] as int? ?? 0;
                    return ListTile(
                      title: Text(t["author"], style: theme.textTheme.bodyLarge),
                      subtitle: Text("\"${t["text"]}\" — ${t["skill"]}",
                          style: theme.textTheme.bodySmall),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                              5,
                                  (i) => Icon(Icons.star,
                                  size: 16,
                                  color: i < rating
                                      ? Colors.amber
                                      : theme.disabledColor))),
                    );
                  })
                ]),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkedInTab(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isLinkedInConnected
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle,
              color: theme.colorScheme.secondary, size: 64),
          const SizedBox(height: 12),
          Text("LinkedIn Connected!",
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          CustomButton(
            label: "Add All Skills to LinkedIn",
            onPressed: () => addToLinkedInProfile("All Skills"),
            isPrimary: false,
          ),
          const SizedBox(height: 8),
          CustomButton(
            label: "Share Recent Achievements",
            onPressed: () => addToLinkedInProfile("Recent Achievements"),
            isPrimary: false,
          ),
        ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.link, color: theme.colorScheme.primary, size: 64),
          const SizedBox(height: 12),
          Text("Connect LinkedIn Account",
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "Share your SkillX achievements directly to your LinkedIn profile.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          CustomButton(label: "Connect LinkedIn", onPressed: connectLinkedIn)
        ]),
      ),
    );
  }

  // Helper function to format date
  String _formatDate(dynamic date) {
    if (date == null) return 'Recently created';

    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Recently created';
    }
  }
}