import 'dart:ui';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final navItems = [
      {
        "id": "home",
        "icon": Icons.home_outlined,
        "filled": Icons.home,
        "label": "Home"
      },
      {
        "id": "search",
        "icon": Icons.search_outlined,
        "filled": Icons.search,
        "label": "Explore"
      },
      {
        "id": "create",
        "icon": Icons.add_circle_outline,
        "filled": Icons.add_circle,
        "label": "Create"
      },
      {
        "id": "chat",
        "icon": Icons.chat_bubble_outline,
        "filled": Icons.chat_bubble,
        "label": "Chat",
        "badge": 2
      },
      {
        "id": "profile",
        "icon": Icons.person_outline,
        "filled": Icons.person,
        "label": "Profile"
      },
    ];

    final int currentIndex =
        navItems.indexWhere((item) => item["id"] == currentScreen);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: theme.colorScheme.surface.withOpacity(0.9),
            child: Row(
              children: navItems.asMap().entries.map((entry) {
                final int index = entry.key;
                final item = entry.value;
                final bool isActive = currentIndex == index;
                final bool hasBadge = item["badge"] != null;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onNavigate(item["id"] as String),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 76,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutBack,
                                transform: Matrix4.translationValues(
                                    0, isActive ? -4 : 0, 0),
                                child: Icon(
                                  isActive
                                      ? item["filled"] as IconData
                                      : item["icon"] as IconData,
                                  size: 28,
                                  color: isActive
                                      ? theme.colorScheme.primary
                                      : Colors.grey.shade500,
                                ),
                              ),
                              if (hasBadge)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                        )
                                      ],
                                    ),
                                    child: Text(
                                      "${item["badge"]}",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item["label"] as String,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight:
                                  isActive ? FontWeight.w700 : FontWeight.w500,
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
