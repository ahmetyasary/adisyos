import 'package:adisyos/features/auth/domain/entities/auth_user.dart';
import 'package:adisyos/models/app_role.dart';

/// Contract — the data layer must fulfil all of these.
abstract interface class AuthRepository {
  /// Signs in with [email] + [password], fetches the role,
  /// and returns a fully populated [AuthUser].
  Future<AuthUser> login({
    required String email,
    required String password,
  });

  /// Signs out and clears all local state.
  Future<void> logout();

  /// Returns the cached [AuthUser] without a network call.
  /// Returns `null` if no session is active.
  AuthUser? getCurrentUser();

  /// Fetches the role for [userId] directly from the database.
  Future<AppRole?> getUserRole(String userId);
}
