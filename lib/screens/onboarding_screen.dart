import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/custom_button.dart';
import '../models/user_model.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  final TextEditingController _name = TextEditingController();
  final List<String> _skills = [
    "Programming",
    "Design",
    "Marketing",
    "Music",
    "Languages"
  ];
  final Set<String> _selectedSkills = {};

  void _finishOnboarding(BuildContext context) {
    final user = UserModel(
      id: "u1",
      name: _name.text.isEmpty ? "New User" : _name.text,
      email: "guest@skillx.app",
    );
    context.read<AppState>().setUser(user);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Onboarding completed!")),
    );

    Navigator.pushReplacementNamed(context, '/auth');
  }

  Widget _buildPage({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          child,
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final pages = [
      _buildPage(
        title: "Welcome to SkillX",
        subtitle: "Your journey to learning and teaching starts here.",
        child: Icon(Icons.rocket_launch,
            size: 100, color: theme.colorScheme.primary),
      ),
      _buildPage(
        title: "Tell us your name",
        subtitle: "So we can personalize your experience.",
        child: TextField(
          controller: _name,
          decoration: const InputDecoration(
            hintText: "Enter your name",
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
      ),
      _buildPage(
        title: "Choose your interests",
        subtitle: "Select what you want to learn or teach.",
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _skills.map((skill) {
            final selected = _selectedSkills.contains(skill);
            return ChoiceChip(
              label: Text(skill),
              selected: selected,
              selectedColor:
              theme.colorScheme.primary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              onSelected: (_) {
                setState(() {
                  selected
                      ? _selectedSkills.remove(skill)
                      : _selectedSkills.add(skill);
                });
              },
            );
          }).toList(),
        ),
      ),
      _buildPage(
        title: "Ready to explore?",
        subtitle:
        "You're all set up, ${_name.text.isEmpty ? "friend" : _name.text}!",
        child: Icon(Icons.check_circle,
            size: 100, color: theme.colorScheme.secondary),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _finishOnboarding(context),
                child: Text(
                  "Skip",
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.8)),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) => pages[index],
              ),
            ),

            // Page indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                    (index) => Container(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                  width: _currentPage == index ? 12 : 8,
                  height: _currentPage == index ? 12 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
              ),
            ),

            // Next / Finish button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomButton(
                label: _currentPage == pages.length - 1 ? "Finish" : "Next",
                onPressed: () {
                  if (_currentPage == pages.length - 1) {
                    _finishOnboarding(context);
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
