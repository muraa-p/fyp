import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();

    final upcomingTeaching = appState.createdWorkshops
        .where((ws) => ws["status"] == "upcoming" || ws["status"] == "Teaching")
        .toList();

    final upcomingEnrolled = appState.enrolledWorkshops
        .where((ws) => ws["status"] == "upcoming" || ws["status"] == "Enrolled")
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Schedule"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (upcomingTeaching.isNotEmpty) ...[
            Text("Workshops You're Teaching",
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...upcomingTeaching.map((ws) => _WorkshopCard(ws, theme, isTeaching: true)),
            const SizedBox(height: 20),
          ],
          if (upcomingEnrolled.isNotEmpty) ...[
            Text("Workshops You're Attending",
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...upcomingEnrolled.map((ws) => _WorkshopCard(ws, theme)),
          ],
          if (upcomingTeaching.isEmpty && upcomingEnrolled.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text("No upcoming workshops",
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      "You have not scheduled or joined any upcoming workshops.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey),
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

Widget _WorkshopCard(Map ws, ThemeData theme, {bool isTeaching = false}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      title: Text(ws["title"] ?? "Untitled Workshop",
          style:
          theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(ws["date"] ?? "Date not set"),
          if (ws["instructor"] != null)
            Text("by ${ws["instructor"]}",
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
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
