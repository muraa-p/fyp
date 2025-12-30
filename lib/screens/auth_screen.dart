import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/custom_button.dart';
import '../main.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'email_sent_screen.dart';
import 'profile_setup_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.4, 1.0, curve: Curves.elasticOut)),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscure : false,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      ),
    );
  }

  void _authenticate(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    //setState(() => _loading = true);

    try {
      AuthResponse response;

      if (_isLogin) {
        response = await _authService.signIn(
            _email.text.trim(), _password.text.trim());
        if (response.user == null)
          throw Exception("Invalid email or password.");
        if (response.user!.emailConfirmedAt == null) {
          await Supabase.instance.client.auth.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Please verify your email before logging in.")),
          );
          return;
        }
        final profile = await _profileService.getUserProfile(response.user!.id);
        context.read<AppState>().setUser(UserModel.fromJson(profile));
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      response = await _authService.signUp(
        _email.text.trim(),
        _password.text.trim(),
        name: _name.text.trim(),
      );

      if (response.user == null) throw Exception("Signup failed.");

      bool verified = false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Verify Your Email"),
            content: const Text(
              "We’ve sent a verification link to your email.\n\n"
              "After clicking it, tap the button below.",
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  try {
                    final login =
                        await Supabase.instance.client.auth.signInWithPassword(
                      email: _email.text.trim(),
                      password: _password.text.trim(),
                    );
                    if (login.user?.emailConfirmedAt != null) {
                      verified = true;
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                "Email not verified yet. Check your inbox.")),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Verification pending. Try again.")),
                    );
                  }
                },
                child: const Text("I HAVE VERIFIED"),
              ),
            ],
          ),
        ),
      );

      if (!verified) return;

      final baseUser = {
        "id": response.user!.id,
        "name": _name.text.trim(),
        "email": _email.text.trim(),
        "bio": "",
        "university": "",
        "major": "",
        "year": "",
        "location": "",
        "website": "",
        "avatar_url": "",
        "skills_to_teach": [],
        "skills_to_learn": [],
      };

      await _profileService.createUserProfile(baseUser);

      final updatedUser = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(baseUser: baseUser)),
      );

      if (updatedUser != null) {
        await _profileService.updateUserProfile(updatedUser);
        context.read<AppState>().setUser(UserModel.fromJson(updatedUser));
      } else {
        context.read<AppState>().setUser(UserModel.fromJson(baseUser));
      }

      Navigator.pushReplacementNamed(context, '/home');
    } catch (error) {
      String errorMessage = error.toString();

      if (errorMessage.contains('Only university emails')) {
        errorMessage =
            'Only APU university emails (@mail.apu.edu.my) are allowed to sign up.';
      } else if (errorMessage.contains('Invalid email or password')) {
        errorMessage = 'Invalid email or password. Please try again.';
      } else if (errorMessage.contains('Email not confirmed')) {
        errorMessage = 'Please verify your email first.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context, // ← this is AuthScreen's context (good)
      builder: (dialogContext) => AlertDialog( // ← use a different name here
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Reset Password",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: _buildTextField(
            emailController,
            "Enter your email",
            Icons.email_outlined,
            validator: _validateEmail,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF60A5FA),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              Navigator.pop(dialogContext); // close dialog using dialogContext

              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(
                  emailController.text.trim(),
                  redirectTo: "skillx://login-callback",
                );

                if (mounted) {
                  // Use the outer context (AuthScreen's context)
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EmailSentScreen(email: emailController.text.trim()),
                    ),
                  );
                }
              } catch (e) {
                String message = "Failed to send reset email.";
                if (e.toString().contains("rate limit")) {
                  message = "Too many requests. Try again later.";
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text("Send Reset Link"),
          ),
        ],
      ),
    );
  }

  String? _validateEmail(String? v) => v?.isEmpty ?? true
      ? 'Email required'
      : (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)
          ? 'Invalid email'
          : null);
  String? _validatePassword(String? v) => v?.isEmpty ?? true
      ? 'Password required'
      : (v!.length < 6 ? 'Min 6 characters' : null);
  String? _validateName(String? v) =>
      !_isLogin && (v?.trim().isEmpty ?? true) ? 'Name required' : null;

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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 5,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Pulsing logo
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.9, end: 1.15),
                              duration: const Duration(seconds: 3),
                              curve: Curves.easeInOut,
                              builder: (_, val, __) => Transform.scale(
                                scale: val,
                                child: const Icon(Icons.auto_awesome_rounded,
                                    size: 90, color: Color(0xFF60A5FA)),
                              ),
                            ),
                            const SizedBox(height: 32),

                            Text(
                              _isLogin ? "Welcome Back 👋" : "Join SkillX ✨",
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isLogin
                                  ? "Continue your learning journey"
                                  : "Let's get you started!",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white.withOpacity(0.85)),
                            ),
                            const SizedBox(height: 48),

                            if (!_isLogin) ...[
                              _buildTextField(
                                  _name, "Full Name", Icons.person_outline,
                                  validator: _validateName),
                              const SizedBox(height: 20),
                            ],
                            _buildTextField(
                                _email, "Email", Icons.email_outlined,
                                validator: _validateEmail),
                            if (!_isLogin) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  "currently Only APU emails (tpxxxxx@mail.apu.edu.my) are allowed",
                                  style: TextStyle(
                                    color: Colors.white70.withOpacity(0.7),
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.start,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            const SizedBox(height: 20),
                            _buildTextField(
                                _password, "Password", Icons.lock_outline,
                                isPassword: true, validator: _validatePassword),

                            // === FORGOT PASSWORD LINK ===
                            if (_isLogin)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _showForgotPasswordDialog(),
                                  child: const Text(
                                    "Forgot password?",
                                    style: TextStyle(
                                      color: Color(0xFF60A5FA),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 48),

                            _loading
                                ? const CircularProgressIndicator(
                                color: Color(0xFF60A5FA))
                                : CustomButton(
                              label:
                              _isLogin ? "Sign In" : "Create Account",
                              onPressed: () => _authenticate(context),
                            ),

                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _isLogin = !_isLogin),
                              child: Text(
                                _isLogin
                                    ? "New here? Create an account"
                                    : "Already have an account? Sign in",
                                style: const TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
