import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../components/custom_button.dart';
import '../main.dart';
// Import your existing HuggingFaceService
import '../services/hugging_face_service.dart'; // Adjust the path as needed
import 'dart:io'; // Added
import 'package:pdf/pdf.dart'; // Added
import 'package:pdf/widgets.dart' as pw; // Added
import 'package:printing/printing.dart'; // Added
import 'package:signin_with_linkedin/signin_with_linkedin.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For jsonEncode
import 'dart:developer' as developer;
import 'package:url_launcher/url_launcher.dart';



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
  String? linkedinAccessToken; // Store token after login

  // DB-backed data
  bool _isLoading = true;
  int completenessScore = 0;
  List<String> suggestions = [];
  List<Map<String, dynamic>> achievements = [];
  List<Map<String, dynamic>> skills = [];
  List<Map<String, dynamic>> testimonials = [];

  // Add this to store workshops taught by user
  List<Map<String, dynamic>> taughtWorkshops = [];

  // Quick stats
  int workshopsCompleted = 0;
  int workshopsTaught = 0;
  int badgesEarned = 0;
  double averageRating = 0.0;

  // User profile data
  Map<String, dynamic>? userProfile;

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

    final userRes = await supabase
        .from('users')
        .select('name,email,phone,bio,website,skills_to_teach,avatar_url,xp,level,university,major,year,location') // Removed linkedin_token
        .eq('id', userId)
        .single();

    userProfile = userRes;

// Add this AFTER userRes is fetched
    final linkedinToken = userRes['linkedin_token'] as String?;
    if (linkedinToken != null && linkedinToken.isNotEmpty) {
      setState(() {
        isLinkedInConnected = true;
        linkedinAccessToken = linkedinToken;
      });
    }

    try {
      // 1. Fetch user profile - FIXED: Added email to the select statement
      final userRes = await supabase
          .from('users')
          .select(
          'name,email,phone,bio,website,skills_to_teach,avatar_url,xp,level,university,major,year,location')
          .eq('id', userId)
          .single();

      userProfile = userRes;

      // 2. Calculate completeness & suggestions
      _calculateCompletenessAndSuggestions(userRes);

      // 3. Fetch gamification data
      final gamificationRes = await supabase
          .rpc('get_user_gamification_data', params: {'current_user_id': userId})
          .single();

      final gamification = gamificationRes;
      badgesEarned = (gamification['badges_earned'] as num).toInt();

      // 4. Workshops taught - Modified to fetch more fields
      final taughtWorkshopsRes = await supabase
          .from('workshops')
          .select('id, title, date, rating, skills, category, duration, difficulty, description')
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
      final userSkillsToTeach = userRes['skills_to_teach'] as List? ?? [];

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
        // Get a list of IDs for workshops taught by user
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


  Future<void> connectLinkedIn() async {
    try {
      final config = LinkedInConfig(
        clientId: '867905jxxemuub', // ← your real client ID
        clientSecret: 'WPL_AP1.zfWkD7CvbaHHkl8B.Sh4YMg==', // ← your real secret (testing only!)
        redirectUrl: 'https://localhost/linkedin-callback',
        scope: ['openid', 'profile', 'email'],
      );

      final linkedin = SignInWithLinkedIn(config: config);

      // Step 1: Open LinkedIn login and get authorization code
      final result = await linkedin.getAuthorizationCode(context: context);
      final String? authCode = result.$1;
      final AuthCodeError? error = result.$2;

      if (authCode != null && authCode.isNotEmpty) {
        developer.log('Got auth code, exchanging for token...');

        // Step 2: Exchange code for real access token
        final tokenResult = await linkedin.getAccessToken(authorizationCode: authCode);
        final tokenInfo = tokenResult.$1;
        final tokenError = tokenResult.$2;

        if (tokenInfo != null && tokenInfo.accessToken.isNotEmpty) {
          final tokenString = tokenInfo.accessToken;

          setState(() {
            isLinkedInConnected = true;
            linkedinAccessToken = tokenString;
          });

          // Save the REAL token
          await supabase
              .from('users')
              .update({'linkedin_token': tokenString})
              .eq('id', supabase.auth.currentUser!.id);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("LinkedIn connected successfully! 🎉")),
          );

          developer.log('Real access token saved. Posting should now work.');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Token exchange failed: ${tokenError?.toJson()}")),
          );
        }
      } else if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("LinkedIn error: ${error.toJson()}")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login cancelled")),
        );
      }
    } catch (e) {
      developer.log('LinkedIn exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection failed: $e")),
      );
    }
  }

