import 'package:flutter/material.dart';

class ProfileSetupScreen extends StatefulWidget {
  final Map<String, dynamic> baseUser;
  const ProfileSetupScreen({super.key, required this.baseUser});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final phoneCtrl = TextEditingController();
  final universityCtrl = TextEditingController();
  final majorCtrl = TextEditingController();
  String academicYear = "";

  void finishSetup() {
    final updated = {
      ...widget.baseUser,

      // Cleaned values (null if empty)
      "phone": phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      "university":
      universityCtrl.text.trim().isEmpty ? null : universityCtrl.text.trim(),
      "major": majorCtrl.text.trim().isEmpty ? null : majorCtrl.text.trim(),
      "year": academicYear.isEmpty ? null : academicYear,

      // Ensure keys exist so Supabase doesn't break
      "skillsToTeach": widget.baseUser["skillsToTeach"] ?? [],
      "skillsToLearn": widget.baseUser["skillsToLearn"] ?? [],
      "social": widget.baseUser["social"] ?? {},
    };

    Navigator.pop(context, updated);
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Your Profile"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              "Tell us a bit more about yourself 👋",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: universityCtrl,
              decoration: const InputDecoration(
                labelText: "University",
                prefixIcon: Icon(Icons.school),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: majorCtrl,
              decoration: const InputDecoration(
                labelText: "Major / Field of Study",
                prefixIcon: Icon(Icons.book),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: academicYear.isEmpty ? null : academicYear,
              decoration: const InputDecoration(
                labelText: "Academic Year",
                prefixIcon: Icon(Icons.calendar_today),
              ),
              items: [
                "Freshman",
                "Sophomore",
                "Junior",
                "Senior",
                "Graduate",
                "PhD"
              ]
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged: (val) => setState(() => academicYear = val ?? ""),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Finish Setup"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: finishSetup,
            ),
          ],
        ),
      ),
    );
  }
}
