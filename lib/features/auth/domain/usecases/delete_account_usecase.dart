import 'package:orderix/features/auth/domain/repositories/auth_repository.dart';

class DeleteAccountUseCase {
  const DeleteAccountUseCase(this._repository);
  final AuthRepository _repository;

  Future<void> call() => _repository.deleteAccount();
}
