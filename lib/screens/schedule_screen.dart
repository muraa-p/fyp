import 'package:flutter/material.dart';
import 'workshop_detail_screen.dart';

class ScheduleScreen extends StatelessWidget {
  final List<Map<String, dynamic>> upcomingWorkshops; // Enrolled (Attending)
  final List<Map<String, dynamic>> teachingWorkshops; // Created (Teaching)

  const ScheduleScreen({
    super.key,
    required this.upcomingWorkshops,
    required this.teachingWorkshops,
  });

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Date TBD';
    try {
      final date = DateTime.parse(isoString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final workshopDate = DateTime(date.year, date.month, date.day);

      if (workshopDate == today) return 'Today';
      if (workshopDate == tomorrow) return 'Tomorrow';
      if (date.year == now.year) {
        return '${date.day} ${_monthName(date.month)}';
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final allEmpty = teachingWorkshops.isEmpty && upcomingWorkshops.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Schedule"),
      ),
      body: allEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 20),
              Text(
                "No scheduled workshops",
                style: theme.textTheme.titleLarge?.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                "Join or create workshops to see them here",
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Teaching Workshops (your own)
          if (teachingWorkshops.isNotEmpty) ...[
            Text(
              "Workshops You're Teaching",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...teachingWorkshops.map((ws) => _WorkshopCard(
              workshop: ws,
              context: context,
              isTeaching: true,
            )),
            const SizedBox(height: 24),
          ],

          // Attending Workshops (enrolled in others)
          if (upcomingWorkshops.isNotEmpty) ...[
            Text(
              "Workshops You're Attending",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 12),
            ...upcomingWorkshops.map((ws) => _WorkshopCard(
              workshop: ws,
              context: context,
              isTeaching: false,
            )),
          ],
        ],
      ),
    );
  }
}

Widget _WorkshopCard({
  required Map<String, dynamic> workshop,
  required BuildContext context,
  required bool isTeaching,
}) {
  final theme = Theme.of(context);

  final title = workshop['title']?.toString() ?? 'Untitled Workshop';
  final dateStr = workshop['date']?.toString();
  final time = workshop['time']?.toString();
  final formattedDate = const ScheduleScreen(upcomingWorkshops: [], teachingWorkshops: [])._formatDate(dateStr);

  // Get creator name safely (from joined users table)
  final creatorMap = workshop['users'] as Map<String, dynamic>?;
  final creatorName = creatorMap?['name']?.toString() ?? 'Unknown Instructor';

  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkshopDetailScreen(workshop: workshop),
          ),
        );
      },
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(formattedDate, style: const TextStyle(fontSize: 14)),
              if (time != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(time, style: const TextStyle(fontSize: 14)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (!isTeaching)
            Text(
              "by $creatorName",
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isTeaching
              ? theme.colorScheme.primary.withOpacity(0.15)
              : theme.colorScheme.secondary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isTeaching ? "Teaching" : "Enrolled",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isTeaching ? theme.colorScheme.primary : theme.colorScheme.secondary,
          ),
        ),
      ),
    ),
  );
}