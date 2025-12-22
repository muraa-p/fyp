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
  // UPDATE PASSWORD
  // ------------------------------

  // Add this method to your AuthService class
  Future<void> updatePassword(String currentPassword, String newPassword) async {
    try {
      // First, verify the current password by attempting to sign in
      final currentUser = _client.auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception('No authenticated user found');
      }

      // Verify current password by attempting to sign in
      await _client.auth.signInWithPassword(
        email: currentUser.email!,
        password: currentPassword,
      );

      // If sign in is successful, update the password
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw Exception('Failed to update password: ${e.toString()}');
    }
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
