import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart'; // ✅ Make sure the path matches your project structure

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  final Function(UserModel) onUpdate;

  const EditProfileScreen({
    super.key,
    required this.user,
    required this.onUpdate,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form controllers
  late TextEditingController nameCtrl,
      emailCtrl,
      phoneCtrl,
      bioCtrl,
      universityCtrl,
      majorCtrl,
      locationCtrl,
      websiteCtrl;
  String academicYear = "";

  late TextEditingController instagramCtrl, twitterCtrl, linkedinCtrl, githubCtrl;

  List<String> skillsToTeach = [];
  List<String> skillsToLearn = [];
  final TextEditingController newSkillTeachCtrl = TextEditingController();
  final TextEditingController newSkillLearnCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // ✅ Initialize form fields from UserModel
    final u = widget.user;
    nameCtrl = TextEditingController(text: u.name);
    emailCtrl = TextEditingController(text: u.email);
    phoneCtrl = TextEditingController(text: u.phone ?? "");
    bioCtrl = TextEditingController(text: u.bio ?? "");
    universityCtrl = TextEditingController(text: u.university ?? "");
    majorCtrl = TextEditingController(text: u.major ?? "");
    academicYear = u.year ?? "";
    locationCtrl = TextEditingController(text: u.location ?? "");
    websiteCtrl = TextEditingController(text: u.website ?? "");

    instagramCtrl = TextEditingController(text: u.social["instagram"] ?? "");
    twitterCtrl = TextEditingController(text: u.social["twitter"] ?? "");
    linkedinCtrl = TextEditingController(text: u.social["linkedin"] ?? "");
    githubCtrl = TextEditingController(text: u.social["github"] ?? "");

    skillsToTeach = List<String>.from(u.skillsToTeach);
    skillsToLearn = List<String>.from(u.skillsToLearn);
  }

  void saveProfile() async {
    print("▶ SAVE PRESSED");

    final updatedUser = widget.user.copyWith(
      name: nameCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      bio: bioCtrl.text.trim().isEmpty ? null : bioCtrl.text.trim(),
      university: universityCtrl.text.trim().isEmpty ? null : universityCtrl.text.trim(),
      major: majorCtrl.text.trim().isEmpty ? null : majorCtrl.text.trim(),
      year: academicYear.isEmpty ? null : academicYear,
      location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
      website: websiteCtrl.text.trim().isEmpty ? null : websiteCtrl.text.trim(),
      skillsToTeach: skillsToTeach,
      skillsToLearn: skillsToLearn,
      social: {
        "instagram": instagramCtrl.text.trim(),
        "twitter": twitterCtrl.text.trim(),
        "linkedin": linkedinCtrl.text.trim(),
        "github": githubCtrl.text.trim(),
      },
    );

    print("▶ SENDING TO SUPABASE:");
    print(updatedUser.toJson());

    final response = await Supabase.instance.client
        .from('users')
        .update({
      'name': updatedUser.name,
      'phone': updatedUser.phone,
      'bio': updatedUser.bio,
      'university': updatedUser.university,
      'major': updatedUser.major,
      'year': updatedUser.year,
      'location': updatedUser.location,
      'website': updatedUser.website,
      'avatar_url': updatedUser.avatarUrl,  // Correctly using avatar_url
      'skills_to_teach': updatedUser.skillsToTeach,
      'skills_to_learn': updatedUser.skillsToLearn,
      'social': updatedUser.social,
    })
        .eq('id', updatedUser.id)
        .select()
        .single();

    print("▶ SUPABASE RESPONSE:");
    print(response);

    widget.onUpdate(updatedUser);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated!")),
    );

    Navigator.pop(context, updatedUser);
  }



  Widget _buildChipList(List<String> items, Function(String) onRemove) {
    return Wrap(
      spacing: 6,
      children: items.map((s) {
        return Chip(
          label: Text(s),
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: () => setState(() => onRemove(s)),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Edit Profile"),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: saveProfile),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Basic Info"),
            Tab(text: "Skills"),
            Tab(text: "Social"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- BASIC INFO ---
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                      child: Text(
                        nameCtrl.text.isNotEmpty ? nameCtrl.text[0] : "U",
                        style: TextStyle(
                          fontSize: 28,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Avatar upload not implemented")),
                        );
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Change Photo"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Full Name")),
              TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: "Email (cannot change)"),
              enabled: false,
              ),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Phone")),
              TextField(controller: bioCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Bio")),
              const Divider(height: 30),
              TextField(controller: universityCtrl, decoration: const InputDecoration(labelText: "University")),
              TextField(controller: majorCtrl, decoration: const InputDecoration(labelText: "Major")),
              DropdownButtonFormField<String>(
                initialValue: academicYear.isEmpty ? null : academicYear,
                decoration: const InputDecoration(labelText: "Academic Year"),
                items: ["Freshman", "Sophomore", "Junior", "Senior", "Graduate", "PhD"]
                    .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                    .toList(),
                onChanged: (val) => setState(() => academicYear = val ?? ""),
              ),
              TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: "Location")),
              TextField(controller: websiteCtrl, decoration: const InputDecoration(labelText: "Website")),
            ],
          ),

          // --- SKILLS ---
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text("Skills I Can Teach", style: TextStyle(fontWeight: FontWeight.bold)),
              _buildChipList(skillsToTeach, (s) => skillsToTeach.remove(s)),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: newSkillTeachCtrl,
                          decoration: const InputDecoration(hintText: "Add skill"))),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final skill = newSkillTeachCtrl.text.trim();
                      if (skill.isNotEmpty && !skillsToTeach.contains(skill)) {
                        setState(() => skillsToTeach.add(skill));
                        newSkillTeachCtrl.clear();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text("Skills I Want to Learn", style: TextStyle(fontWeight: FontWeight.bold)),
              _buildChipList(skillsToLearn, (s) => skillsToLearn.remove(s)),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: newSkillLearnCtrl,
                          decoration: const InputDecoration(hintText: "Add skill"))),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final skill = newSkillLearnCtrl.text.trim();
                      if (skill.isNotEmpty && !skillsToLearn.contains(skill)) {
                        setState(() => skillsToLearn.add(skill));
                        newSkillLearnCtrl.clear();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),

          // --- SOCIAL ---
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(controller: instagramCtrl, decoration: const InputDecoration(labelText: "Instagram")),
              TextField(controller: twitterCtrl, decoration: const InputDecoration(labelText: "Twitter")),
              TextField(controller: linkedinCtrl, decoration: const InputDecoration(labelText: "LinkedIn")),
              TextField(controller: githubCtrl, decoration: const InputDecoration(labelText: "GitHub")),
              const Divider(height: 30),
              const Text("Contact Preferences", style: TextStyle(fontWeight: FontWeight.bold)),
              const ListTile(
                leading: Icon(Icons.mail, color: Colors.blue),
                title: Text("Email"),
                trailing: Chip(label: Text("Always")),
              ),
              const ListTile(
                leading: Icon(Icons.phone, color: Colors.green),
                title: Text("Phone"),
                trailing: Chip(label: Text("On Request")),
              ),
              const ListTile(
                leading: Icon(Icons.public, color: Colors.purple),
                title: Text("Social Media"),
                trailing: Chip(label: Text("Public")),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
