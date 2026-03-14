import 'package:adisyos/features/auth/domain/repositories/auth_repository.dart';
import 'package:adisyos/models/app_role.dart';

class GetUserRoleUseCase {
  const GetUserRoleUseCase(this._repository);
  final AuthRepository _repository;

  /// Fetches the role for [userId] from the database.
  Future<AppRole?> call(String userId) => _repository.getUserRole(userId);
}
