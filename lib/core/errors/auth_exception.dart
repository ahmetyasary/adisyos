/// Sealed hierarchy — every auth failure is a typed exception.
sealed class AuthException implements Exception {
  const AuthException(this.messageKey);
  final String messageKey; // translation key

  @override
  String toString() => 'AuthException($messageKey)';
}

/// Wrong email / password.
class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException()
      : super('auth_error_invalid');
}

/// Email not yet confirmed on Supabase.
class EmailNotConfirmedException extends AuthException {
  const EmailNotConfirmedException()
      : super('auth_error_unconfirmed');
}

/// No network / socket error.
class NetworkException extends AuthException {
  const NetworkException() : super('auth_error_network');
}

/// Role row is missing in public.users.
class RoleNotFoundException extends AuthException {
  const RoleNotFoundException() : super('auth_error_role_not_found');
}

/// Email is already registered in Supabase auth.
class EmailAlreadyInUseException extends AuthException {
  const EmailAlreadyInUseException() : super('auth_error_email_taken');
}

/// Catch-all for unexpected failures.
class UnknownAuthException extends AuthException {
  const UnknownAuthException([this.detail])
      : super('auth_error_generic');

  /// Raw error detail for logging/debugging. Not for end-user display.
  final String? detail;

  @override
  String toString() =>
      detail == null ? 'AuthException($messageKey)' : 'AuthException($messageKey: $detail)';
}
