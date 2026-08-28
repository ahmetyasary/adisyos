import 'package:orderix/features/auth/domain/repositories/auth_repository.dart';

class UpdatePasswordUseCase {
  const UpdatePasswordUseCase(this._repository);
  final AuthRepository _repository;

  Future<void> call({required String password}) =>
      _repository.updatePassword(password: password);
}
