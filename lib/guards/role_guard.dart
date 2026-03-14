import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/features/auth/presentation/controller/auth_controller.dart';
import 'package:adisyos/models/app_role.dart';

// ─────────────────────────────────────────────────────────────
// RoleGuard  –  inline widget guard
//
// Hides [child] when the current user's role is not in [allowedRoles].
//
// Usage:
//   RoleGuard(
//     allowedRoles: [AppRole.admin],
//     child: DeleteButton(),
//   )
//
//   RoleGuard.admin(child: ReportsButton())
//   RoleGuard.staff(child: QuickOrderButton())
// ─────────────────────────────────────────────────────────────

class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  });

  final List<AppRole> allowedRoles;
  final Widget child;

  /// Shown when access is denied. Defaults to [SizedBox.shrink].
  final Widget? fallback;

  factory RoleGuard.admin({Key? key, required Widget child, Widget? fallback}) =>
      RoleGuard(
        key: key,
        allowedRoles: const [AppRole.admin],
        child: child,
        fallback: fallback,
      );

  factory RoleGuard.staff({Key? key, required Widget child, Widget? fallback}) =>
      RoleGuard(
        key: key,
        allowedRoles: const [AppRole.staff],
        child: child,
        fallback: fallback,
      );

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final role = AuthController.to.currentRole;
      if (role != null && allowedRoles.contains(role)) return child;
      return fallback ?? const SizedBox.shrink();
    });
  }
}

// ─────────────────────────────────────────────────────────────
// RoleGuardPage  –  full-page guard
//
// Wraps an entire screen. Shows a loading spinner while the role
// is being resolved, and an access-denied screen if unauthorized.
//
// Usage:
//   RoleGuardPage(
//     allowedRoles: [AppRole.admin],
//     child: ReportsView(),
//   )
// ─────────────────────────────────────────────────────────────

class RoleGuardPage extends StatelessWidget {
  const RoleGuardPage({
    super.key,
    required this.allowedRoles,
    required this.child,
  });

  final List<AppRole> allowedRoles;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final auth = AuthController.to;

      if (auth.isAuthenticated && auth.currentRole == null) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final role = auth.currentRole;
      if (role != null && allowedRoles.contains(role)) return child;

      return const _AccessDeniedScreen();
    });
  }
}

// ─────────────────────────────────────────────────────────────
// _AccessDeniedScreen
// ─────────────────────────────────────────────────────────────

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Erişim Yetkiniz Yok',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Bu sayfayı görüntülemek için yetkiniz bulunmuyor.'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: Get.back,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Geri Dön'),
            ),
          ],
        ),
      ),
    );
  }
}
