import 'package:adisyos/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:adisyos/features/auth/domain/entities/auth_user.dart';
import 'package:adisyos/features/auth/domain/repositories/auth_repository.dart';
import 'package:adisyos/models/app_role.dart';

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
    final role = await _dataSource.fetchRole(supaUser.id);

    _cachedUser = AuthUser(
      id: supaUser.id,
      email: supaUser.email ?? email,
      role: role,
    );
    return _cachedUser!;
  }

  // ── logout ────────────────────────────────────────────────

  @override
  Future<void> logout() async {
    await _dataSource.signOut();
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
