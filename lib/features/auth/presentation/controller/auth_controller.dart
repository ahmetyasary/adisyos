import 'package:get/get.dart';
// Hide Supabase's AuthUser so our domain entity wins.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser, AuthException;
import 'package:adisyos/core/errors/auth_exception.dart';
import 'package:adisyos/features/auth/domain/entities/auth_user.dart';
import 'package:adisyos/features/auth/domain/usecases/login_usecase.dart';
import 'package:adisyos/features/auth/domain/usecases/logout_usecase.dart';
import 'package:adisyos/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:adisyos/features/auth/domain/usecases/get_user_role_usecase.dart';
import 'package:adisyos/models/app_role.dart';

class AuthController extends GetxService {
  // ── Singleton access ──────────────────────────────────────
  static AuthController get to => Get.find();

  // ── Constructor injection ─────────────────────────────────
  AuthController({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required GetUserRoleUseCase getUserRoleUseCase,
  })  : _login = loginUseCase,
        _logout = logoutUseCase,
        _getCurrentUser = getCurrentUserUseCase,
        _getUserRole = getUserRoleUseCase;

  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final GetCurrentUserUseCase _getCurrentUser;
  final GetUserRoleUseCase _getUserRole;

  // ── Reactive state ────────────────────────────────────────
  final Rx<AuthUser?> user = Rx(null);
  final RxBool isLoading = false.obs;
  final RxBool isRestoringSession = true.obs;

  // ── Convenience getters ───────────────────────────────────
  bool get isAuthenticated => user.value != null;
  bool get isAdmin => user.value?.role.isAdmin ?? false;
  bool get isStaff => user.value?.role.isStaff ?? false;
  AppRole? get currentRole => user.value?.role;

  // ── Session restore on app start ──────────────────────────
  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final supaUser = Supabase.instance.client.auth.currentUser;
      if (supaUser == null) return;

      final role = await _getUserRole(supaUser.id);
      if (role == null) return;

      user.value = AuthUser(
        id: supaUser.id,
        email: supaUser.email ?? '',
        role: role,
      );
    } finally {
      isRestoringSession.value = false;
    }
  }

  // ── Public API ────────────────────────────────────────────

  /// Signs in, fetches role, updates [user].
  /// Throws a typed [AuthException] on failure.
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    isLoading.value = true;
    try {
      final authUser = await _login(email: email, password: password);
      user.value = authUser;
      return authUser;
    } finally {
      isLoading.value = false;
    }
  }

  /// Signs out and clears [user].
  Future<void> logout() async {
    await _logout();
    user.value = null;
  }

  /// Returns the cached [AuthUser] (no network call).
  AuthUser? getCurrentUser() => _getCurrentUser();

  /// Fetches the role for [userId] from the database.
  Future<AppRole?> getUserRole(String userId) => _getUserRole(userId);

  // ── Permission helper ─────────────────────────────────────

  /// Inline permission check.
  /// Usage: `AuthController.to.can((r) => r.canAccessReports)`
  bool can(bool Function(AppRole role) check) {
    final role = currentRole;
    return role != null && check(role);
  }
}
