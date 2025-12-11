import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  final int completenessScore = 85;
  final List<String> suggestions = [
    "Add more project descriptions",
    "Get endorsements for Python skills",
    "Add contact information"
  ];

  final List<Map<String, dynamic>> achievements = [
    {
      "title": "Community Leader",
      "desc": "Taught 10+ workshops with 4.8+ average rating",
      "icon": "👑",
      "earned": "2024-03-10",
    },
    {
      "title": "Skill Master",
      "desc": "Endorsed in 5+ different skills",
      "icon": "🏆",
      "earned": "2024-02-28",
    },
    {
      "title": "Knowledge Seeker",
      "desc": "Completed 20+ workshops",
      "icon": "📚",
      "earned": "2024-02-15",
    }
  ];

  final List<Map<String, dynamic>> skills = [
    {
      "name": "JavaScript",
      "level": "Expert",
      "endorsements": 15,
      "taught": 8,
      "attended": 12,
      "certs": ["Advanced JavaScript Patterns", "ES6+ Mastery"],
      "projects": ["E-commerce Platform", "Task Management App"]
    },
    {
      "name": "React",
      "level": "Advanced",
      "endorsements": 12,
      "taught": 5,
      "attended": 8,
      "certs": ["React Hooks Workshop", "State Management"],
      "projects": ["Social Media Dashboard", "Learning Platform"]
    },
    {
      "name": "Python",
      "level": "Intermediate",
      "endorsements": 8,
      "taught": 3,
      "attended": 15,
      "certs": ["Python Fundamentals"],
      "projects": ["Data Analysis Tool", "Web Scraper"]
    }
  ];

  final List<Map<String, dynamic>> testimonials = [
    {
      "author": "Sarah Johnson",
      "role": "Computer Science Student",
      "text":
      "Excellent instructor with clear explanations and practical examples.",
      "rating": 5,
      "skill": "JavaScript"
    },
    {
      "author": "Michael Park",
      "role": "Web Development Student",
      "text": "Great teaching style and always willing to help.",
      "rating": 5,
      "skill": "React"
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    final createdWorkshops = appState.createdWorkshops;

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
            unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
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
                _buildExperienceTab(context, createdWorkshops),
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
                    color: theme.colorScheme.primary),
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
      {"icon": "🎓", "label": "Workshops Completed", "value": "25"},
      {"icon": "👨‍🏫", "label": "Workshops Taught", "value": "16"},
      {"icon": "🏆", "label": "Badges Earned", "value": "12"},
      {"icon": "⭐", "label": "Average Rating", "value": "4.8"},
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
            child:
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(item["icon"]!, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(item["value"]!,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(item["label"]!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7)))
            ]),
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
              "John Smith\nFull-Stack Developer & Tech Educator\n\nSkills: JavaScript (Expert), React (Advanced), Python (Intermediate)\nTeaching: 16 workshops taught, 4.8/5 rating\nAchievements: Community Leader, Skill Master",
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
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
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
                  theme.colorScheme.surface.withOpacity(0.5),
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
                  theme.colorScheme.surface.withOpacity(0.5),
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

  Widget _buildExperienceTab(BuildContext context, List<Map<String, dynamic>> created) {
    final theme = Theme.of(context);
    final hasCreated = created.isNotEmpty;

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
                  ...created.map((w) => ListTile(
                    title: Text(w["title"] ?? "Untitled",
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      "Instructor • ${w["date"] ?? 'Recently created'}",
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.link),
                      color: theme.colorScheme.primary,
                      onPressed: () => addToLinkedInProfile(w["title"] ?? "Workshop"),
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
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Testimonials & Reviews",
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...testimonials.map((t) => ListTile(
                title:
                Text(t["author"], style: theme.textTheme.bodyLarge),
                subtitle: Text("\"${t["text"]}\" — ${t["skill"]}",
                    style: theme.textTheme.bodySmall),
                trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                        5,
                            (i) => Icon(Icons.star,
                            size: 16,
                            color: i < t["rating"]
                                ? Colors.amber
                                : theme.disabledColor))),
              ))
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
            onPressed: () =>
                addToLinkedInProfile("Recent Achievements"),
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
          CustomButton(
              label: "Connect LinkedIn", onPressed: connectLinkedIn)
        ]),
      ),
    );
  }
}
