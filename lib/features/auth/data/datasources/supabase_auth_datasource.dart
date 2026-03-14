// Hide gotrue's AuthException so our sealed class wins.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:adisyos/core/errors/auth_exception.dart';
import 'package:adisyos/models/app_role.dart';

/// Low-level Supabase calls. No business logic here.
class SupabaseAuthDataSource {
  SupabaseAuthDataSource(this._client);
  final SupabaseClient _client;

  // ── Auth ──────────────────────────────────────────────────

  Future<User> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) throw const InvalidCredentialsException();
      return user;
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      if (e.statusCode == '400' || e.message.contains('Invalid login')) {
        throw const InvalidCredentialsException();
      }
      if (e.message.contains('Email not confirmed')) {
        throw const EmailNotConfirmedException();
      }
      throw UnknownAuthException(e.message);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') || msg.contains('network') || msg.contains('connection')) {
        throw const NetworkException();
      }
      throw const UnknownAuthException();
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  User? get currentUser => _client.auth.currentUser;

  // ── Role ──────────────────────────────────────────────────

  /// Fetches role from `public.users` ⟶ `roles` join.
  Future<AppRole> fetchRole(String userId) async {
    try {
      final row = await _client
          .from('users')
          .select('roles(name)')
          .eq('id', userId)
          .single();

      // Shape: { "roles": { "name": "admin" } }
      final roleName =
          (row['roles'] as Map<String, dynamic>)['name'] as String;
      return AppRoleX.fromString(roleName);
    } catch (_) {
      throw const RoleNotFoundException();
    }
  }
}
