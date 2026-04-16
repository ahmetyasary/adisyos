import 'package:orderix/models/app_role.dart';

/// Pure domain entity — no Supabase types here.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
  });

  final String id;
  final String email;
  final AppRole role;

  bool get isAdmin => role.isAdmin;
  bool get isStaff => role.isStaff;

  @override
  String toString() => 'AuthUser(id: $id, email: $email, role: ${role.name})';
}
