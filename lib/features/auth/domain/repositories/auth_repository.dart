import 'package:orderix/features/auth/domain/entities/auth_user.dart';
import 'package:orderix/models/app_role.dart';

/// Contract — the data layer must fulfil all of these.
abstract interface class AuthRepository {
  /// Signs in with [email] + [password], fetches the role,
  /// and returns a fully populated [AuthUser].
  Future<AuthUser> login({
    required String email,
    required String password,
  });

  /// Registers a new user.
  /// Returns `true` when email confirmation is required before the first login.
  Future<bool> signUp({required String email, required String password});

  /// Signs out and clears all local state.
  Future<void> logout();

  /// Permanently deletes the current user's account and clears local state.
  /// Throws a typed [AuthException] on failure.
  Future<void> deleteAccount();

  /// Sends a password-reset email for [email].
  Future<void> resetPasswordForEmail({required String email});

  /// Updates the current user's password (recovery / authenticated session).
  Future<void> updatePassword({required String password});

  /// Changes the login password after verifying [currentPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Returns the cached [AuthUser] without a network call.
  /// Returns `null` if no session is active.
  AuthUser? getCurrentUser();

  /// Fetches the role for [userId] directly from the database.
  Future<AppRole?> getUserRole(String userId);
}
