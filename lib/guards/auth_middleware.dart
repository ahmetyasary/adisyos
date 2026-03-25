import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/features/auth/presentation/controller/auth_controller.dart';
import 'package:adisyos/models/app_role.dart';

/// Flip to true to skip authentication during development.
/// Has no effect in release builds.
const _kBypassAuth = true;

// ── Named routes ──────────────────────────────────────────────

abstract class AppRoutes {
  static const login     = '/login';
  static const home      = '/home';
  static const tables    = '/tables';
  static const orders    = '/orders';
  static const menu      = '/menu';
  static const reports   = '/reports';
  static const employees = '/employees';
  static const settings  = '/settings';
}

// ── Role permissions per route ────────────────────────────────
//    Omitted routes are accessible to any authenticated user.

const _routePermissions = <String, List<AppRole>>{
  AppRoutes.reports:   [AppRole.admin],
  AppRoutes.employees: [AppRole.admin],
  AppRoutes.settings:  [AppRole.admin],
  AppRoutes.menu:      [AppRole.admin],
  // Both roles:
  AppRoutes.tables:    [AppRole.admin, AppRole.staff],
  AppRoutes.orders:    [AppRole.admin, AppRole.staff],
};

// ── Middleware ────────────────────────────────────────────────

/// Attach to any GetPage that requires authentication or a specific role.
///
/// ```dart
/// GetPage(
///   name: AppRoutes.reports,
///   page: () => const ReportsView(),
///   middlewares: [AuthMiddleware()],
/// )
/// ```
class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final auth = AuthController.to;

    // ── Not logged in → login screen ──────────────────────
    if (!auth.isAuthenticated) {
      if (kDebugMode && _kBypassAuth) return null;
      return const RouteSettings(name: AppRoutes.login);
    }

    // ── Role still loading → allow (controller shows spinner) ─
    final role = auth.currentRole;
    if (role == null) return null;

    // ── Check page-level permission ───────────────────────
    final allowed = _routePermissions[route];
    if (allowed != null && !allowed.contains(role)) {
      Get.snackbar(
        'Erişim Engellendi',
        'Bu sayfaya erişim yetkiniz yok.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return const RouteSettings(name: AppRoutes.home);
    }

    return null; // allow
  }
}
