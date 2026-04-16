import 'package:orderix/features/auth/domain/repositories/auth_repository.dart';

class SignUpUseCase {
  SignUpUseCase(this._repository);
  final AuthRepository _repository;

  Future<bool> call({required String email, required String password}) =>
      _repository.signUp(email: email, password: password);
}
