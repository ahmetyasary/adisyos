import 'dart:async';

import 'package:get/get.dart';
// Hide Supabase's AuthUser so our domain entity wins.
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;
import 'package:orderix/core/errors/auth_exception.dart';
import 'package:orderix/features/auth/domain/entities/auth_user.dart';
import 'package:orderix/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/login_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/logout_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/get_user_role_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/signup_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/update_password_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/change_password_usecase.dart';
import 'package:orderix/models/app_role.dart';
import 'package:orderix/services/staff_service.dart';
import 'package:orderix/services/subscription_service.dart';

class AuthController extends GetxService {
  // ── Singleton access ──────────────────────────────────────
  static AuthController get to => Get.find();

  // ── Constructor injection ─────────────────────────────────
  AuthController({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required GetUserRoleUseCase getUserRoleUseCase,
    required SignUpUseCase signUpUseCase,
    required DeleteAccountUseCase deleteAccountUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
    required UpdatePasswordUseCase updatePasswordUseCase,
    required ChangePasswordUseCase changePasswordUseCase,
  })  : _login = loginUseCase,
        _logout = logoutUseCase,
        _getCurrentUser = getCurrentUserUseCase,
        _getUserRole = getUserRoleUseCase,
        _signUp = signUpUseCase,
        _deleteAccount = deleteAccountUseCase,
        _resetPassword = resetPasswordUseCase,
        _updatePassword = updatePasswordUseCase,
        _changePassword = changePasswordUseCase;

  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final GetCurrentUserUseCase _getCurrentUser;
  final GetUserRoleUseCase _getUserRole;
  final SignUpUseCase _signUp;
  final DeleteAccountUseCase _deleteAccount;
  final ResetPasswordUseCase _resetPassword;
  final UpdatePasswordUseCase _updatePassword;
  final ChangePasswordUseCase _changePassword;

  // ── Reactive state ────────────────────────────────────────
  final Rx<AuthUser?> user = Rx(null);
  final RxBool isLoading = false.obs;
  final RxBool isSigningUp = false.obs;
  final RxBool isRestoringSession = true.obs;
  final RxBool isDeletingAccount = false.obs;
  final RxBool isResettingPassword = false.obs;
  final RxBool isUpdatingPassword = false.obs;
  final RxBool pendingPasswordRecovery = false.obs;

  StreamSubscription<AuthState>? _authSub;

  // ── Convenience getters ───────────────────────────────────
  bool get isAuthenticated => user.value != null;
  bool get isAdmin => currentRole?.isAdmin ?? false;
  bool get isStaff => currentRole?.isStaff ?? false;

  /// The role that governs what the current session may access.
  ///
  /// A PIN-based staff session takes precedence over the account's own role.
  /// Staff profile roles map to [AppRole]: yetkili→admin, garson→staff,
  /// mutfak→kitchen. Reading [StaffService.hasActiveStaff] here also makes any
  /// `Obx` that watches the role rebuild when a staff session starts or ends.
  AppRole? get currentRole {
    if (Get.isRegistered<StaffService>() && StaffService.to.hasActiveStaff) {
      return StaffService.to.currentStaffAppRole;
    }
    return user.value?.role;
  }

  // ── Session restore on app start ──────────────────────────
  @override
  void onInit() {
    super.onInit();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        pendingPasswordRecovery.value = true;
      }
    });
    _restoreSession();
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
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
      await SubscriptionService.to.loginCustomer(supaUser.id);
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
      await SubscriptionService.to.loginCustomer(authUser.id);
      return authUser;
    } finally {
      isLoading.value = false;
    }
  }

  /// Registers a new user.
  /// Returns `true` when email confirmation is required before the first login.
  /// Throws a typed [AuthException] on failure.
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    isSigningUp.value = true;
    try {
      return await _signUp(email: email, password: password);
    } finally {
      isSigningUp.value = false;
    }
  }

  /// Sends a password-reset email.
  Future<void> resetPasswordForEmail({required String email}) async {
    isResettingPassword.value = true;
    try {
      await _resetPassword(email: email);
    } finally {
      isResettingPassword.value = false;
    }
  }

  /// Completes password recovery / change for the current session.
  Future<void> updatePassword({required String password}) async {
    isUpdatingPassword.value = true;
    try {
      await _updatePassword(password: password);
      pendingPasswordRecovery.value = false;
    } finally {
      isUpdatingPassword.value = false;
    }
  }

  /// Changes the account login password after verifying the current one.
  Future<void> changeLoginPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    isUpdatingPassword.value = true;
    try {
      await _changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } finally {
      isUpdatingPassword.value = false;
    }
  }

  /// Signs out and clears [user].
  Future<void> logout() async {
    await _logout();
    await SubscriptionService.to.logoutCustomer();
    user.value = null;
    pendingPasswordRecovery.value = false;
  }

  /// Permanently deletes the current user's account (Apple 5.1.1(v)).
  /// Clears [user] on success. Throws a typed [AuthException] on failure.
  Future<void> deleteAccount() async {
    isDeletingAccount.value = true;
    try {
      await _deleteAccount();
      await SubscriptionService.to.logoutCustomer();
      user.value = null;
    } finally {
      isDeletingAccount.value = false;
    }
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
