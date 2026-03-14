enum AppRole { admin, staff }

extension AppRoleX on AppRole {
  String get name => switch (this) {
        AppRole.admin => 'admin',
        AppRole.staff => 'staff',
      };

  bool get isAdmin => this == AppRole.admin;
  bool get isStaff => this == AppRole.staff;

  // Page-level permissions
  bool get canAccessEmployees => isAdmin;
  bool get canAccessReports => isAdmin;
  bool get canAccessSettings => isAdmin;
  bool get canAccessTables => true; // both roles
  bool get canAccessOrders => true; // both roles
  bool get canAccessMenu => isAdmin;

  static AppRole fromString(String value) => switch (value) {
        'admin' => AppRole.admin,
        'staff' => AppRole.staff,
        _ => AppRole.staff, // safe default
      };
}
