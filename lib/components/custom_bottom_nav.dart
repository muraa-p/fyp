import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final String currentScreen;
  final Function(String) onNavigate;

  const CustomBottomNav({
    super.key,
    required this.currentScreen,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final navItems = [
      {"id": "home", "icon": Icons.home_outlined, "label": "Home"},
      {"id": "search", "icon": Icons.search, "label": "Explore"},
      {"id": "create", "icon": Icons.add_circle_outline, "label": "Create"},
      {
        "id": "chat",
        "icon": Icons.chat_bubble_outline,
        "label": "Chat",
        "badge": 2
      },
      {"id": "profile", "icon": Icons.person_outline, "label": "Profile"},
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.8)),
        color: Theme.of(context).colorScheme.surface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: navItems.map((item) {
          final isActive = currentScreen == item["id"];
          final hasBadge = item["badge"] != null;

          return GestureDetector(
            onTap: () => onNavigate(item["id"] as String),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        item["icon"] as IconData,
                        size: 24,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade600,
                      ),
                      if (hasBadge)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            height: 16,
                            width: 16,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "${item["badge"]}",
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item["label"] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
