import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skillx/screens/delete_account_screen.dart';
import 'package:skillx/screens/gamification_screen.dart';
import 'package:skillx/services/notification_service.dart';
import 'package:skillx/services/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'models/user_model.dart';
import 'themes/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'services/workshop_listener_service.dart';

final supabase = Supabase.instance.client;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://glvavlqdtxcpfurkpemq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdsdmF2bHFkdHhjcGZ1cmtwZW1xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3MTMwNzksImV4cCI6MjA4MTI4OTA3OX0.ndV5qGlTrJeBsl95TVzxCy8PZyYZbIP6RPZAeR_L-2k',
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 2,
    ),
    debug: true, // Optional: helps with debugging Supabase logs
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const SkillXApp(),
    ),
  );
}

class AppState extends ChangeNotifier {
  UserModel? _user;
  bool _isDarkMode = false;
  bool _newWorkshopAlertsEnabled = true;

  final List<Map<String, dynamic>> _enrolledWorkshops = [];
  final List<Map<String, dynamic>> _createdWorkshops = [];

  UserModel? get user => _user;
  bool get isDarkMode => _isDarkMode;
  bool get newWorkshopAlertsEnabled => _newWorkshopAlertsEnabled;

  List<Map<String, dynamic>> get enrolledWorkshops => _enrolledWorkshops;
  List<Map<String, dynamic>> get createdWorkshops => _createdWorkshops;

  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  Future<void> loadNewWorkshopAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    _newWorkshopAlertsEnabled = prefs.getBool('new_workshop_alerts') ?? true;
    notifyListeners();
  }

  Future<void> setNewWorkshopAlerts(bool enabled) async {
    _newWorkshopAlertsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('new_workshop_alerts', enabled);
    notifyListeners();

    final listener = WorkshopListenerService();
    if (enabled) {
      listener.startListening();
    } else {
      listener.stopListening();
    }
  }

  void enrollWorkshop(Map<String, dynamic> ws) {
    if (!_enrolledWorkshops.any((w) => w["title"] == ws["title"])) {
      _enrolledWorkshops.add(ws);
      notifyListeners();
    }
  }

  void unenrollWorkshop(String title) {
    _enrolledWorkshops.removeWhere((w) => w["title"] == title);
    notifyListeners();
  }

  void addCreatedWorkshop(Map<String, dynamic> ws) {
    if (!_createdWorkshops.any((w) => w["title"] == ws["title"])) {
      _createdWorkshops.add(ws);
      notifyListeners();
    }
  }

  void removeCreatedWorkshop(String title) {
    _createdWorkshops.removeWhere((w) => w["title"] == title);
    notifyListeners();
  }

  void updateWorkshop(String id, Map<String, dynamic> updatedData) {
    final index = createdWorkshops.indexWhere((w) => w['id'] == id);
    if (index != -1) {
      createdWorkshops[index] = {
        ...createdWorkshops[index],
        ...updatedData,
      };
      notifyListeners();
    }
  }

  void deleteWorkshop(String id) {
    createdWorkshops.removeWhere((w) => w['id'] == id);
    notifyListeners();
  }
}

class SkillXApp extends StatefulWidget {
  const SkillXApp({super.key});

  @override
  State<SkillXApp> createState() => _SkillXAppState();
}

class _SkillXAppState extends State<SkillXApp> {
  late final WorkshopListenerService _workshopListener;
  late final AppLinks _appLinks;
  late final NotificationService _notificationService; // Add this
  StreamSubscription<Uri>? _sub;
  bool _hasHandledRecovery = false;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _workshopListener = WorkshopListenerService();
    _notificationService = NotificationService(); // Initialize once

    // Add this to ensure deep link is handled after auth restore
    supabase.auth.onAuthStateChange.listen((data) {
      // Re-check for pending deep link after auth is loaded
      _appLinks.getInitialLink().then((uri) {
        if (uri != null) _handleDeletionLink(uri);
      });
    });

    supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      final appState = Provider.of<AppState>(context, listen: false);

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        if (session?.user != null) {
          // === NEW: Load user profile when session is restored ===
          try {
            final profileService = ProfileService();
            final profileData =
                await profileService.getUserProfile(session!.user.id);
            appState.setUser(UserModel.fromJson(profileData));
          } catch (e) {
            print('Failed to load profile on app start: $e');
            // Optional: show error or stay logged in with null user
          }
          // ======================================================

          await appState.loadNewWorkshopAlerts();

          if (appState.newWorkshopAlertsEnabled) {
            _workshopListener.startListening();
          }

          final userId = session!.user.id;

          supabase
              .from('notifications')
              .stream(primaryKey: ['id'])
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .listen((List<Map<String, dynamic>> events) async {
                for (final event in events) {
                  if (event['__op'] == 'INSERT' && event['read'] == false) {
                    final String title = event['title'] ?? 'New Notification';
                    final String? type = event['type'];
                    final String body =
                        event['body'] ?? 'You have a new notification!';

                    // Use the pre-initialized service
                    await _notificationService.showGeneralNotification(
                      id: event['id'].hashCode,
                      title: title,
                      body: body,
                      payload: event['data']?.toString(),
                      type: type,
                    );

                    // === ALSO show in-app SnackBar if app is open ===
                    if (navigatorKey.currentContext != null) {
                      ScaffoldMessenger.of(navigatorKey.currentContext!)
                          .hideCurrentSnackBar();

                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (navigatorKey.currentContext != null &&
                            navigatorKey.currentContext!.mounted) {
                          ScaffoldMessenger.of(navigatorKey.currentContext!)
                              .showSnackBar(
                            SnackBar(
                              content: Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              duration: const Duration(seconds: 6),
                              backgroundColor:
                                  Theme.of(navigatorKey.currentContext!)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                              action: SnackBarAction(
                                label: 'View',
                                textColor:
                                    Theme.of(navigatorKey.currentContext!)
                                        .colorScheme
                                        .primary,
                                onPressed: () {
                                  navigatorKey.currentState?.push(
                                    MaterialPageRoute(
                                      builder: (context) => GamificationScreen(
                                        onNavigate: (_) {},
                                        initialTab: type == 'badge' ? 1 : 0,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }
                      });
                    }

                    // Mark as read
                    supabase
                        .from('notifications')
                        .update({'read': true})
                        .eq('id', event['id'])
                        .catchError(
                            (error) => print('Failed to mark read: $error'));
                  }
                }
              });
        }
      } else if (event == AuthChangeEvent.signedOut) {
        appState.setUser(null); // Clear user on logout
        _workshopListener.stopListening();
      }
      if (event == AuthChangeEvent.passwordRecovery) {
        if (!_hasHandledRecovery) {
          _hasHandledRecovery = true;
          // Clear stack and go directly to reset screen
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
                (route) => false,
          );
        }
        return; // Stop further processing
      }

      else if (event == AuthChangeEvent.signedOut) {
      appState.setUser(null);
      _workshopListener.stopListening();
      _hasHandledRecovery = false; // Reset for next recovery
    }

    });
  }

  void _handleDeletionLink(Uri uri) {
    if (uri.path == '/delete-account') {
      final token = uri.queryParameters['token'];
      if (token != null) {
        // Wait for the first frame to ensure context is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = navigatorKey.currentContext;
          if (context != null && Navigator.canPop(context) ||
              ModalRoute.of(context!)?.isFirst == true) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const DeleteAccountScreen(),
                settings: RouteSettings(arguments: {'token': token}),
              ),
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _workshopListener.stopListening();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkillX',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const HomeScreen(),
        '/delete-account': (context) => const DeleteAccountScreen(),
      },
      home: const AuthWrapper(), // ← This replaces initialRoute
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    // Load profile immediately if already logged in on app start
    final session = supabase.auth.currentSession;
    if (session != null) {
      _loadUserProfile(session.user.id);
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    if (_isLoadingProfile) return; // Prevent double load
    setState(() => _isLoadingProfile = true);

    try {
      final profileService = ProfileService();
      final profileData = await profileService.getUserProfile(userId);
      if (mounted) {
        context.read<AppState>().setUser(UserModel.fromJson(profileData));
      }
    } catch (e) {
      print('Error loading profile in AuthWrapper: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Still waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isLoadingProfile) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        if (session != null) {
          // Session exists → go to Home
          // Profile should already be loaded from initState or listener
          return const HomeScreen();
        }

        // No session → Welcome screen
        return const WelcomeScreen();
      },
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set New Password"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            TextField(
              controller: _newPassword,
              obscureText: _obscure,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "New Password",
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmPassword,
              obscureText: _obscure,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Confirm Password",
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
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
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Also check your spam folder if you don't see the email.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF60A5FA),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: _loading ? null : () async {
                  if (_newPassword.text.trim() != _confirmPassword.text.trim()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Passwords do not match")),
                    );
                    return;
                  }
                  if (_newPassword.text.trim().length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Password must be at least 6 characters")),
                    );
                    return;
                  }

                  setState(() => _loading = true);
                  try {
                    await Supabase.instance.client.auth.updateUser(
                      UserAttributes(password: _newPassword.text.trim()),
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Password updated successfully! 🎉"),
                          backgroundColor: Colors.green,
                        ),
                      );

                      // Manually load user profile
                      final userId = Supabase.instance.client.auth.currentUser!.id;
                      try {
                        final profileService = ProfileService();
                        final profileData = await profileService.getUserProfile(userId);
                        Provider.of<AppState>(context, listen: false)
                            .setUser(UserModel.fromJson(profileData));
                      } catch (e) {
                        print("Failed to load profile after reset: $e");
                        // Continue anyway — user is logged in
                      }

                      // Go to home with clean navigation stack
                      navigatorKey.currentState?.pushNamedAndRemoveUntil(
                        '/home',
                            (route) => false,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: ${e.toString()}")),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Update Password",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
