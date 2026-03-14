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

/// Catch-all for unexpected failures.
class UnknownAuthException extends AuthException {
  const UnknownAuthException([String? detail])
      : super('auth_error_generic');
}
