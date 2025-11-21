import 'package:flutter/material.dart';

class EndorsementsScreen extends StatefulWidget {
  final Function(String) onNavigate;
  const EndorsementsScreen({super.key, required this.onNavigate});

  @override
  State<EndorsementsScreen> createState() => _EndorsementsScreenState();
}

class _EndorsementsScreenState extends State<EndorsementsScreen> {
  String? selectedSkill;
  final TextEditingController endorsementText = TextEditingController();

  // Dummy Data
  final List<Map<String, dynamic>> mySkills = [
    {
      "name": "JavaScript",
      "endorsements": 15,
      "level": "Expert",
      "recentEndorsers": [
        {"name": "Sarah Johnson", "avatar": "👩‍💻", "text": "Excellent teaching style and deep knowledge"},
        {"name": "Alex Chen", "avatar": "👨‍🎓", "text": "Very patient and explains concepts clearly"},
        {"name": "Emily Davis", "avatar": "👩‍🔬", "text": "Helped me understand complex JS concepts"},
      ]
    },
    {
      "name": "React",
      "endorsements": 12,
      "level": "Advanced",
      "recentEndorsers": [
        {"name": "Michael Park", "avatar": "👨‍🏫", "text": "Great at breaking down React patterns"},
        {"name": "Lisa Wong", "avatar": "👩‍💼", "text": "Practical examples and real-world projects"},
      ]
    },
    {
      "name": "Python",
      "endorsements": 8,
      "level": "Intermediate",
      "recentEndorsers": [
        {"name": "David Kim", "avatar": "👨‍💻", "text": "Good fundamentals and problem-solving approach"},
        {"name": "Anna Smith", "avatar": "👩‍🎓", "text": "Helped me with data structures"},
      ]
    },
  ];

  final List<Map<String, dynamic>> endorsementsReceived = [
    {
      "skill": "JavaScript",
      "endorser": "Sarah Johnson",
      "endorserAvatar": "👩‍💻",
      "text": "Excellent teaching style and deep knowledge of JavaScript.",
      "date": "2025-10-05",
      "rating": 5
    },
    {
      "skill": "React",
      "endorser": "Michael Park",
      "endorserAvatar": "👨‍🏫",
      "text": "Great at breaking down complex React patterns.",
      "date": "2025-10-03",
      "rating": 5
    },
  ];

  final List<Map<String, dynamic>> endorsementsGiven = [
    {
      "skill": "Data Science",
      "recipient": "Alex Chen",
      "recipientAvatar": "👨‍🎓",
      "text": "Exceptional knowledge in machine learning and data visualization.",
      "date": "2025-10-07"
    },
    {
      "skill": "Graphic Design",
      "recipient": "Emily Davis",
      "recipientAvatar": "👩‍🔬",
      "text": "Creative and professional design work with great attention to detail.",
      "date": "2025-10-01"
    },
  ];

  final List<Map<String, dynamic>> pendingEndorsements = [
    {
      "id": 1,
      "requester": "Lisa Wong",
      "avatar": "👩‍💼",
      "skill": "React",
      "workshop": "Advanced React Hooks Workshop",
      "date": "2025-10-09"
    },
    {
      "id": 2,
      "requester": "James Miller",
      "avatar": "👨‍💼",
      "skill": "JavaScript",
      "workshop": "JavaScript Fundamentals",
      "date": "2025-10-07"
    },
  ];

