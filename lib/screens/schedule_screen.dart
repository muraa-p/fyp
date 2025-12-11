import 'package:flutter/material.dart';
import 'workshop_detail_screen.dart';

class ScheduleScreen extends StatelessWidget {
  final List<Map<String, dynamic>> upcomingWorkshops;
  final List<Map<String, dynamic>> teachingWorkshops;

  const ScheduleScreen({
    super.key,
    required this.upcomingWorkshops,
    required this.teachingWorkshops,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Schedule"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (teachingWorkshops.isNotEmpty) ...[
            Text(
              "Workshops You're Teaching",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...teachingWorkshops.map((ws) => _WorkshopCard(ws, context, isTeaching: true)),
            const SizedBox(height: 20),
          ],
          if (upcomingWorkshops.isNotEmpty) ...[
            Text(
              "Workshops You're Attending",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...upcomingWorkshops.map((ws) => _WorkshopCard(ws, context)),
          ],
          if (teachingWorkshops.isEmpty && upcomingWorkshops.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      "No upcoming workshops",
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "You have not scheduled or joined any upcoming workshops.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _WorkshopCard(Map<String, dynamic> ws, BuildContext context, {bool isTeaching = false}) {
  final theme = Theme.of(context);

  // Safely parse the date
  DateTime? date;
  try {
    if (ws['date'] != null && ws['date'].toString().isNotEmpty) {
      date = DateTime.parse(ws['date'].toString());
    }
  } catch (e) {
    print('Error parsing date for workshop ${ws['id']}: $e');
  }

  final time = ws['time']?.toString();

  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkshopDetailScreen(workshop: ws),
          ),
        );
      },
      title: Text(
        ws["title"]?.toString() ?? "Untitled Workshop",
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          if (date != null)
            Text("${date.day}/${date.month}/${date.year}"),
          if (time != null)
            Text(time),
          if (ws["creator_id"] != null)
            Text(
              "by ${ws["creator_id"]}",
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
        ],
      ),
      trailing: Chip(
        label: Text(
          isTeaching ? "Teaching" : "Enrolled",
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: isTeaching
            ? theme.colorScheme.primary.withOpacity(0.15)
            : theme.colorScheme.secondary.withOpacity(0.15),
      ),
    ),
  );
}