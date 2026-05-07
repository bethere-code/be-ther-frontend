/// Passed via [GoRouterState.extra] when opening [AuthOtpScreen].
enum AuthOtpFlow {
  /// Existing email-only login path (`/auth/email` → OTP).
  login,

  /// Full sign-up form → OTP → account creation.
  signup,
}

class AuthOtpRouteExtra {
  const AuthOtpRouteExtra({
    required this.identifier,
    required this.destinationLabel,
    required this.flow,
  });

  /// What OTP verification endpoint should use (email or username/email identifier).
  final String identifier;

  /// What the UI should display as destination text (usually an email).
  final String destinationLabel;

  final AuthOtpFlow flow;
}
