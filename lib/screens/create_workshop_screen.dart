import 'package:flutter/material.dart';
import '../components/custom_button.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // so AppState is visible

class CreateWorkshopScreen extends StatefulWidget {
  final Function(String)? onNavigate;

  final Map<String, dynamic>? existingWorkshop;
  final bool isEditing;

  const CreateWorkshopScreen({
    super.key,
    this.onNavigate,
    this.existingWorkshop,
    this.isEditing = false,
  });


  @override
  State<CreateWorkshopScreen> createState() => _CreateWorkshopScreenState();
}


class _CreateWorkshopScreenState extends State<CreateWorkshopScreen> {
  int currentStep = 0;

  final steps = [
    'Workshop Details',
    'Schedule & Location',
    'Content & Resources',
    'Review & Publish'
  ];

  // Shared state
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController maxParticipantsController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController newTagController = TextEditingController();
  final TextEditingController newPrereqController = TextEditingController();
  final TextEditingController newOutcomeController = TextEditingController();
  final TextEditingController skillRequestedController = TextEditingController();
  final TextEditingController newLessonTitleController = TextEditingController();
  final TextEditingController newLessonDurationController = TextEditingController();
  final TextEditingController skillOfferedController = TextEditingController();


  List<Map<String, dynamic>> syllabus = [];

  @override
  void initState() {
    super.initState();

    if (widget.isEditing && widget.existingWorkshop != null) {
      final w = widget.existingWorkshop!;
      titleController.text = w['title'] ?? '';
      descController.text = w['description'] ?? '';
      skillRequestedController.text = w['skillRequested'] ?? '';
      skillOfferedController.text = w['skillOffered'] ?? '';
      selectedWorkshopType = w['type'] ?? 'Free Workshop';
      selectedCategory = w['category'];
      selectedDifficulty = w['difficulty'];
      selectedDuration = w['duration'];
      selectedDate = w['date'] != null ? DateTime.tryParse(w['date']) : null;
      locationController.text = w['location'] ?? '';
      syllabus = List<Map<String, dynamic>>.from(w['syllabus'] ?? []);
      prerequisites = List<String>.from(w['prerequisites'] ?? []);
      outcomes = List<String>.from(w['outcomes'] ?? []);
      tags = List<String>.from(w['tags'] ?? []);
      maxParticipantsController.text = (w['participants']?.toString().split('/')?.last ?? '');
    }
  }



  String? selectedCategory;
  String? selectedDifficulty;
  String? selectedDuration;
  String? locationType = 'virtual';
  String selectedWorkshopType = 'Free Workshop'; // 👈 NEW
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  List<String> tags = [];
  List<String> prerequisites = [];
  List<String> outcomes = [];

  // Dropdown options
  final categories = [
    'Programming', 'Design', 'Languages', 'Business',
    'Soft Skills', 'Music', 'Fitness', 'Photography',
    'Writing', 'Cooking', 'Data Science', 'Marketing'
  ];
  final difficulties = ['Beginner', 'Intermediate', 'Advanced'];
  final durations = [
    '30 minutes', '1 hour', '1.5 hours', '2 hours',
    '2.5 hours', '3 hours', '4 hours', 'Full day'
  ];

  // Step control
  void nextStep() {
    if (currentStep < steps.length - 1) setState(() => currentStep++);
  }

  void prevStep() {
    if (currentStep > 0) setState(() => currentStep--);
  }

