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

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
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

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildPage(
      {required String title,
      required String subtitle,
      required Widget child}) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(scale: _pulseAnimation, child: child),
          const SizedBox(height: 48),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.85),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildPage(
        title: "Welcome to SkillX 🚀",
        subtitle: "Your journey to learning and teaching starts here.",
        child: Icon(Icons.rocket_launch_rounded,
            size: 140, color: Colors.blue.shade400),
      ),
      _buildPage(
        title: "What's your name?",
        subtitle: "We'll use this to personalize your experience.",
        child: TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: "Enter your name",
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
            prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none),
          ),
        ),
      ),
      _buildPage(
        title: "Choose your interests",
        subtitle: "Pick skills you'd love to learn or teach.",
        child: Wrap(
          spacing: 12,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: _skills.map((skill) {
            final selected = _selectedSkills.contains(skill);
            return FilterChip(
              label: Text(skill),
              selected: selected,
              selectedColor: const Color(0xFF60A5FA).withOpacity(0.3),
              backgroundColor: Colors.white.withOpacity(0.1),
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              labelStyle: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              checkmarkColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onSelected: (_) {
                setState(() => selected
                    ? _selectedSkills.remove(skill)
                    : _selectedSkills.add(skill));
              },
            );
          }).toList(),
        ),
      ),
      _buildPage(
        title: "You're all set! 🎉",
        subtitle:
            "Welcome aboard, ${_name.text.isEmpty ? "friend" : _name.text.trim()}!",
        child: Icon(Icons.sentiment_very_satisfied_rounded,
            size: 140, color: Colors.green.shade400),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () => _finishOnboarding(context),
                  child: Text("Skip",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 16)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: _currentPage == i ? 30 : 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? Colors.blue.shade400
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 50),
              child: CustomButton(
                label: _currentPage == pages.length - 1 ? "Let's Go!" : "Next",
                onPressed: () {
                  if (_currentPage == pages.length - 1) {
                    _finishOnboarding(context);
                  } else {
                    _controller.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _finishOnboarding(BuildContext context) {
    final user = UserModel(
      id: "u1",
      name: _name.text.isEmpty ? "New User" : _name.text,
      email: "guest@skillx.app",
    );
    context.read<AppState>().setUser(user);
    Navigator.pushReplacementNamed(context, '/auth');
  }
}
