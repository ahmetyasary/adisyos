enum AppRole { admin, staff, kitchen }

extension AppRoleX on AppRole {
  String get name => switch (this) {
        AppRole.admin => 'admin',
        AppRole.staff => 'staff',
        AppRole.kitchen => 'kitchen',
      };

  /// Turkish label shown in UI (Yetkili / Garson / Mutfak).
  String get labelTr => switch (this) {
        AppRole.admin => 'Yetkili',
        AppRole.staff => 'Garson',
        AppRole.kitchen => 'Mutfak',
      };

  /// Value stored in `staff_profiles.role`.
  String get staffDbValue => switch (this) {
        AppRole.admin => 'yetkili',
        AppRole.staff => 'garson',
        AppRole.kitchen => 'mutfak',
      };

  bool get isAdmin => this == AppRole.admin;
  bool get isStaff => this == AppRole.staff;
  bool get isKitchen => this == AppRole.kitchen;

  // Page-level permissions
  bool get canAccessEmployees => isAdmin;
  bool get canAccessReports => isAdmin;
  bool get canAccessSettings => isAdmin;
  bool get canAccessTables => isAdmin || isStaff;
  bool get canAccessOrders => isAdmin || isStaff;
  bool get canAccessMenu => isAdmin;
  bool get canAccessKitchen => isAdmin || isKitchen;

  static AppRole fromString(String value) => switch (value.trim().toLowerCase()) {
        'admin' || 'yetkili' => AppRole.admin,
        'kitchen' || 'mutfak' => AppRole.kitchen,
        'staff' || 'garson' => AppRole.staff,
        _ => AppRole.staff, // safe default for unknown / legacy rows
      };
}