  // Utility
  void addItem(List<String> list, TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isNotEmpty && !list.contains(text)) {
      setState(() {
        list.add(text);
        controller.clear();
      });
    }
  }

  void removeItem(List<String> list, int index) {
    setState(() => list.removeAt(index));
  }

  // Step 1: Workshop Details
  Widget buildStep1() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 Workshop Type
        const Text(
          'Workshop Type',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ToggleButtons(
          borderRadius: BorderRadius.circular(12),
          isSelected: [
            selectedWorkshopType == 'Free Workshop',
            selectedWorkshopType == 'Teach4Learn'
          ],
          onPressed: (index) {
            setState(() {
              selectedWorkshopType =
              index == 0 ? 'Free Workshop' : 'Teach4Learn';
            });
          },
          selectedColor: Colors.white,
          fillColor: theme.colorScheme.primary,
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('Free Workshop'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('Teach4Learn'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 🔹 Title or Exchange Title
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: selectedWorkshopType == 'Teach4Learn'
                ? 'Exchange Title'
                : 'Workshop Title',
            hintText: selectedWorkshopType == 'Teach4Learn'
                ? 'e.g., Skill Swap: Learn Illustration for Web Dev'
                : 'e.g., Advanced Flutter Widgets',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // 🔹 Teach4Learn-specific fields
        if (selectedWorkshopType == 'Teach4Learn') ...[
          // Skill Wanted
          TextField(
            controller: skillRequestedController,
            decoration: const InputDecoration(
              labelText: 'Skill Wanted',
              hintText: 'e.g., Digital Illustration',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Skill You Can Teach
          TextField(
            controller: skillOfferedController,
            decoration: const InputDecoration(
              labelText: 'Skill You Can Teach in Return',
              hintText: 'e.g., Web Development, React, or HTML/CSS',
              border: OutlineInputBorder(),
            ),
          ),


          const SizedBox(height: 16),
        ],

        // 🔹 About / Description
        TextField(
          controller: descController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'About / Description',
            hintText:
            'Describe what participants will learn or how you’ll collaborate.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // 🔹 Category & Difficulty
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                    labelText: 'Category', border: OutlineInputBorder()),
                items: categories
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => selectedCategory = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedDifficulty,
                decoration: const InputDecoration(
                    labelText: 'Difficulty', border: OutlineInputBorder()),
                items: difficulties
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => selectedDifficulty = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 🔹 Duration & Max Participants
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedDuration,
                decoration: const InputDecoration(
                    labelText: 'Duration', border: OutlineInputBorder()),
                items: durations
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => selectedDuration = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: maxParticipantsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Max Participants',
                    hintText: 'e.g., 15',
                    border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 🔹 Tags
        Wrap(
          spacing: 6,
          children: tags
              .map((t) => Chip(
            label: Text(t),
            onDeleted: () => setState(() => tags.remove(t)),
          ))
              .toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: newTagController,
                decoration: const InputDecoration(
                  hintText: 'Add a tag...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => addItem(tags, newTagController),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => addItem(tags, newTagController),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }




  // Step 2–4 (unchanged)
  Widget buildStep2(BuildContext context) { /* same as before */
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Workshop Date', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => selectedDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(selectedDate == null
                    ? 'Select Date'
                    : '${selectedDate!.toLocal()}'.split(' ')[0]),
                const Icon(Icons.calendar_today_outlined, size: 18)
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Start Time', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: selectedTime ?? TimeOfDay.now(),
            );
            if (picked != null) setState(() => selectedTime = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(selectedTime == null
                    ? 'Select Time'
                    : selectedTime!.format(context)),
                const Icon(Icons.access_time_outlined, size: 18)
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Location Type', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: locationType == 'virtual'
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade200),
                onPressed: () => setState(() => locationType = 'virtual'),
                icon: const Icon(Icons.videocam),
                label: Text(
                  'Virtual',
                  style: TextStyle(
                    color: locationType == 'virtual'
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: locationType == 'physical'
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade200),
                onPressed: () => setState(() => locationType = 'physical'),
                icon: const Icon(Icons.location_on_outlined),
                label: Text(
                  'In-Person',
                  style: TextStyle(
                    color: locationType == 'physical'
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: locationController,
          decoration: InputDecoration(
            labelText:
            locationType == 'virtual' ? 'Platform/Tool' : 'Venue/Room',
            hintText: locationType == 'virtual'
                ? 'e.g., Zoom, Google Meet'
                : 'e.g., Library Room 201',
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Prerequisites ---
        const Text('Prerequisites', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...List.generate(prerequisites.length, (i) {
          return ListTile(
            title: Text(prerequisites[i]),
            trailing: IconButton(
                onPressed: () => removeItem(prerequisites, i),
                icon: const Icon(Icons.close)),
          );
        }),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: newPrereqController,
                decoration: const InputDecoration(
                    hintText: 'Add prerequisite', border: OutlineInputBorder()),
                onSubmitted: (_) => addItem(prerequisites, newPrereqController),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => addItem(prerequisites, newPrereqController),
              child: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // --- Learning Outcomes ---
        const Text('Learning Outcomes',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...List.generate(outcomes.length, (i) {
          return ListTile(
            title: Text(outcomes[i]),
            trailing: IconButton(
                onPressed: () => removeItem(outcomes, i),
                icon: const Icon(Icons.close)),
          );
        }),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: newOutcomeController,
                decoration: const InputDecoration(
                    hintText: 'Add learning outcome',
                    border: OutlineInputBorder()),
                onSubmitted: (_) => addItem(outcomes, newOutcomeController),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => addItem(outcomes, newOutcomeController),
              child: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // --- 🆕 Syllabus Builder ---
        const Text('Syllabus (Lesson Plan)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),

        ...List.generate(syllabus.length, (i) {
          final item = syllabus[i];
          return ListTile(
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
            ),
            title: Text(item['title']),
            subtitle: Text(item['duration']),
            trailing: IconButton(
                onPressed: () => setState(() => syllabus.removeAt(i)),
                icon: const Icon(Icons.close)),
          );
        }),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: newLessonTitleController,
                decoration: const InputDecoration(
                  hintText: 'Lesson title',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextField(
                controller: newLessonDurationController,
                decoration: const InputDecoration(
                  hintText: 'Duration',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final title = newLessonTitleController.text.trim();
                final duration = newLessonDurationController.text.trim();
                if (title.isNotEmpty && duration.isNotEmpty) {
                  setState(() {
                    syllabus.add({
                      "title": title,
                      "duration": duration,
                      "completed": false,
                    });
                    newLessonTitleController.clear();
                    newLessonDurationController.clear();
                  });
                }
              },
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }


  Widget buildStep4() { /* unchanged */
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titleController.text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(descController.text),
        const Divider(height: 24),
        Text('Type: $selectedWorkshopType'),
        if (selectedWorkshopType == 'Teach4Learn')
          Text('Skill Requested: ${skillRequestedController.text}'),
        Text('Category: $selectedCategory'),
        Text('Difficulty: $selectedDifficulty'),
        Text('Duration: $selectedDuration'),
        Text('Max Participants: ${maxParticipantsController.text}'),
      ],
    );
  }

  void handlePublish() {
    final appState = Provider.of<AppState>(context, listen: false);

    final autoDesc = selectedWorkshopType == 'Teach4Learn'
        ? (skillOfferedController.text.isNotEmpty ||
        skillRequestedController.text.isNotEmpty
        ? "Skill Exchange — I can teach ${skillOfferedController.text.isNotEmpty ? skillOfferedController.text : '[skill]'} "
        "in return for learning ${skillRequestedController.text.isNotEmpty ? skillRequestedController.text : '[skill]'}."
        : "Skill Exchange session.")
        : null;

    final newWorkshop = {
      "id": widget.isEditing
          ? widget.existingWorkshop!['id']
          : DateTime.now().millisecondsSinceEpoch.toString(),
      "title": titleController.text.isNotEmpty
          ? titleController.text
          : "Untitled Workshop",
      "description": descController.text.isNotEmpty
          ? descController.text
          : (autoDesc ?? "No description provided."),
      "category": selectedCategory ?? "General",
      "difficulty": selectedDifficulty ?? "Beginner",
      "duration": selectedDuration ?? "1 hour",
      "participants":
      "0/${maxParticipantsController.text.isNotEmpty ? maxParticipantsController.text : '10'}",
      "type": selectedWorkshopType,
      "skillRequested": skillRequestedController.text,
      "skillOffered": skillOfferedController.text,
      "date": selectedDate != null
          ? selectedDate!.toLocal().toString().split(' ')[0]
          : "TBA",
      "time": selectedTime != null ? selectedTime!.format(context) : "TBA",
      "location": locationController.text.isNotEmpty
          ? locationController.text
          : (locationType == "virtual" ? "Online" : "In-person"),
      "status": "upcoming",
      "rating": widget.isEditing
          ? (widget.existingWorkshop?['rating'] ?? 0.0)
          : 0.0,
      "creatorId": "currentUser",
      "instructor": "You",
      "image": widget.isEditing
          ? widget.existingWorkshop!['image']
          : "https://source.unsplash.com/random/800x600?${selectedCategory ?? 'workshop'}",
      "syllabus": syllabus,
      "prerequisites": prerequisites,
      "outcomes": outcomes,
      "tags": tags,
    };

    if (widget.isEditing) {
      appState.updateWorkshop(widget.existingWorkshop!['id'], newWorkshop);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workshop updated ✅')),
      );

      // ✅ Go back to previous (detail) screen after editing
      Navigator.pop(context, newWorkshop);

    } else {
      appState.addCreatedWorkshop(newWorkshop);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work!shop published 🎉')),
      );

      // ✅ If navigation callback exists, use it; otherwise just pop
      if (widget.onNavigate != null) {
        widget.onNavigate!("home");
      } else {
        Navigator.pop(context);
      }
    }
  }







  @override
  Widget build(BuildContext context) {
    final stepWidgets = [buildStep1(), buildStep2(context), buildStep3(), buildStep4()];
    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${currentStep + 1}: ${steps[currentStep]}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => currentStep == 0
              ? widget.onNavigate!('home')
              : setState(() => currentStep--),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: stepWidgets[currentStep],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (currentStep > 0)
              Expanded(
                child: CustomButton(
                  label: 'Previous',
                  onPressed: prevStep,
                  isPrimary: false,
                ),
              ),
            if (currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                label: currentStep == steps.length - 1
                    ? 'Publish Workshop'
                    : 'Continue',
                onPressed:
                currentStep == steps.length - 1 ? handlePublish : nextStep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ResourceButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade100,
          foregroundColor: Colors.black87,
          minimumSize: const Size(100, 80)),
      onPressed: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
