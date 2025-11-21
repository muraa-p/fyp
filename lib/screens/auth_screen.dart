import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/custom_button.dart';
import '../main.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'profile_setup_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;

  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  // ============================================================
  // AUTHENTICATION HANDLER
  // ============================================================
  void _authenticate(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      AuthResponse response;

      // ============================================================
      // LOGIN
      // ============================================================
      if (_isLogin) {
        response = await _authService.signIn(
          _email.text.trim(),
          _password.text.trim(),
        );

        if (response.user == null) {
          throw Exception("Invalid email or password.");
        }

        // Block login if email is NOT verified
        if (response.user!.emailConfirmedAt == null) {
          Supabase.instance.client.auth.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please verify your email before logging in."),
            ),
          );
          return;
        }

        // Load profile
        final profile =
        await _profileService.getUserProfile(response.user!.id);

        context.read<AppState>().setUser(UserModel.fromJson(profile));
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      // ============================================================
      // SIGN UP
      // ============================================================
      response = await _authService.signUp(
        _email.text.trim(),
        _password.text.trim(),
        name: _name.text.trim(),
      );

      if (response.user == null) {
        throw Exception("Signup failed.");
      }

      // -----------------------------------------------------------
      // REQUIRE MANUAL EMAIL VERIFICATION (NO DEEP LINKS)
      // -----------------------------------------------------------
      bool verified = false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text("Verify Your Email"),
              content: const Text(
                  "We’ve sent a verification link to your email.\n\n"
                      "After verifying, tap the button below."),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      // Try signing in again — this will succeed ONLY if email is verified
                      final login = await Supabase.instance.client.auth.signInWithPassword(
                        email: _email.text.trim(),
                        password: _password.text.trim(),
                      );

                      if (login.user != null && login.user!.emailConfirmedAt != null) {
                        verified = true;
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Still not verified. Please confirm your email first."),
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Verification not completed yet."),
                        ),
                      );
                    }
                  },


                  child: const Text("I HAVE VERIFIED"),
                ),
              ],
            ),
          );
        },
      );

      if (!verified) return;

      // -----------------------------------------------------------
      // CREATE BASE PROFILE IN DATABASE
      // -----------------------------------------------------------
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
        "skillsToTeach": [],
        "skillsToLearn": [],
      };

      await _profileService.createUserProfile(baseUser);

      // -----------------------------------------------------------
      // GO TO PROFILE SETUP SCREEN
      // -----------------------------------------------------------
      final updatedUser = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(baseUser: baseUser),
        ),
      );

      if (updatedUser != null) {
        await _profileService.updateUserProfile(updatedUser);
        context.read<AppState>().setUser(UserModel.fromJson(updatedUser));
      } else {
        context.read<AppState>().setUser(UserModel.fromJson(baseUser));
      }

      Navigator.pushReplacementNamed(context, '/home');

    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  // ============================================================
  // VALIDATION
  // ============================================================
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Minimum 6 characters required';
    return null;
  }

  String? _validateName(String? value) {
    if (!_isLogin && (value == null || value.trim().isEmpty)) {
      return 'Full name is required';
    }
    return null;
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isLogin
                              ? "Welcome Back 👋"
                              : "Create Account ✨",
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? "Sign in to continue"
                              : "Let’s get you started on SkillX!",
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _name,
                            validator: _validateName,
                            decoration: InputDecoration(
                              labelText: "Full Name",
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        TextFormField(
                          controller: _email,
                          validator: _validateEmail,
                          decoration: InputDecoration(
                            labelText: "Email",
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _password,
                          validator: _validatePassword,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        _loading
                            ? const CircularProgressIndicator()
                            : CustomButton(
                          label: _isLogin
                              ? "Sign In"
                              : "Create Account",
                          onPressed: () => _authenticate(context),
                        ),

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () {
                            setState(() => _isLogin = !_isLogin);
                          },
                          child: Text(
                            _isLogin
                                ? "Don’t have an account? Create one"
                                : "Already have an account? Sign In",
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
    );
  }
}
