import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skillx/screens/delete_account_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart'; // Correct import

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

  // Persistent toggle
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

    // Immediately start/stop global listener
    final listener = WorkshopListenerService();
    if (enabled) {
      listener.startListening();
    } else {
      listener.stopListening();
    }
  }

  // Workshop lists...
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
  late final AppLinks _appLinks; // AppLinks instance
  StreamSubscription<Uri>? _sub; // Correct subscription type

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks(); // Initialize AppLinks
    _handleDeepLinks();
    _workshopListener = WorkshopListenerService();

    // Listen to auth changes
    supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        if (session?.user != null) {
          final appState = Provider.of<AppState>(context, listen: false);
          await appState.loadNewWorkshopAlerts();

          if (appState.newWorkshopAlertsEnabled) {
            _workshopListener.startListening();
          }
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _workshopListener.stopListening();
      }
    });
  }

  void _handleDeepLinks() async {
    // Check if app was opened from a deep link
    final uri = await _appLinks.getInitialLink();
    if (uri != null) {
      _handleDeletionLink(uri);
    }

    // Listen for future deep links while the app is running
    _sub = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeletionLink(uri);
      }
    }, onError: (err) {
      // Handle exception by printing a message
      print('Error receiving app link: $err');
    });
  }

  void _handleDeletionLink(Uri uri) {
    if (uri.path == '/delete-account') {
      final token = uri.queryParameters['token'];
      if (token != null) {
        // Ensure navigator is ready before pushing
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigatorKey.currentContext != null) {
            Navigator.of(navigatorKey.currentContext!).pushNamed(
              '/delete-account',
              arguments: {'token': token},
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _workshopListener.stopListening();
    _sub?.cancel(); // Correctly cancel the subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDarkMode;
    return MaterialApp(
      title: 'SkillX',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/auth': (context) => const AuthScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const HomeScreen(),
        '/delete-account': (context) => const DeleteAccountScreen(),
      },
      initialRoute: '/',
    );
  }
}