  // --- Actions ---
  void sendEndorsement() {
    if (selectedSkill != null && endorsementText.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Endorsement sent successfully!")),
      );
      setState(() {
        selectedSkill = null;
        endorsementText.clear();
      });
      Navigator.pop(context);
    }
  }

  void requestEndorsement(String skill) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Endorsement request sent for $skill")),
    );
  }

  void respondToEndorsement(int id, bool approve) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approve ? "Endorsement approved!" : "Endorsement declined."),
      ),
    );
    setState(() => pendingEndorsements.removeWhere((e) => e["id"] == id));
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

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Endorsements"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => widget.onNavigate("profile"),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Give Endorsement",
            onPressed: () {
              String? selectedWorkshop;

              // Dummy workshops — you can later fetch from AppState or backend
              final List<String> workshops = [
                "Flutter Advanced Widgets",
                "Intro to React Hooks",
                "JavaScript Fundamentals",
                "UI/UX Design Basics",
              ];

              showDialog(
                context: context,
                builder: (_) => StatefulBuilder(
                  builder: (context, setState) => AlertDialog(
                    title: const Text("Give Endorsement"),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Workshop dropdown
                          DropdownButtonFormField<String>(
                            value: selectedWorkshop,
                            decoration: const InputDecoration(
                              labelText: "Workshop",
                              border: OutlineInputBorder(),
                            ),
                            items: workshops
                                .map((w) =>
                                DropdownMenuItem(value: w, child: Text(w)))
                                .toList(),
                            onChanged: (val) => setState(() => selectedWorkshop = val),
                          ),
                          const SizedBox(height: 12),

                          // Skill input
                          TextField(
                            decoration: const InputDecoration(
                              labelText: "Skill",
                              hintText: "e.g., Flutter, Python, UI Design...",
                            ),
                            onChanged: (val) => selectedSkill = val,
                          ),
                          const SizedBox(height: 12),

                          // Endorsement text
                          TextField(
                            controller: endorsementText,
                            decoration: const InputDecoration(
                              labelText: "Endorsement",
                              hintText: "Write your endorsement...",
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (selectedWorkshop == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please select a workshop.")),
                            );
                            return;
                          }
                          sendEndorsement();
                        },
                        child: const Text("Send"),
                      ),
                    ],
                  ),
                ),
              );
            },

          ),
        ],
      ),

      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.thumb_up_alt_outlined), text: "Received"),
                Tab(icon: Icon(Icons.person_outline), text: "Given"),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.workspace_premium,
                                        color: Colors.amber),
                                    SizedBox(width: 8),
                                    Text(
                                      "Pending Requests",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...pendingEndorsements.map((req) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(req["avatar"],
                                          style:
                                          const TextStyle(fontSize: 24)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(req["requester"],
                                                style: const TextStyle(
                                                    fontWeight:
                                                    FontWeight.bold)),
                                            Text(
                                                "Requesting endorsement for ${req["skill"]}"),
                                            Text(
                                              "Workshop: ${req["workshop"]}",
                                              style: theme
                                                  .textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () =>
                                                respondToEndorsement(
                                                    req["id"], true),
                                            child:
                                            const Text("Approve"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                respondToEndorsement(
                                                    req["id"], false),
                                            child: const Text("Decline"),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("My Skills & Endorsements",
                                  style:
                                  TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              ...mySkills.map((s) => Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Text(s["name"],
                                                  style: const TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold)),
                                              const SizedBox(width: 8),
                                              Chip(
                                                label: Text(s["level"]),
                                                backgroundColor:
                                                getLevelColor(
                                                    s["level"]),
                                                labelStyle:
                                                const TextStyle(
                                                    color:
                                                    Colors.white),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.thumb_up,
                                                  color: Colors.blue,
                                                  size: 18),
                                              const SizedBox(width: 4),
                                              Text("${s["endorsements"]}"),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...s["recentEndorsers"]
                                          .take(2)
                                          .map<Widget>((e) => Row(
                                        children: [
                                          Text(e["avatar"]),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              "${e["name"]}: \"${e["text"]}\"",
                                              style: theme.textTheme
                                                  .bodySmall,
                                            ),
                                          ),
                                        ],
                                      )),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () => requestEndorsement(
                                            s["name"]),
                                        child:
                                        const Text("Request More"),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Recent Endorsements Received",
                                  style:
                                  TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              ...endorsementsReceived.map((e) => ListTile(
                                leading:
                                Text(e["endorserAvatar"], style: const TextStyle(fontSize: 24)),
                                title: Text(
                                    "${e["endorser"]} endorsed you for ${e["skill"]}"),
                                subtitle: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: List.generate(
                                        5,
                                            (i) => Icon(Icons.star,
                                            size: 16,
                                            color: i < e["rating"]
                                                ? Colors.amber
                                                : Colors.grey),
                                      ),
                                    ),
                                    Text("\"${e["text"]}\"",
                                        style: const TextStyle(
                                            fontStyle: FontStyle.italic)),
                                    Text(e["date"],
                                        style: theme.textTheme.bodySmall),
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
                          leading: Text(e["recipientAvatar"],
                              style: const TextStyle(fontSize: 24)),
                          title: Text(
                              "You endorsed ${e["recipient"]} for ${e["skill"]}"),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("\"${e["text"]}\"",
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic)),
                              Text(e["date"],
                                  style: theme.textTheme.bodySmall),
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
    );
  }
}
