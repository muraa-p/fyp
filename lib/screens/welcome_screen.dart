import 'package:flutter/material.dart';
import '../components/custom_button.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));

    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleIn = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.4, 1.0, curve: Curves.elasticOut)),
    );
    _slideUp =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40),
              child: Column(
                children: [
                  // Animated header
                  SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, -0.5), end: Offset.zero)
                        .animate(
                      CurvedAnimation(
                          parent: _controller,
                          curve:
                              const Interval(0.0, 0.5, curve: Curves.easeOut)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SkillX',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                  color: Colors.black38,
                                  blurRadius: 10,
                                  offset: Offset(0, 4))
                            ],
                          ),
                        ),
                        // Removed theme toggle since we're dark-only now
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Hero card with scale + slide
                  ScaleTransition(
                    scale: _scaleIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Container(
                        padding: const EdgeInsets.all(44),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.2),
                              blurRadius: 40,
                              spreadRadius: 5,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Pulsing icon
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.9, end: 1.1),
                              duration: const Duration(seconds: 3),
                              curve: Curves.easeInOut,
                              builder: (_, val, __) => Transform.scale(
                                scale: val,
                                child: const Icon(Icons.school_rounded,
                                    size: 110, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 36),
                            const Text(
                              'Learn. Teach. Connect.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.3,
                                shadows: [
                                  Shadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                      offset: Offset(0, 4))
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Workshops, CV building, skills sharing — all in one app.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(0.85),
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Buttons with entrance animation
                  SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.5), end: Offset.zero)
                        .animate(
                      CurvedAnimation(
                          parent: _controller,
                          curve:
                              const Interval(0.7, 1.0, curve: Curves.easeOut)),
                    ),
                    child: Column(
                      children: [
                        CustomButton(
                          label: 'Get Started',
                          onPressed: () =>
                              Navigator.pushNamed(context, '/onboarding'),
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          label: 'Sign in',
                          isPrimary: false,
                          onPressed: () =>
                              Navigator.pushNamed(context, '/auth'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