// Replace addToLinkedInProfile() to actually post
  Future<void> addToLinkedInProfile(String item) async {
    if (!isLinkedInConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connect LinkedIn to share achievements")),
      );
      return;
    }

    // Make the message richer and more engaging
    final String fullText = """
Just leveled up my skills on SkillX! 🚀

$item

I'm building real-world experience through teaching workshops and earning endorsements.

Check out SkillX and level up too: https://your-skillx-app-link.com

#SkillX #Learning #ProfessionalDevelopment #Skills #CareerGrowth
""".trim();

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: fullText));

    // Primary: Mobile web share page — clean "Start a post" screen
    final Uri mobileShareUri = Uri.parse("https://www.linkedin.com/sharing/share-offsite/?mini=true");

    // Fallback: General feed (if above doesn't open nicely)
    final Uri feedUri = Uri.parse("https://www.linkedin.com/feed/");

    bool launched = await launchUrl(mobileShareUri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await launchUrl(feedUri, mode: LaunchMode.externalApplication);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📋 Text copied! Open LinkedIn, paste it, and post 🚀"),
        duration: Duration(seconds: 4),
      ),
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CVPreviewScreen(
                    userProfile: userProfile!,
                    skills: skills,
                    taughtWorkshops: taughtWorkshops,
                    achievements: achievements,
                    testimonials: testimonials,
                    averageRating: averageRating,
                    workshopsCompleted: workshopsCompleted,
                  ),
                ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("CV Preview", style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CVPreviewScreen(
                          userProfile: userProfile!,
                          skills: skills,
                          taughtWorkshops: taughtWorkshops,
                          achievements: achievements,
                          testimonials: testimonials,
                          averageRating: averageRating,
                          workshopsCompleted: workshopsCompleted,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    "View Full",
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
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
            ),
          ],
        ),
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
                            onPressed: () => addToLinkedInProfile("Achieved ${s["level"]} level in ${s["name"]} on SkillX!"),
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
                          const SizedBox(height: 8),
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

// CV Preview Screen
class CVPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final List<Map<String, dynamic>> skills;
  final List<Map<String, dynamic>> taughtWorkshops;
  final List<Map<String, dynamic>> achievements;
  final List<Map<String, dynamic>> testimonials;
  final double averageRating;
  final int workshopsCompleted;

  const CVPreviewScreen({
    super.key,
    required this.userProfile,
    required this.skills,
    required this.taughtWorkshops,
    required this.achievements,
    required this.testimonials,
    required this.averageRating,
    required this.workshopsCompleted,
  });

  @override
  State<CVPreviewScreen> createState() => _CVPreviewScreenState();
}

class _CVPreviewScreenState extends State<CVPreviewScreen> {
  bool _isGenerating = false;
  bool _useAIGeneration = false;

  // AI-generated content
  String _professionalSummary = "";
  String _skillsText = "";
  String _experienceText = "";
  String _educationText = "";
  String _achievementsText = "";

  // Editable user overrides (start empty, filled when user edits)
  late Map<String, String> _editedContent;

  @override
  void initState() {
    super.initState();
    // Initialize editable map with empty strings
    _editedContent = {
      'summary': '',
      'skills': '',
      'experience': '',
      'education': '',
      'achievements': '',
    };
    _generateAllSections();
  }

  // Helper to get final text: edited > AI > fallback
  String _getDisplayText(String key, String aiText, String fallback) {
    final edited = _editedContent[key];
    if (edited != null && edited.isNotEmpty) return edited;
    if (_useAIGeneration && aiText.isNotEmpty) return aiText;
    return fallback;
  }

