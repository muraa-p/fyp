import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skillx/screens/delete_account_screen.dart';
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
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdsdmF2bHFkdHhjcGZ1cmtwZW1xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3MTMwNzksImV4cCI6MjA4MTI4OTA3OX0.ndV5qGlTrJeBsl95TVzxCy8PZyYZbIP6RPZAeR_L-2k',
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
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _handleDeepLinks();
    _workshopListener = WorkshopListenerService();

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
            final profileData = await profileService.getUserProfile(session!.user.id);
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

          // === Existing notification listener ===
          final userId = session!.user.id;

          supabase
              .from('notifications')
              .stream(primaryKey: ['id'])
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .listen((List<Map<String, dynamic>> data) {
            for (final notif in data) {
              if (notif['read'] == false) {
                ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                  SnackBar(
                    content: Text(notif['title']),
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'View',
                      onPressed: () {},
                    ),
                  ),
                );

                supabase
                    .from('notifications')
                    .update({'read': true})
                    .eq('id', notif['id']);
              }
            }
          });
        }
      } else if (event == AuthChangeEvent.signedOut) {
        appState.setUser(null); // Clear user on logout
        _workshopListener.stopListening();
      }
    });
  }

  void _handleDeepLinks() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null) {
      _handleDeletionLink(uri);
    }

    _sub = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeletionLink(uri);
      }
    }, onError: (err) {
      print('Error receiving app link: $err');
    });
  }

  void _handleDeletionLink(Uri uri) {
    if (uri.path == '/delete-account') {
      final token = uri.queryParameters['token'];
      if (token != null) {
        // Wait for the first frame to ensure context is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = navigatorKey.currentContext;
          if (context != null && Navigator.canPop(context) || ModalRoute.of(context!)?.isFirst == true) {
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
    final isDark = context.watch<AppState>().isDarkMode;

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
      home: AuthWrapper(), // ← This replaces initialRoute
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
    if (session != null && session.user != null) {
      _loadUserProfile(session.user!.id);
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
        if (snapshot.connectionState == ConnectionState.waiting || _isLoadingProfile) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        if (session != null && session.user != null) {
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