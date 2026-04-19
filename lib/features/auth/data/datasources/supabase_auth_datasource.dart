import 'package:flutter/foundation.dart';
// Hide gotrue's AuthException so our sealed class wins.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:orderix/core/errors/auth_exception.dart';
import 'package:orderix/models/app_role.dart';

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

  /// Signs up a new user and assigns the default admin role when a session is
  /// available immediately (i.e. email confirmation is disabled in Supabase).
  ///
  /// Returns `true` when the user must confirm their email before logging in.
  /// In that case the role assignment is skipped here — add an `after insert on
  /// auth.users` trigger in Supabase to auto-assign the role for that flow.
  Future<bool> signUp(String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email:    email,
        password: password,
      );
      final user = response.user;
      if (user == null) throw const UnknownAuthException();

      final needsConfirmation = response.session == null;

      if (!needsConfirmation) {
        await ensureUserProfile(userId: user.id, email: email);
      }

      return needsConfirmation;
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('user already registered')) {
        throw const EmailAlreadyInUseException();
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

  /// Inserts a row into `public.users` with the admin role.
  /// Safe to call multiple times — uses ON CONFLICT DO NOTHING.
  /// Requires an active session (RLS: `auth.uid() = id`).
  Future<void> ensureUserProfile({
    required String userId,
    required String email,
  }) async {
    final roleRow = await _client
        .from('roles')
        .select('id')
        .eq('name', 'admin')
        .single();

    await _client.from('users').upsert(
      {
        'id':      userId,
        'email':   email,
        'role_id': roleRow['id'],
      },
      onConflict: 'id',
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Permanently deletes the current user via the `delete-account` Edge
  /// Function (requires service role on the server). Signs out locally
  /// afterwards so the session is cleared regardless of remote state.
  Future<void> deleteAccount() async {
    try {
      final res = await _client.functions.invoke('delete-account');
      // functions_client throws FunctionException on non-2xx, so reaching
      // here means success. Status is sanity-checked anyway.
      if (res.status >= 400) {
        throw UnknownAuthException('delete-account returned ${res.status}');
      }
      await _client.auth.signOut();
    } on FunctionException catch (e) {
      debugPrint(
        'deleteAccount FunctionException '
        'status=${e.status} reason=${e.reasonPhrase} details=${e.details}',
      );
      throw UnknownAuthException(
        'delete-account ${e.status}: ${e.details ?? e.reasonPhrase ?? ''}',
      );
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      debugPrint('deleteAccount AuthApiException ${e.statusCode} ${e.message}');
      throw UnknownAuthException(e.message);
    } catch (e, st) {
      debugPrint('deleteAccount generic error: $e\n$st');
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('connection')) {
        throw const NetworkException();
      }
      throw UnknownAuthException(e.toString());
    }
  }

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
