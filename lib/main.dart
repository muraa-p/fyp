import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/user_model.dart';
import 'themes/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

// =================================================================
// ADD THIS LINE: Create a global Supabase client
// =================================================================
final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Initialize Supabase
  await Supabase.initialize(
    url: 'https://vjmuvhkrmehmwwkrzdkk.supabase.co',          // <-- TODO: paste from Supabase project
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZqbXV2aGtybWVobXd3a3J6ZGtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3NjQyODcsImV4cCI6MjA3OTM0MDI4N30.PZw4fxDUhGxUB4f60xbDaUKb9J-g2sWHo0AfQxoEdSU', // <-- TODO: paste anon key
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

  final List<Map<String, dynamic>> _enrolledWorkshops = [];
  final List<Map<String, dynamic>> _createdWorkshops = [];

  UserModel? get user => _user;
  bool get isDarkMode => _isDarkMode;

  List<Map<String, dynamic>> get enrolledWorkshops => _enrolledWorkshops;
  List<Map<String, dynamic>> get createdWorkshops => _createdWorkshops;

  // --- User Management ---
  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  // --- Theme ---
  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  // --- Enrolled Workshops ---
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

  // --- Created Workshops ---
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

class SkillXApp extends StatelessWidget {
  const SkillXApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDarkMode;
    return MaterialApp(
      title: 'SkillX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/auth': (context) => const AuthScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const HomeScreen(),
      },
      initialRoute: '/',
    );
  }
}
