import 'package:orderix/features/auth/domain/repositories/auth_repository.dart';

class ResetPasswordUseCase {
  const ResetPasswordUseCase(this._repository);
  final AuthRepository _repository;

  Future<void> call({required String email}) =>
      _repository.resetPasswordForEmail(email: email);
}
