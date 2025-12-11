// Update the WorkshopDetailScreen.dart file

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skillx/screens/create_workshop_screen.dart';
import 'package:skillx/screens/user_profile_screen.dart';
import 'package:skillx/screens/chat_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class WorkshopDetailScreen extends StatefulWidget {
  final Map<String, dynamic> workshop;

  const WorkshopDetailScreen({super.key, required this.workshop});

  @override
  State<WorkshopDetailScreen> createState() => _WorkshopDetailScreenState();
}

class _WorkshopDetailScreenState extends State<WorkshopDetailScreen> {
  bool isEnrolled = false;
  bool isLiked = false;
  bool isLoadingEnrollment = false;
  Map<String, dynamic>? workshopConversation;
  String enrollmentStatus = 'none'; // Track the status: 'none', 'pending', 'enrolled'

  late List<Map<String, dynamic>> syllabus;
  Map<String, dynamic>? lessonReviews; // Track reviews for each lesson
  bool hasReviewedWorkshop = false; // Track if user has reviewed the entire workshop

  @override
  void initState() {
    super.initState();
    // Use the workshop's own syllabus if it exists, otherwise fallback to default
    final passed = widget.workshop["syllabus"];
    syllabus = passed != null && passed is List
        ? List<Map<String, dynamic>>.from(passed)
        : [
      {"title": "Introduction", "duration": "10 min", "completed": false},
      {"title": "Core Concepts", "duration": "20 min", "completed": false},
      {"title": "Project Practice", "duration": "30 min", "completed": false},
    ];

    // Initialize lesson reviews map
    lessonReviews = {};
    for (int i = 0; i < syllabus.length; i++) {
      lessonReviews![i.toString()] = null; // No review initially
    }

    // Check if user is enrolled and get workshop conversation
    _checkEnrollmentAndConversation();
    _checkExistingReviews();
  }

// Update the _checkEnrollmentAndConversation function in WorkshopDetailScreen.dart

  Future<void> _checkEnrollmentAndConversation() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Check if user is enrolled in the workshop
      final enrollmentData = await Supabase.instance.client
          .from('workshop_enrollments')
          .select()
          .eq('user_id', currentUser.id)
          .eq('workshop_id', widget.workshop['id'])
          .maybeSingle();

      // Check if user has a pending enrollment request
      final requestData = await Supabase.instance.client
          .from('workshop_requests')
          .select()
          .eq('requester_id', currentUser.id)  // Changed from user_id to requester_id
          .eq('workshop_id', widget.workshop['id'])
          .maybeSingle();

      // Set the appropriate status - enrollment takes precedence over request
      String status = 'none';
      if (enrollmentData != null) {
        status = 'enrolled';
      } else if (requestData != null) {
        status = 'pending';
      }

      setState(() {
        isEnrolled = enrollmentData != null;
        enrollmentStatus = status;
      });

      // If enrolled, get the workshop conversation
      if (isEnrolled) {
        final conversationData = await Supabase.instance.client
            .from('workshops')
            .select('conversation_id')
            .eq('id', widget.workshop['id'])
            .single();

        if (conversationData['conversation_id'] != null) {
          // Make sure the user is added to the conversation participants
          await Supabase.instance.client.rpc('add_user_to_workshop_chat', params: {
            'workshop_id': widget.workshop['id'],
            'user_id': currentUser.id,  // Use user_id instead of participant_id
          });

          final conversation = await Supabase.instance.client
              .from('conversations')
              .select('id, name, avatar_url')
              .eq('id', conversationData['conversation_id'])
              .single();

          setState(() {
            workshopConversation = conversation;
          });
        }
      }
    } catch (e) {
      print('Error checking enrollment: $e');
    }
  }

  // Check for existing reviews
  Future<void> _checkExistingReviews() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Check if user has already reviewed the workshop
      final existingWorkshopReview = await Supabase.instance.client
          .from('workshop_ratings')
          .select()
          .eq('workshop_id', widget.workshop['id'])
          .eq('user_id', currentUser.id)
          .maybeSingle();

      setState(() {
        hasReviewedWorkshop = existingWorkshopReview != null;
      });

      // Check for lesson reviews if we have a lesson_reviews table
      // This is a placeholder for where you would fetch lesson reviews
      // You might need to create a new table for lesson reviews
    } catch (e) {
      print('Error checking existing reviews: $e');
    }
  }

  // Also add a refresh method to manually check enrollment status
  Future<void> _refreshEnrollmentStatus() async {
    await _checkEnrollmentAndConversation();
  }

