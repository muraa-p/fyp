import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

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
  Future<void> updatePassword(String currentPassword, String newPassword) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception('No authenticated user found');
      }

      await _client.auth.signInWithPassword(
        email: currentUser.email!,
        password: currentPassword,
      );

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

  // --- Deletion Flow Methods ---

  String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return String.fromCharCodes(Iterable.generate(
        32, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // Request account deletion
  Future<void> requestAccountDeletion() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final token = _generateToken();
      final expiresAt = DateTime.now().add(const Duration(days: 3));

      // Store the token in the database
      await _client.from('deletion_tokens').insert({
        'user_id': user.id,
        'token': token,
        'expires_at': expiresAt.toIso8601String(),
      });

      // NOTE: The actual email is sent by a secure Edge Function.
      // Your Flutter app should only show a success message.
    } catch (e) {
      throw Exception('Failed to request account deletion: ${e.toString()}');
    }
  }

  // Verify deletion token
  Future<Map<String, dynamic>?> verifyDeletionToken(String token) async {
    try {
      final response = await _client
          .from('deletion_tokens')
          .select('user_id, expires_at')
          .eq('token', token)
          .single();

      if (response == null) {
        return null;
      }

      final expiresAt = DateTime.parse(response['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) {
        return null;
      }

      return response;
    } catch (e) {
      return null;
    }
  }

  // Confirm account deletion with password
  Future<void> confirmAccountDeletion(String password, String token) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Verify the token is valid
      final tokenData = await verifyDeletionToken(token);
      if (tokenData == null) {
        throw Exception('Invalid or expired deletion link');
      }

      // Verify the user's password for security
      await _client.auth.signInWithPassword(
        email: user.email!,
        password: password,
      );

      print('Password re-auth successful. Now calling delete function...');

      // Call the secure Edge Function to perform the final deletion
      await _deleteUserAccount();  // Only call once, here

    } catch (e) {
      print('Deletion flow error: $e');
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }



  // Delete user account by calling a secure Edge Function
  Future<void> _deleteUserAccount() async {
    try {
      final session = _client.auth.currentSession;

      if (session == null) {
        throw Exception('No session found - user not logged in');
      }
      if (session.accessToken.isEmpty) {
        throw Exception('Access token is empty');
      }

      print('=== Attempting to delete account ===');
      print('User ID: ${session.user?.id}');
      print('User email: ${session.user?.email}');
      print('Access token starts with: ${session.accessToken.substring(0, 30)}...');
      print('Token length: ${session.accessToken.length}');

      final response = await _client.functions.invoke(
        'delete-account',
        method: HttpMethod.post,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',  // Add this too
        },
        body: {},  // Empty body is fine
      );

      print('✅ Invoke SUCCESS');
      print('Status: ${response.status}');
      print('Data: ${response.data}');
    } on FunctionException catch (e) {
      print('❌ FunctionException caught');
      print('Status: ${e.status}');
      print('Details: ${e.details}');  // This already covers the error message
      rethrow;
    } catch (e, stackTrace) {
      print('❌ Unexpected error during invoke: $e');
      print('Type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}