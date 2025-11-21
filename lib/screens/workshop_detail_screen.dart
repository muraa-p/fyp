import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skillx/screens/create_workshop_screen.dart';
import 'package:skillx/screens/user_profile_screen.dart';
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

  late List<Map<String, dynamic>> syllabus;

  @override
  void initState() {
    super.initState();
    // ✅ Use the workshop's own syllabus if it exists, otherwise fallback to default
    final passed = widget.workshop["syllabus"];
    syllabus = passed != null && passed is List
        ? List<Map<String, dynamic>>.from(passed)
        : [
      {"title": "Introduction", "duration": "10 min", "completed": false},
      {"title": "Core Concepts", "duration": "20 min", "completed": false},
      {"title": "Project Practice", "duration": "30 min", "completed": false},
    ];
  }


  void _toggleLessonComplete(int index) {
    setState(() {
      syllabus[index]['completed'] = !syllabus[index]['completed'];
    });

    // Update global progress
    final appState = context.read<AppState>();
    final ws = widget.workshop;

    appState.enrollWorkshop({
      ...ws,
      "progress": syllabus,
    });
  }

  @override
  Widget build(BuildContext context) {
    final ws = widget.workshop;
    final theme = Theme.of(context);
    final isTeach4Learn = ws['type'] == 'Teach4Learn';

    final completedCount =
        syllabus.where((item) => item['completed']).length;
    final progressPercent = syllabus.isEmpty
        ? 0.0
        : completedCount / syllabus.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isTeach4Learn
              ? (ws['title'] ?? 'Skill Exchange')
              : (ws['title'] ?? 'Workshop Details'),
        ),
        actions: [
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

// --- About Section ---
          _aboutCard(ws, theme, isTeach4Learn),

          const SizedBox(height: 20),

// --- Syllabus ---
          if ((ws['syllabus'] ?? []).isNotEmpty)
            _syllabusCard(theme, progressPercent),

          const SizedBox(height: 20),

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
      // 👇 Normal workshops stay as-is
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16), // ✅ named parameter
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

    // 👇 Teach4Learn layout: skill exchange information
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16), // ✅ named parameter
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Skill Exchange Details",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // 🎯 Skill the user wants to learn
            if (ws['skillRequested'] != null &&
                ws['skillRequested'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6), // ✅ fixed here too
                child: Row(
                  children: [
                    const Icon(Icons.school, color: Colors.deepPurple, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Wants to learn: ${ws['skillRequested']}",
                        style: theme.textTheme.bodyMedium!
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // 🧠 Skill the user can teach in return
            if (ws['skillOffered'] != null &&
                ws['skillOffered'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6), // ✅ fixed here too
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Can teach: ${ws['skillOffered']}",
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

  Widget _syllabusCard(ThemeData theme, double progressPercent) {
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
                      GestureDetector(
                        onTap: () => _toggleLessonComplete(index),
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
    final isCreator = ws['creatorId'] == 'currentUser'; // 👈 check who made it

    // --- if creator, disable the enroll button ---
    if (isCreator) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            // 📝 EDIT BUTTON
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text("Edit"),
                onPressed: () async {
                  // 🧭 Navigate to CreateWorkshopScreen in edit mode
                  final updatedWorkshop = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateWorkshopScreen(
                        existingWorkshop: ws,
                        isEditing: true,
                      ),
                    ),
                  );

                  // ✅ Refresh detail screen after editing
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

            // 🗑️ DELETE BUTTON
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

                  // ✅ Only delete & navigate back if confirmed
                  if (confirm == true) {
                    context.read<AppState>().deleteWorkshop(ws['id']);
                    Navigator.pop(context); // Close details screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Workshop deleted 🗑️")),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      );
    }




    // --- otherwise show enroll/un-enroll button ---
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: isEnrolled
              ? theme.colorScheme.secondary
              : theme.colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        onPressed: () {
          setState(() => isEnrolled = !isEnrolled);
          final appState = context.read<AppState>();

          if (isEnrolled) {
            appState.enrollWorkshop({
              ...widget.workshop,
              "progress": syllabus,
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isTeach4Learn
                    ? "Exchange request sent! 🎯"
                    : "Successfully enrolled!"),
              ),
            );
          } else {
            appState.unenrollWorkshop(widget.workshop["title"]);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isTeach4Learn
                    ? "Exchange request withdrawn"
                    : "Unenrolled from workshop"),
              ),
            );
          }
        },
        child: Text(
          isTeach4Learn
              ? (isEnrolled ? "Request Sent ✓" : "Send Exchange Request")
              : (isEnrolled ? "Enrolled ✓" : "Enroll Now"),
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
