import 'package:flutter/material.dart';

class ProfileSetupScreen extends StatefulWidget {
  final Map<String, dynamic> baseUser;
  const ProfileSetupScreen({super.key, required this.baseUser});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final phoneCtrl = TextEditingController();
  final majorCtrl = TextEditingController();
  String academicYear = "";

  @override
  void initState() {
    super.initState();
    // Pre-fill if somehow already set (though it should be from baseUser)
    phoneCtrl.text = widget.baseUser["phone"] ?? "";
    majorCtrl.text = widget.baseUser["major"] ?? "";
    academicYear = widget.baseUser["year"] ?? "";
  }

  void finishSetup() {
    final updated = {
      ...widget.baseUser,

      // Cleaned values (null if empty)
      "phone": phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      "university": "APU",  // ← Always force APU
      "major": majorCtrl.text.trim().isEmpty ? null : majorCtrl.text.trim(),
      "year": academicYear.isEmpty ? null : academicYear,

      // Ensure keys exist so Supabase doesn't break
      "skills_to_teach": widget.baseUser["skills_to_teach"] ?? [],
      "skills_to_learn": widget.baseUser["skills_to_learn"] ?? [],
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

            // === LOCKED UNIVERSITY DISPLAY WITH SHAPE ===
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: theme.inputDecorationTheme.fillColor ?? Colors.grey[900]?.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.inputDecorationTheme.enabledBorder?.borderSide.color ?? Colors.grey.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "University",
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Asia Pacific University (APU)",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.lock_outline,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "University is fixed for all students based on the email domain. (eg. @apu.edu.my)",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
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
              ].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
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