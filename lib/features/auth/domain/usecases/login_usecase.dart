import 'package:adisyos/features/auth/domain/entities/auth_user.dart';
import 'package:adisyos/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);
  final AuthRepository _repository;

  Future<AuthUser> call({
    required String email,
    required String password,
  }) =>
      _repository.login(email: email, password: password);
}