// In WorkshopDetailScreen.dart
  void _toggleLessonComplete(int index) async {
    final currentUser = supabase.auth.currentUser;
    final isCreator = currentUser != null && widget.workshop['creator_id'] == currentUser.id;

    if (!isCreator) return;

    // Optimistically update the UI
    setState(() {
      syllabus[index]['completed'] = !syllabus[index]['completed'];
    });
    await _updateWorkshopSyllabus();

    // If the lesson is being marked as completed, call our new function
    if (syllabus[index]['completed']) {
      try {
        // Get all enrolled users for this workshop
        final enrolledUsersResponse = await supabase
            .from('workshop_enrollments')
            .select('user_id')
            .eq('workshop_id', widget.workshop['id']);

        final List<dynamic> enrolledUsers = enrolledUsersResponse;

        // Call the database function for each enrolled user
        for (final enrollment in enrolledUsers) {
          await supabase.rpc('mark_lesson_complete', params: {
            'p_user_id': enrollment['user_id'],
            'p_workshop_id': widget.workshop['id'],
            'p_lesson_index': index,
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lesson marked complete for all participants!')),
          );
        }
      } catch (e) {
        // Revert the UI change on error
        setState(() {
          syllabus[index]['completed'] = !syllabus[index]['completed'];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error marking lesson complete: $e')),
          );
        }
      }
    }
  }

  // Update workshop syllabus in the database
  Future<void> _updateWorkshopSyllabus() async {
    try {
      await Supabase.instance.client
          .from('workshops')
          .update({'syllabus': syllabus})
          .eq('id', widget.workshop['id']);
    } catch (e) {
      print('Error updating syllabus: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating syllabus: ${e.toString()}')),
      );
    }
  }

  // Show dialog to review a lesson
  void _showLessonReviewDialog(int lessonIndex) {
    final TextEditingController reviewController = TextEditingController();
    int rating = 5; // Default rating

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review: ${syllabus[lessonIndex]['title']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How would you rate this lesson?'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      rating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reviewController,
              decoration: const InputDecoration(
                hintText: 'Write your review...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _submitLessonReview(lessonIndex, rating, reviewController.text);
              Navigator.pop(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // Submit lesson review
  Future<void> _submitLessonReview(int lessonIndex, int rating, String review) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Store the review locally
      setState(() {
        lessonReviews![lessonIndex.toString()] = {
          'rating': rating,
          'review': review,
          'created_at': DateTime.now().toIso8601String(),
        };
      });

      // In a real implementation, you would save this to a lesson_reviews table
      // For now, we'll just show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson review submitted!')),
      );
    } catch (e) {
      print('Error submitting lesson review: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting review: ${e.toString()}')),
      );
    }
  }

  // Show dialog to review the entire workshop
  void _showWorkshopReviewDialog() {
    final TextEditingController reviewController = TextEditingController();
    int rating = 5; // Default rating

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review: ${widget.workshop['title']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How would you rate this workshop?'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      rating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reviewController,
              decoration: const InputDecoration(
                hintText: 'Write your review...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _submitWorkshopReview(rating, reviewController.text);
              Navigator.pop(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // Submit workshop review
  Future<void> _submitWorkshopReview(int rating, String review) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      // 1. Save the review to the database (this part is unchanged)
      await supabase
          .from('workshop_ratings')
          .upsert({
        'workshop_id': widget.workshop['id'],
        'user_id': currentUser.id,
        'rating': rating,
        'review': review,
        // 'created_at' is automatically handled by Supabase default, no need to set it here
      }, onConflict: 'workshop_id,user_id');

      // 2. Award XP and check for badges using our secure backend function
      // This is the new gamification logic!
      await supabase.rpc('award_xp_and_check_badges', params: {
        'p_user_id': currentUser.id,
        'p_xp_to_award': 20, // Award 20 XP for submitting a workshop review
        'p_action_type': 'workshop_reviewed',
        'p_workshop_id': widget.workshop['id'],
      });

      // 3. Update the UI state
      setState(() {
        hasReviewedWorkshop = true;
      });

      // 4. Show a success message that includes the XP reward
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workshop review submitted! +20 XP'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error submitting workshop review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting review: ${e.toString()}')),
        );
      }
    }
  }

  // Format date for display
  String _formatDate(DateTime? date) {
    if (date == null) return 'Date to be announced';

    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays > 0) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == -1) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Format time for display
  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Time to be announced';

    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final ws = widget.workshop;
    final theme = Theme.of(context);
    final isTeach4Learn = ws['type'] == 'Teach4Learn';
    final currentUser = Supabase.instance.client.auth.currentUser;
    final isCreator = currentUser != null && ws['creator_id'] == currentUser.id;

    final completedCount =
        syllabus.where((item) => item['completed']).length;
    final progressPercent = syllabus.isEmpty
        ? 0.0
        : completedCount / syllabus.length;

    // Check if all lessons are completed
    final allLessonsCompleted = syllabus.every((lesson) => lesson['completed'] == true);

    // Parse date and time from workshop data
    DateTime? workshopDate;
    TimeOfDay? workshopTime;

    if (ws['date'] != null) {
      try {
        workshopDate = DateTime.parse(ws['date']);
        workshopTime = TimeOfDay.fromDateTime(workshopDate);
      } catch (e) {
        print('Error parsing date: $e');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isTeach4Learn
              ? (ws['title'] ?? 'Skill Exchange')
              : (ws['title'] ?? 'Workshop Details'),
        ),
        actions: [
          // Add a debug refresh button (remove in production)
          if (!isCreator)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshEnrollmentStatus,
              tooltip: 'Refresh enrollment status',
            ),
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : null,
            ),
            onPressed: () {
              setState(() => isLiked = !isLiked);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isLiked ? "Added to favorites" : "Removed from favorites",
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Sharing not implemented")),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Banner ---
          if (isTeach4Learn)
            _banner(theme, "Teach4Learn Exchange", Icons.swap_horiz, Colors.blue)
          else
            _banner(theme, "Free Workshop", Icons.school, Colors.deepPurple),

          const SizedBox(height: 16),

          // --- Cover Image ---
          _coverImage(ws),

          const SizedBox(height: 20),

          // --- Date and Time Card ---
          if (!isTeach4Learn)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Date & Time",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          _formatDate(workshopDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          _formatTime(workshopTime),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    if (ws['location'] != null && ws['location'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              ws['location'],
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

          if (!isTeach4Learn) const SizedBox(height: 20),

          // --- Stats ---
          if (!isTeach4Learn)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatItem(
                    icon: Icons.star,
                    label: "${ws['rating'] ?? 'N/A'}",
                    color: Colors.amber),
                _StatItem(
                    icon: Icons.group,
                    label: "${ws['participants'] ?? '0/0'}",
                    color: Colors.green),
                _StatItem(
                    icon: Icons.access_time,
                    label: ws['duration'] ?? '',
                    color: Colors.blue),
              ],
            ),
          if (!isTeach4Learn) const SizedBox(height: 20),

          // --- Instructor / Exchange Partner ---
          _instructorCard(context, ws, theme, isTeach4Learn),

          const SizedBox(height: 20),

          // --- Workshop Group Chat Button ---
          if (isEnrolled && workshopConversation != null)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.chat, color: Colors.blue),
                title: const Text('Workshop Group Chat'),
                subtitle: const Text('Join the discussion with other participants'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        initialConversation: {
                          'id': workshopConversation!['id'],
                          'is_group': true,
                          'name': workshopConversation!['name'],
                          'avatar_url': workshopConversation!['avatar_url'],
                          'workshop_id': ws['id'],
                        },
                      ),
                    ),
                  );
                },
              ),
            ),

          if (isEnrolled && workshopConversation != null) const SizedBox(height: 20),

          // --- About Section ---
          _aboutCard(ws, theme, isTeach4Learn),

          const SizedBox(height: 20),

          // --- Syllabus ---
          if ((ws['syllabus'] ?? []).isNotEmpty)
            _syllabusCard(theme, progressPercent, isCreator),

          const SizedBox(height: 20),

          // --- Workshop Review Button (only for enrolled users when all lessons are completed) ---
          if (isEnrolled && allLessonsCompleted && !hasReviewedWorkshop)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.rate_review),
                label: const Text("Review Workshop"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _showWorkshopReviewDialog,
              ),
            ),

          // --- Prerequisites ---
          if ((ws['prerequisites'] ?? '').toString().trim().isNotEmpty)
            _infoCard(
              title: "Prerequisites",
              content: ws['prerequisites'],
              icon: Icons.check_circle_outline,
              color: Colors.orange,
            ),

          const SizedBox(height: 20),

          // --- Learning Outcomes ---
          if ((ws['outcomes'] ?? '').toString().trim().isNotEmpty)
            _infoCard(
              title: "Learning Outcomes",
              content: ws['outcomes'],
              icon: Icons.emoji_events_outlined,
              color: Colors.green,
            ),

          const SizedBox(height: 20),

          // --- Tags ---
          if ((ws['tags'] ?? []).isNotEmpty)
            _tagsCard(ws['tags']),

          const SizedBox(height: 20),

          // --- Reviews ---
          _reviewCard(),

          const SizedBox(height: 80),
        ],
      ),

      // --- Bottom Button ---
      bottomNavigationBar: _bottomButton(context, theme, isTeach4Learn),
    );
  }

  Widget _banner(ThemeData theme, String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _coverImage(Map<String, dynamic> ws) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ws['image'] != null
          ? Image.network(
        ws['image'],
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/placeholder.png',
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      )
          : Image.asset(
        'assets/images/placeholder.png',
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _instructorCard(BuildContext context, Map<String, dynamic> ws,
      ThemeData theme, bool isTeach4Learn) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(
                user: {
                  "name": ws["instructor"] ?? ws["partner"] ?? "Unknown",
                  "bio": isTeach4Learn
                      ? "Enthusiastic learner and teacher ready to exchange skills."
                      : "Experienced instructor passionate about teaching.",
                  "university": "SkillX Community",
                  "rating": ws["rating"] ?? 4.8,
                },
              ),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
          child: Text(
            (ws['instructor'] ?? ws['partner'] ?? "?")
                .toString()
                .substring(0, 1),
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
        title: Text(
          ws['instructor'] ??
              ws['partner'] ??
              (isTeach4Learn ? "Exchange Partner" : "Instructor"),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(isTeach4Learn
            ? "Skill Exchange Partner"
            : "Workshop Instructor"),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _aboutCard(Map<String, dynamic> ws, ThemeData theme, bool isTeach4Learn) {
    if (!isTeach4Learn) {
      // Normal workshops stay as-is
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "About",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                ws['description'] ?? "No description available for this workshop.",
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Teach4Learn layout: skill exchange information
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Skill Exchange Details",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Skill the user wants to learn
            if (ws['skill_requested'] != null && ws['skill_requested'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.school, color: Colors.deepPurple, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Wants to learn: ${ws['skill_requested']}",
                        style: theme.textTheme.bodyMedium!
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // Skill the user can teach in return
            if (ws['skill_offered'] != null && ws['skill_offered'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Can teach: ${ws['skill_offered']}",
                        style: theme.textTheme.bodyMedium!
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade300),

            const SizedBox(height: 8),
            Text(
              ws['description'] ??
                  "This Teach4Learn session is about skill sharing and collaborative learning.",
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _syllabusCard(ThemeData theme, double progressPercent, bool isCreator) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Syllabus",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progressPercent,
              backgroundColor: Colors.grey.shade300,
              minHeight: 6,
            ),
            const SizedBox(height: 16),
            Column(
              children: syllabus.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final hasReviewed = lessonReviews?[index.toString()] != null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: item['completed']
                        ? Colors.green.withOpacity(0.1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Only make the circle clickable for the creator
                      GestureDetector(
                        onTap: isCreator ? () => _toggleLessonComplete(index) : null,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: item['completed']
                              ? Colors.green
                              : theme.colorScheme.primary,
                          child: Icon(
                            item['completed']
                                ? Icons.check
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            Text(item['duration'],
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      // Show "Give Review" button for completed lessons (for enrolled users, not creators)
                      if (item['completed'] && isEnrolled && !isCreator && !hasReviewed)
                        TextButton(
                          onPressed: () => _showLessonReviewDialog(index),
                          child: const Text("Give Review"),
                        ),
                      // Show "Reviewed" indicator if already reviewed
                      if (item['completed'] && isEnrolled && !isCreator && hasReviewed)
                        const Text(
                          "Reviewed",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Reviews",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            Text("⭐ Jennifer Wu: Excellent session!"),
            Text("⭐ Tom Martinez: Great collaboration opportunity."),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required dynamic content,
    required IconData icon,
    required Color color,
  }) {
    final items = content is List ? content : [content];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text("• $item"),
            )),
          ],
        ),
      ),
    );
  }

  Widget _tagsCard(List<dynamic> tags) {
    final theme = Theme.of(context);
    final chipTheme = theme.chipTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark
          ? const Color(0xFF273549) // lighter than dark surface
          : Colors.white,            // clean white in light mode
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map<Widget>((tag) {
            return Chip(
              label: Text(
                tag.toString(),
                style: chipTheme.labelStyle,
              ),
              backgroundColor: chipTheme.backgroundColor,
              side: BorderSide.none,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _bottomButton(BuildContext context, ThemeData theme, bool isTeach4Learn) {
    final ws = widget.workshop;
    final currentUser = Supabase.instance.client.auth.currentUser;
    final isCreator = currentUser != null && ws['creator_id'] == currentUser.id;

    // If creator, disable the enroll button
    if (isCreator) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            // EDIT BUTTON
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text("Edit"),
                onPressed: () async {
                  // Navigate to CreateWorkshopScreen in edit mode
                  final updatedWorkshop = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateWorkshopScreen(
                        existingWorkshop: ws,
                        isEditing: true,
                      ),
                    ),
                  );

                  // Refresh detail screen after editing
                  if (updatedWorkshop != null) {
                    setState(() {
                      widget.workshop.clear();
                      widget.workshop.addAll(updatedWorkshop);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Workshop details refreshed ✅"),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),

            // DELETE BUTTON
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: const Text("Delete"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Delete Workshop"),
                      content: const Text(
                        "Are you sure you want to delete this workshop? This action cannot be undone.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );

                  // Only delete & navigate back if confirmed
                  if (confirm == true) {
                    try {
                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const AlertDialog(
                          content: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 20),
                              Text("Deleting workshop..."),
                            ],
                          ),
                        ),
                      );

                      // Delete from Supabase
                      await Supabase.instance.client
                          .from('workshops')
                          .delete()
                          .eq('id', ws['id']);

                      // Also delete any related enrollments, ratings, and requests
                      await Supabase.instance.client
                          .from('workshop_enrollments')
                          .delete()
                          .eq('workshop_id', ws['id']);

                      await Supabase.instance.client
                          .from('workshop_ratings')
                          .delete()
                          .eq('workshop_id', ws['id']);

                      await Supabase.instance.client
                          .from('workshop_requests')
                          .delete()
                          .eq('workshop_id', ws['id']);

                      // Close loading dialog
                      Navigator.pop(context);

                      // Update local state
                      context.read<AppState>().deleteWorkshop(ws['id']);

                      // Close details screen
                      Navigator.pop(context);

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Workshop deleted 🗑️")),
                      );
                    } catch (e) {
                      // Close loading dialog if still open
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }

                      // Show error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error deleting workshop: ${e.toString()}")),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      );
    }

    // Show workshop group chat button if enrolled
    if (isEnrolled && workshopConversation != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.chat),
          label: const Text("Open Workshop Chat"),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  initialConversation: {
                    'id': workshopConversation!['id'],
                    'is_group': true,
                    'name': workshopConversation!['name'],
                    'avatar_url': workshopConversation!['avatar_url'],
                    'workshop_id': ws['id'],
                  },
                ),
              ),
            );
          },
        ),
      );
    }

    // Otherwise show enroll/un-enroll button based on enrollment status
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: enrollmentStatus == 'enrolled'
              ? Colors.green  // Changed to green color when enrolled
              : theme.colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        // Disable the button if enrolled (approved) to prevent unenrollment
        onPressed: (isLoadingEnrollment || enrollmentStatus == 'enrolled') ? null : () async {
          setState(() => isLoadingEnrollment = true);

          try {
            if (enrollmentStatus == 'pending') {
              // Withdraw pending request
              await Supabase.instance.client
                  .from('workshop_requests')
                  .delete()
                  .eq('requester_id', currentUser!.id)  // Changed from user_id to requester_id
                  .eq('workshop_id', ws['id']);

              setState(() {
                enrollmentStatus = 'none';
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isTeach4Learn
                      ? "Exchange request withdrawn"
                      : "Enrollment request withdrawn"),
                ),
              );
            } else {
              // Send new enrollment request
              await Supabase.instance.client
                  .from('workshop_requests')
                  .insert({
                'workshop_id': ws['id'],
                'requester_id': currentUser!.id,
                'status': 'pending',
              });

              setState(() {
                enrollmentStatus = 'pending';
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isTeach4Learn
                      ? "Exchange request sent! 🎯"
                      : "Enrollment request sent! Awaiting approval."),
                ),
              );
            }
          } catch (e) {
            print('Error with enrollment: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${e.toString()}')),
            );
          } finally {
            setState(() => isLoadingEnrollment = false);
          }
        },
        child: isLoadingEnrollment
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Text(
          enrollmentStatus == 'enrolled'
              ? "Enrolled ✓"  // Changed to show proper message when enrolled
              : enrollmentStatus == 'pending'
              ? "Withdraw Request"
              : (isTeach4Learn ? "Send Exchange Request" : "Request Enrollment"),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatItem({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}