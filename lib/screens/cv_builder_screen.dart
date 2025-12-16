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
          .select('skill, text, workshop_id')
          .eq('endorsed_user', userId);

      final endorsementCounts = <String, int>{};
      final endorsementDetails = <String, List<Map<String, dynamic>>>{};

      for (var e in endorsementsRes) {
        final skill = e['skill'] as String?;
        if (skill != null) {
          endorsementCounts[skill] = (endorsementCounts[skill] ?? 0) + 1;

          if (!endorsementDetails.containsKey(skill)) {
            endorsementDetails[skill] = [];
          }
          endorsementDetails[skill]!.add({
            'text': e['text'],
            'workshop_id': e['workshop_id'],
          });
        }
      }

      // 9. Get workshop ratings for evidence
      final workshopRatings = <String, List<Map<String, dynamic>>>{};
      if (taughtWorkshopsRes.isNotEmpty) {
        final taughtWorkshopIds = taughtWorkshopsRes.map((w) => w['id'] as String).toList();

        final ratingsRes = await supabase
            .from('workshop_ratings')
            .select('rating, review, user_id, workshop_id')
            .not('review', 'is', null)
            .not('review', 'eq', '')
            .filter('workshop_id', 'in', taughtWorkshopIds);

        // Get user names for reviews
        final reviewerIds = ratingsRes.map((r) => r['user_id'] as String).toSet().toList();
        final authorsRes = await supabase
            .from('users')
            .select('id, name')
            .filter('id', 'in', reviewerIds);
        final authorsMap = {for (var a in authorsRes) a['id'] as String: a['name'] as String?};

        // Organize ratings by workshop
        for (var rating in ratingsRes) {
          final workshopId = rating['workshop_id'] as String;
          if (!workshopRatings.containsKey(workshopId)) {
            workshopRatings[workshopId] = [];
          }
          workshopRatings[workshopId]!.add({
            'rating': rating['rating'],
            'review': rating['review'],
            'author': authorsMap[rating['user_id']] ?? "Anonymous",
          });
        }
      }

      // 10. Get user's skills_to_teach
      final userSkillsToTeach = user['skills_to_teach'] as List? ?? [];

      // 11. Create enhanced skills data structure
      skills = [];

      // First, add skills that user has explicitly set as skills_to_teach
      for (var skillName in userSkillsToTeach) {
        // Find workshops where this skill was taught
        final relatedWorkshops = taughtWorkshopsRes.where((w) {
          final skillsList = w['skills'] as List? ?? [];
          return skillsList.contains(skillName);
        }).toList();

        // Calculate average rating for this skill across all workshops
        double skillRating = 0.0;
        int ratingCount = 0;
        for (var workshop in relatedWorkshops) {
          if (workshop['rating'] is num && (workshop['rating'] as num) > 0) {
            skillRating += (workshop['rating'] as num).toDouble();
            ratingCount++;
          }
        }
        skillRating = ratingCount > 0 ? skillRating / ratingCount : 0.0;

        // Determine skill level based on endorsements and workshops taught
        int endorsements = endorsementCounts[skillName] ?? 0;
        int workshopsTaught = relatedWorkshops.length;

        String level;
        if (endorsements >= 10 || workshopsTaught >= 5) {
          level = "Expert";
        } else if (endorsements >= 5 || workshopsTaught >= 3) {
          level = "Advanced";
        } else if (endorsements >= 1 || workshopsTaught >= 1) {
          level = "Intermediate";
        } else {
          level = "Beginner";
        }

        // Collect evidence (reviews and endorsements)
        List<Map<String, dynamic>> evidence = [];

        // Add workshop reviews as evidence
        for (var workshop in relatedWorkshops) {
          final workshopId = workshop['id'] as String;
          if (workshopRatings.containsKey(workshopId)) {
            for (var rating in workshopRatings[workshopId]!) {
              evidence.add({
                'type': 'review',
                'workshop_title': workshop['title'],
                'text': rating['review'],
                'author': rating['author'],
                'rating': rating['rating'],
                'date': workshop['date'],
              });
            }
          }
        }

        // Add endorsements as evidence
        if (endorsementDetails.containsKey(skillName)) {
          for (var endorsement in endorsementDetails[skillName]!) {
            final workshopId = endorsement['workshop_id'] as String?;
            String workshopTitle = "General";

            if (workshopId != null) {
              final workshop = taughtWorkshopsRes.firstWhere(
                    (w) => w['id'] == workshopId,
                orElse: () => {'title': 'General'},
              );
              workshopTitle = workshop['title'] as String? ?? "General";
            }

            evidence.add({
              'type': 'endorsement',
              'workshop_title': workshopTitle,
              'text': endorsement['text'],
              'date': null,
            });
          }
        }

        // Sort evidence by date (most recent first)
        evidence.sort((a, b) {
          if (a['date'] == null && b['date'] == null) return 0;
          if (a['date'] == null) return 1;
          if (b['date'] == null) return -1;
          return DateTime.parse(b['date']).compareTo(DateTime.parse(a['date']));
        });

        skills.add({
          "name": skillName,
          "level": level,
          "endorsements": endorsements,
          "workshops": relatedWorkshops,
          "average_rating": skillRating,
          "evidence": evidence.take(5).toList(), // Limit to top 5 evidence items
        });
      }

      // Then, add skills from workshops that aren't in skills_to_teach
      final taughtSkills = <String>{};
      for (var w in taughtWorkshopsRes) {
        final skillsList = w['skills'] as List?;
        if (skillsList != null) {
          taughtSkills.addAll(skillsList.cast<String>());
        }
      }

      for (var skillName in taughtSkills) {
        if (!userSkillsToTeach.contains(skillName)) {
          // Find workshops where this skill was taught
          final relatedWorkshops = taughtWorkshopsRes.where((w) {
            final skillsList = w['skills'] as List? ?? [];
            return skillsList.contains(skillName);
          }).toList();

          // Calculate average rating for this skill across all workshops
          double skillRating = 0.0;
          int ratingCount = 0;
          for (var workshop in relatedWorkshops) {
            if (workshop['rating'] is num && (workshop['rating'] as num) > 0) {
              skillRating += (workshop['rating'] as num).toDouble();
              ratingCount++;
            }
          }
          skillRating = ratingCount > 0 ? skillRating / ratingCount : 0.0;

          // Determine skill level based on endorsements and workshops taught
          int endorsements = endorsementCounts[skillName] ?? 0;
          int workshopsTaught = relatedWorkshops.length;

          String level;
          if (endorsements >= 10 || workshopsTaught >= 5) {
            level = "Expert";
          } else if (endorsements >= 5 || workshopsTaught >= 3) {
            level = "Advanced";
          } else if (endorsements >= 1 || workshopsTaught >= 1) {
            level = "Intermediate";
          } else {
            level = "Beginner";
          }

          // Collect evidence (reviews and endorsements)
          List<Map<String, dynamic>> evidence = [];

          // Add workshop reviews as evidence
          for (var workshop in relatedWorkshops) {
            final workshopId = workshop['id'] as String;
            if (workshopRatings.containsKey(workshopId)) {
              for (var rating in workshopRatings[workshopId]!) {
                evidence.add({
                  'type': 'review',
                  'workshop_title': workshop['title'],
                  'text': rating['review'],
                  'author': rating['author'],
                  'rating': rating['rating'],
                  'date': workshop['date'],
                });
              }
            }
          }

          // Add endorsements as evidence
          if (endorsementDetails.containsKey(skillName)) {
            for (var endorsement in endorsementDetails[skillName]!) {
              final workshopId = endorsement['workshop_id'] as String?;
              String workshopTitle = "General";

              if (workshopId != null) {
                final workshop = taughtWorkshopsRes.firstWhere(
                      (w) => w['id'] == workshopId,
                  orElse: () => {'title': 'General'},
                );
                workshopTitle = workshop['title'] as String? ?? "General";
              }

              evidence.add({
                'type': 'endorsement',
                'workshop_title': workshopTitle,
                'text': endorsement['text'],
                'date': null,
              });
            }
          }

          // Sort evidence by date (most recent first)
          evidence.sort((a, b) {
            if (a['date'] == null && b['date'] == null) return 0;
            if (a['date'] == null) return 1;
            if (b['date'] == null) return -1;
            return DateTime.parse(b['date']).compareTo(DateTime.parse(a['date']));
          });

          skills.add({
            "name": skillName,
            "level": level,
            "endorsements": endorsements,
            "workshops": relatedWorkshops,
            "average_rating": skillRating,
            "evidence": evidence.take(5).toList(), // Limit to top 5 evidence items
            "from_workshop": true, // Mark as derived from workshop
          });
        }
      }

      // 12. Testimonials & Reviews (IMPROVED & COMPATIBLE)
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
        if (skills.isEmpty)
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.school_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurface.withAlpha(128)),
                  const SizedBox(height: 12),
                  Text(
                    "No skills added yet",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Add skills you've taught or learned through workshops",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(128),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    label: "Add Your First Skill",
                    onPressed: () => _showAddSkillDialog(context),
                  ),
                ],
              ),
            ),
          )
        else
          ...skills.map((s) => Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${s["name"]} (${s["level"]})",
                        style: theme.textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          if (s["from_workshop"] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "From Workshop",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => addToLinkedInProfile(s["name"]),
                            icon: const Icon(Icons.link),
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        "Endorsements: ${s["endorsements"]}",
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        "Workshops: ${s["workshops"].length}",
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      if (s["average_rating"] > 0)
                        Row(
                          children: [
                            Text(
                              "Rating: ",
                              style: theme.textTheme.bodySmall,
                            ),
                            ...List.generate(
                              5,
                                  (i) => Icon(
                                Icons.star,
                                size: 14,
                                color: i < s["average_rating"]
                                    ? Colors.amber
                                    : theme.disabledColor,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // Show related workshops
                  if (s["workshops"].isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Related Workshops",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...s["workshops"].take(3).map((w) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${w["title"]} (${_formatDate(w["date"])})",
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    )),
                    if (s["workshops"].length > 3)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Text(
                          "+${s["workshops"].length - 3} more workshops",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],

                  // Show evidence (reviews and endorsements)
                  if (s["evidence"].isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Evidence",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...s["evidence"].map((e) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                e["type"] == "review"
                                    ? Icons.rate_review
                                    : Icons.thumb_up,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                e["type"] == "review"
                                    ? "Review from ${e["author"]}"
                                    : "Endorsement",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (e["type"] == "review" && e["rating"] != null) ...[
                                const SizedBox(width: 8),
                                ...List.generate(
                                  5,
                                      (i) => Icon(
                                    Icons.star,
                                    size: 12,
                                    color: i < e["rating"]
                                        ? Colors.amber
                                        : theme.disabledColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(width: 24),
                          Text(
                            "\"${e["text"]}\"",
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if (e["workshop_title"] != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Text(
                                "From: ${e["workshop_title"]}",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withAlpha(179),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
          )),
        const SizedBox(height: 12),
        CustomButton(
          label: "Add New Skill",
          onPressed: () => _showAddSkillDialog(context),
        ),
      ],
    );
  }

  // Add this method to show a dialog for adding a new skill
  void _showAddSkillDialog(BuildContext context) {
    final TextEditingController skillController = TextEditingController();
    final List<String> skillLevels = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];
    String selectedLevel = 'Intermediate';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Add New Skill"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: skillController,
                    decoration: const InputDecoration(
                      labelText: "Skill Name",
                      hintText: "e.g., Flutter, Public Speaking",
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Proficiency Level"),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: selectedLevel,
                    isExpanded: true,
                    items: skillLevels.map((String level) {
                      return DropdownMenuItem<String>(
                        value: level,
                        child: Text(level),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedLevel = newValue;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (skillController.text.trim().isNotEmpty) {
                      final userId = supabase.auth.currentSession?.user.id;
                      if (userId != null) {
                        try {
                          // Get current skills_to_teach
                          final currentUserRes = await supabase
                              .from('users')
                              .select('skills_to_teach')
                              .eq('id', userId)
                              .single();

                          final currentSkills = currentUserRes['skills_to_teach'] as List? ?? [];

                          // Add new skill if not already present
                          if (!currentSkills.contains(skillController.text.trim())) {
                            final updatedSkills = [...currentSkills, skillController.text.trim()];

                            // Update user's skills_to_teach
                            await supabase
                                .from('users')
                                .update({
                              'skills_to_teach': updatedSkills
                            })
                                .eq('id', userId);

                            // Refresh data
                            _loadData();

                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Skill added successfully!")),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Skill already exists")),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error adding skill: ${e.toString()}")),
                            );
                          }
                        }
                      }
                    }
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
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