  // Edit dialog for any section
  void _editSection(String key, String title, String currentText) {
    final controller = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit $title"),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Write your own content here...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _editedContent[key] = controller.text.trim();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("$title updated!")),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("CV Preview"),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit CV Content',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Tap the pencil icon next to any section to edit")),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download CV as PDF',
            onPressed: _generateAndSavePDF,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),

                // AI Toggle
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Enhance with AI", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Text("AI Mode", style: TextStyle(color: _useAIGeneration ? Colors.green : Colors.grey)),
                            const SizedBox(width: 8),
                            Switch(
                              value: _useAIGeneration,
                              onChanged: (value) {
                                setState(() => _useAIGeneration = value);
                                _generateAllSections();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Professional Summary
                _buildEditableSection(
                  context,
                  "PROFESSIONAL SUMMARY",
                  _getDisplayText('summary', _professionalSummary, _generateTemplateSummary()),
                      () => _editSection('summary', "Professional Summary", _getDisplayText('summary', _professionalSummary, _generateTemplateSummary())),
                ),
                const SizedBox(height: 24),

                // Skills
                _buildEditableSection(
                  context,
                  "SKILLS",
                  _useAIGeneration && _skillsText.isNotEmpty
                      ? _skillsText
                      : _buildSkillsSectionFallback(), // fallback is widget, so handle separately
                      () => _editSection('skills', "Skills", _getDisplayText('skills', _skillsText, "")),
                  isRichText: _useAIGeneration && _skillsText.isEmpty, // only allow edit if AI text exists or user wants custom
                ),

                // For Skills, we use fallback widget if no AI text and no edit
                if (!_useAIGeneration || _skillsText.isEmpty)
                  _buildSection(context, "SKILLS", _buildSkillsSection(context)),

                const SizedBox(height: 24),

                // Experience
                _buildEditableSection(
                  context,
                  "EXPERIENCE",
                  _getDisplayText('experience', _experienceText, ""),
                      () => _editSection('experience', "Experience", _getDisplayText('experience', _experienceText, "")),
                ),
                if (!_useAIGeneration || _experienceText.isEmpty)
                  _buildSection(context, "EXPERIENCE", _buildExperienceSection(context)),

                const SizedBox(height: 24),

                // Education
                _buildEditableSection(
                  context,
                  "EDUCATION",
                  _getDisplayText('education', _educationText, ""),
                      () => _editSection('education', "Education", _getDisplayText('education', _educationText, "")),
                ),
                if (!_useAIGeneration || _educationText.isEmpty)
                  _buildSection(context, "EDUCATION", _buildEducationSection(context)),

                const SizedBox(height: 24),

                // Achievements
                if (widget.achievements.isNotEmpty) ...[
                  _buildEditableSection(
                    context,
                    "ACHIEVEMENTS",
                    _getDisplayText('achievements', _achievementsText, ""),
                        () => _editSection('achievements', "Achievements", _getDisplayText('achievements', _achievementsText, "")),
                  ),
                  if (!_useAIGeneration || _achievementsText.isEmpty)
                    _buildSection(context, "ACHIEVEMENTS", _buildAchievementsSection(context)),
                  const SizedBox(height: 24),
                ],

                // Testimonials
                if (widget.testimonials.isNotEmpty)
                  _buildSection(context, "TESTIMONIALS", _buildTestimonialsSection(context)),

                const SizedBox(height: 80),
              ],
            ),
          ),

          if (_isGenerating)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text("Enhancing your CV with AI...", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // New helper: editable section with pencil icon
  Widget _buildEditableSection(BuildContext context, String title, String content, VoidCallback onEdit, {bool isRichText = true}) {
    final theme = Theme.of(context);
    final hasContent = content.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                decoration: TextDecoration.underline,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              tooltip: "Edit this section",
              onPressed: onEdit,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (hasContent)
          if (isRichText)
            ...content.split('\n').where((line) => line.trim().isNotEmpty).map((line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(line.trim(), style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
            ))
          else
            Text(content, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))
        else
          Text("No content yet — tap edit to add your own", style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface.withAlpha(150))),
      ],
    );
  }

  // Fallback for Skills when no AI text
  String _buildSkillsSectionFallback() {
    return widget.skills.map((s) => "• ${s['name']} (${s['level']})").join('\n');
  }

  Future<void> _generateAllSections() async {
    if (!mounted) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      if (_useAIGeneration) {
        // Generate all AI content in parallel
        final futures = await Future.wait([
          HuggingFaceService.generateSummary(
            name: widget.userProfile['name'] ?? "Professional",
            skills: widget.skills.map((s) => s['name'] as String).toList(),
            workshopCount: widget.taughtWorkshops.length,
            rating: widget.averageRating.toStringAsFixed(1),
          ),
          HuggingFaceService.generateSkillsSection(skillsData: widget.skills),
          HuggingFaceService.generateExperienceSection(
            taughtWorkshops: widget.taughtWorkshops,
            name: widget.userProfile['name'] ?? "Professional",
          ),
          HuggingFaceService.generateEducationSection(userProfile: widget.userProfile),
          HuggingFaceService.generateAchievementsSection(achievements: widget.achievements),
        ]);

        if (!mounted) return;

        setState(() {
          _professionalSummary = futures[0];
          _skillsText = futures[1];
          _experienceText = futures[2];
          _educationText = futures[3];
          _achievementsText = futures[4];
        });
      } else {
        // Use template/fallback versions
        setState(() {
          _professionalSummary = _generateTemplateSummary();
          _skillsText = "";
          _experienceText = "";
          _educationText = "";
          _achievementsText = "";
        });
      }
    } catch (e) {
      debugPrint('AI generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("AI enhancement failed, using standard format"),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _professionalSummary = _generateTemplateSummary();
          _skillsText = "";
          _experienceText = "";
          _educationText = "";
          _achievementsText = "";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _generateAndSavePDF() async {
    final pdf = pw.Document();
    final name = widget.userProfile['name'] as String? ?? "Your Name";
    final email = widget.userProfile['email'] as String? ?? "";
    final phone = widget.userProfile['phone'] as String? ?? "";
    final location = widget.userProfile['location'] as String? ?? "";

    final List<pw.Widget> content = [];

    // Header
    content.add(pw.Text(name, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)));
    content.add(pw.SizedBox(height: 8));
    content.add(pw.Text(email, style: const pw.TextStyle(fontSize: 12)));
    if (phone.isNotEmpty) content.add(pw.Text(phone, style: const pw.TextStyle(fontSize: 12)));
    if (location.isNotEmpty) content.add(pw.Text(location, style: const pw.TextStyle(fontSize: 12)));
    content.add(pw.SizedBox(height: 20));
    content.add(pw.Divider());
    content.add(pw.SizedBox(height: 20));

    // Professional Summary — uses edited > AI > template
    content.add(pw.Text("PROFESSIONAL SUMMARY", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
    content.add(pw.SizedBox(height: 8));
    final summaryText = _getDisplayText('summary', _professionalSummary, _generateTemplateSummary());
    content.add(pw.Paragraph(text: summaryText, style: const pw.TextStyle(fontSize: 11, lineSpacing: 5)));
    content.add(pw.SizedBox(height: 20));

    // Skills — uses edited > AI > fallback chips
    content.add(pw.Text("SKILLS", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
    content.add(pw.SizedBox(height: 8));
    final skillsText = _getDisplayText('skills', _skillsText, _buildSkillsSectionFallback());
    if (skillsText.isNotEmpty) {
      content.add(pw.Paragraph(text: skillsText, style: const pw.TextStyle(fontSize: 11)));
    } else {
      content.add(
        pw.Wrap(
          spacing: 10,
          runSpacing: 10,
          children: widget.skills.map((s) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey300,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text("${s['name']} (${s['level']})", style: const pw.TextStyle(fontSize: 11)),
            );
          }).toList(),
        ),
      );
    }
    content.add(pw.SizedBox(height: 20));

    // Experience — uses edited > AI > fallback
    content.add(pw.Text("EXPERIENCE", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
    content.add(pw.SizedBox(height: 12));
    final experienceText = _getDisplayText('experience', _experienceText, "");
    if (experienceText.isNotEmpty) {
      content.add(pw.Paragraph(text: experienceText, style: const pw.TextStyle(fontSize: 11, lineSpacing: 5)));
    } else {
      for (final w in widget.taughtWorkshops) {
        final title = w['title'] as String? ?? "Untitled";
        final description = w['description'] as String? ?? "";
        content.add(pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text("Workshop Instructor", style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
            pw.SizedBox(height: 6),
            pw.Paragraph(text: description, style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 12),
          ],
        ));
      }
    }
    content.add(pw.SizedBox(height: 20));

    // Education — uses edited > AI > fallback
    content.add(pw.Text("EDUCATION", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
    content.add(pw.SizedBox(height: 8));
    final educationText = _getDisplayText('education', _educationText, "");
    if (educationText.isNotEmpty) {
      content.add(pw.Paragraph(text: educationText, style: const pw.TextStyle(fontSize: 11)));
    } else {
      final university = widget.userProfile['university'] as String?;
      final major = widget.userProfile['major'] as String?;
      final year = widget.userProfile['year'] as String?;
      if (university != null) content.add(pw.Text(university, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)));
      if (major != null) content.add(pw.Text(major, style: const pw.TextStyle(fontSize: 11)));
      if (year != null) content.add(pw.Text("Graduated: $year", style: const pw.TextStyle(fontSize: 11)));
    }
    content.add(pw.SizedBox(height: 20));

    // Achievements — uses edited > AI > fallback
    if (widget.achievements.isNotEmpty) {
      content.add(pw.Text("ACHIEVEMENTS", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
      content.add(pw.SizedBox(height: 8));
      final achievementsText = _getDisplayText('achievements', _achievementsText, "");
      if (achievementsText.isNotEmpty) {
        content.add(pw.Paragraph(text: achievementsText, style: const pw.TextStyle(fontSize: 11)));
      } else {
        for (final a in widget.achievements) {
          content.add(pw.Text("• ${a['title']} ${a['icon'] ?? ''}", style: const pw.TextStyle(fontSize: 11)));
          if (a['desc'] != null) content.add(pw.Text(a['desc'], style: const pw.TextStyle(fontSize: 11)));
          content.add(pw.SizedBox(height: 6));
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: content)],
      ),
    );

    await Printing.sharePdf(
      filename: 'SkillX_CV_${name.replaceAll(' ', '_')}.pdf',
      bytes: await pdf.save(),
    );
  }



  String _generateTemplateSummary() {
    final name = widget.userProfile['name'] as String? ?? "Professional";
    final bio = widget.userProfile['bio'] as String? ?? "";
    final skillNames = widget.skills.map((s) => s['name'] as String).toList();

    if (bio.isNotEmpty) return bio;

    String summary = "$name is a skilled workshop facilitator";
    if (skillNames.isNotEmpty) {
      final skillsPart = skillNames.length > 3
          ? "${skillNames.take(3).join(', ')} and others"
          : skillNames.join(', ');
      summary += " specializing in $skillsPart";
    }
    summary += ". Delivered ${widget.taughtWorkshops.length} workshops with an average rating of ${widget.averageRating.toStringAsFixed(1)}/5.";
    return summary;
  }


  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.userProfile['name'] as String? ?? "Your Name";
    final phone = widget.userProfile['phone'] as String?;
    final email = widget.userProfile['email'] as String? ?? "your.email@example.com";
    final location = widget.userProfile['location'] as String?;
    final website = widget.userProfile['website'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            // Removed: color: Colors.black87
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            if (phone != null) _buildContactItem(Icons.phone, phone),
            _buildContactItem(Icons.email, email),
            if (location != null) _buildContactItem(Icons.location_on, location),
            if (website != null) _buildContactItem(Icons.language, website),
          ],
        ),
      ],
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurface.withAlpha(128)),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withAlpha(179),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, Widget content) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface, // CHANGED: Was Colors.black87
            decoration: TextDecoration.underline,
            decorationThickness: 1,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildSkillsSection(BuildContext context) {
    final theme = Theme.of(context);

    // Group skills by level
    final expertSkills = widget.skills.where((s) => s['level'] == 'Expert').toList();
    final advancedSkills = widget.skills.where((s) => s['level'] == 'Advanced').toList();
    final intermediateSkills = widget.skills.where((s) => s['level'] == 'Intermediate').toList();
    final beginnerSkills = widget.skills.where((s) => s['level'] == 'Beginner').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expertSkills.isNotEmpty) ...[
          _buildSkillCategory("Expert", expertSkills),
          const SizedBox(height: 12),
        ],
        if (advancedSkills.isNotEmpty) ...[
          _buildSkillCategory("Advanced", advancedSkills),
          const SizedBox(height: 12),
        ],
        if (intermediateSkills.isNotEmpty) ...[
          _buildSkillCategory("Intermediate", intermediateSkills),
          const SizedBox(height: 12),
        ],
        if (beginnerSkills.isNotEmpty) ...[
          _buildSkillCategory("Beginner", beginnerSkills),
        ],
      ],
    );
  }

  Widget _buildSkillCategory(String level, List<Map<String, dynamic>> skillList) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          level,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface, // CHANGED: Was Colors.black87
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: skillList.map((skill) {
            return Chip(
              label: Text(
                skill['name'] as String,
                style: const TextStyle(fontSize: 12),
              ),
              // CHANGED: Use theme chip color with fallback
              backgroundColor: theme.chipTheme.backgroundColor ?? Colors.grey[200],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExperienceSection(BuildContext context) {
    final theme = Theme.of(context);

    // Sort workshops by date (most recent first)
    final sortedWorkshops = List<Map<String, dynamic>>.from(widget.taughtWorkshops);
    sortedWorkshops.sort((a, b) {
      if (a['date'] == null && b['date'] == null) return 0;
      if (a['date'] == null) return 1;
      if (b['date'] == null) return -1;
      return DateTime.parse(b['date']).compareTo(DateTime.parse(a['date']));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedWorkshops.map((workshop) {
        final title = workshop['title'] as String? ?? "Untitled Workshop";
        final date = workshop['date'] as String?;
        final description = workshop['description'] as String? ?? "";
        final category = workshop['category'] as String? ?? "General";
        final duration = workshop['duration'] as String? ?? "";
        final skills = workshop['skills'] as List? ?? [];
        final rating = workshop['rating'] as num? ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Workshop Instructor",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(128),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                if (date != null)
                  Text(
                    _formatDate(date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(128),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (description.isNotEmpty)
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (category.isNotEmpty) ...[
                  Text(
                    "Category: $category",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                if (duration.isNotEmpty) ...[
                  Text(
                    "Duration: $duration",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                if (rating > 0) ...[
                  Text(
                    "Rating: ",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                  ...List.generate(
                    5,
                        (i) => Icon(
                      Icons.star,
                      size: 14,
                      color: i < rating ? Colors.amber : Colors.grey[300],
                    ),
                  ),
                ],
              ],
            ),
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Skills taught: ${skills.join(', ')}",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildEducationSection(BuildContext context) {
    final theme = Theme.of(context);
    final university = widget.userProfile['university'] as String?;
    final major = widget.userProfile['major'] as String?;
    final year = widget.userProfile['year'] as String?;

    if (university == null && major == null && year == null) {
      return Text(
        "Education information not provided",
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.black54,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (university != null)
          Text(
            university,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              // removed Colors.black87
            ),
          ),
        if (major != null)
          Text(
            major,
            style: theme.textTheme.bodyMedium,
          ),
        if (year != null)
          Text(
            "Graduated: $year",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(179),
            ),
          ),
      ],
    );
  }

  Widget _buildAchievementsSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.achievements.map((achievement) {
        final title = achievement['title'] as String? ?? "";
        final desc = achievement['desc'] as String? ?? "";
        final earned = achievement['earned'] as String? ?? "";

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                if (earned != "N/A")
                  Text(
                    earned,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(128),
                    ),
                  ),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                desc,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTestimonialsSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.testimonials.map((testimonial) {
        final author = testimonial['author'] as String? ?? "";
        final text = testimonial['text'] as String? ?? "";
        final rating = testimonial['rating'] as int? ?? 0;
        final skill = testimonial['skill'] as String? ?? "";

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "\"$text\"",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  "- $author",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withAlpha(230),
                  ),
                ),
                const SizedBox(width: 8),
                if (skill.isNotEmpty)
                  Text(
                    "($skill)",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                const SizedBox(width: 8),
                ...List.generate(
                  5,
                      (i) => Icon(
                    Icons.star,
                    size: 14,
                    color: i < rating ? Colors.amber : Colors.grey[300],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return "${date.month}/${date.year}";
    } catch (e) {
      return dateString;
    }
  }
}