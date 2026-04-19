import 'package:orderix/core/errors/auth_exception.dart';
import 'package:orderix/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:orderix/features/auth/domain/entities/auth_user.dart';
import 'package:orderix/features/auth/domain/repositories/auth_repository.dart';
import 'package:orderix/models/app_role.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource);
  final SupabaseAuthDataSource _dataSource;

  AuthUser? _cachedUser;

  // ── login ─────────────────────────────────────────────────

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final supaUser = await _dataSource.signIn(email, password);

    AppRole role;
    try {
      role = await _dataSource.fetchRole(supaUser.id);
    } on RoleNotFoundException {
      // First login after email confirmation — profile row not yet created.
      // We have a valid session at this point so we can write it now.
      try {
        await _dataSource.ensureUserProfile(
          userId: supaUser.id,
          email:  supaUser.email ?? email,
        );
      } catch (_) {
        // ensureUserProfile can fail if the DB trigger already created the
        // row (duplicate) or if RLS blocks it — ignore and try fetchRole
        // one more time regardless.
      }
      // Second attempt — throws RoleNotFoundException if still missing.
      role = await _dataSource.fetchRole(supaUser.id);
    }

    _cachedUser = AuthUser(
      id:    supaUser.id,
      email: supaUser.email ?? email,
      role:  role,
    );
    return _cachedUser!;
  }

  // ── signUp ────────────────────────────────────────────────

  @override
  Future<bool> signUp({
    required String email,
    required String password,
  }) =>
      _dataSource.signUp(email, password);

  // ── logout ────────────────────────────────────────────────

  @override
  Future<void> logout() async {
    await _dataSource.signOut();
    _cachedUser = null;
  }

  // ── deleteAccount ─────────────────────────────────────────

  @override
  Future<void> deleteAccount() async {
    await _dataSource.deleteAccount();
    _cachedUser = null;
  }

  // ── getCurrentUser ────────────────────────────────────────

  @override
  AuthUser? getCurrentUser() {
    // Hydrate cache from Supabase session if app restarted.
    if (_cachedUser == null && _dataSource.currentUser != null) {
      // Role not yet loaded — caller must call getUserRole() to hydrate.
      return null;
    }
    return _cachedUser;
  }

  // ── getUserRole ───────────────────────────────────────────

  @override
  Future<AppRole?> getUserRole(String userId) async {
    try {
      final role = await _dataSource.fetchRole(userId);
      // Keep cache consistent when called externally.
      if (_cachedUser != null && _cachedUser!.id == userId) {
        _cachedUser = AuthUser(
          id: _cachedUser!.id,
          email: _cachedUser!.email,
          role: role,
        );
      }
      return role;
    } catch (_) {
      return null;
    }
  }
}
