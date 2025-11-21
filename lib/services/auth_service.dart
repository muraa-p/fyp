import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // ------------------------------
  // SIGN UP — with email verification
  // ------------------------------
  Future<AuthResponse> signUp(String email, String password, {String? name}) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        "name": name ?? "New User",
      },
      emailRedirectTo: "com.example.skillx://login-callback",
    );
  }

  // ------------------------------
  // LOGIN
  // ------------------------------
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ------------------------------
  // LOGOUT
  // ------------------------------
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ------------------------------
  // CURRENT USER
  // ------------------------------
  User? get currentUser => _client.auth.currentUser;

  // ------------------------------
  // AUTH STATE CHANGES
  // ------------------------------
  Stream<AuthState> authChanges() => _client.auth.onAuthStateChange;
}
