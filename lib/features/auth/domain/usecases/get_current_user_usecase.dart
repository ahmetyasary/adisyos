import 'package:adisyos/features/auth/domain/entities/auth_user.dart';
import 'package:adisyos/features/auth/domain/repositories/auth_repository.dart';

class GetCurrentUserUseCase {
  const GetCurrentUserUseCase(this._repository);
  final AuthRepository _repository;

  /// Synchronous — reads from the in-memory cache.
  AuthUser? call() => _repository.getCurrentUser();
}
