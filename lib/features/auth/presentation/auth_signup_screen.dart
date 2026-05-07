import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/be_ther_buttons.dart';
import '../../../core/network/api_exception.dart';
import 'auth_notifier.dart';
import 'auth_otp_route_extra.dart';
import 'auth_otp_screen.dart';

/// Sign-up: collect profile + password, then send OTP and open [AuthOtpScreen].
class AuthSignupScreen extends ConsumerStatefulWidget {
  const AuthSignupScreen({super.key});

  static const path = '/auth/signup';
  static const name = 'authSignup';

  @override
  ConsumerState<AuthSignupScreen> createState() => _AuthSignupScreenState();
}

class _LowercaseAlphanumericUsernameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return newValue.copyWith(text: t, composing: TextRange.empty);
  }
}

class _AuthSignupScreenState extends ConsumerState<AuthSignupScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _age = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  String? _usernameError;
  String? _emailError;
  bool _checkingUsername = false;
  bool _checkingEmail = false;
  bool _usernameAvailable = false;
  bool _emailAvailable = false;
  Timer? _usernameDebounce;
  Timer? _emailDebounce;
  int _usernameRequestId = 0;
  int _emailRequestId = 0;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _emailDebounce?.cancel();
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _age.dispose();
    _password.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _passwordRegex = RegExp(
    r'^.{8,}$',
  );

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Enter your name';
    final u = _username.text.trim();
    if (u.length < 3 || u.length > 32) {
      return 'Username must be 3–32 characters';
    }
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(u)) {
      return 'Username: lowercase letters and digits only';
    }
    final e = _email.text.trim();
    if (!_emailRegex.hasMatch(e)) return 'Enter a valid email';
    if (_usernameError != null) return _usernameError;
    if (_emailError != null) return _emailError;
    final p = _password.text;
    if (!_passwordRegex.hasMatch(p)) {
      return 'Password must be at least 8 characters';
    }
    final ageText = _age.text.trim();
    if (ageText.isNotEmpty) {
      final n = int.tryParse(ageText);
      if (n == null || n < 1 || n > 120) {
        return 'Age must be a number between 1 and 120';
      }
    }
    return null;
  }

  void _scheduleUsernameAvailabilityCheck(String raw) {
    if (_loading) return;
    final username = raw.trim().toLowerCase();
    _usernameDebounce?.cancel();
    _usernameError = null;
    _usernameAvailable = false;

    if (username.isEmpty) {
      setState(() {});
      return;
    }
    if (username.length < 3) {
      setState(() => _usernameError = 'Username must be at least 3 characters');
      return;
    }
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(username)) {
      setState(
        () => _usernameError = 'Username: lowercase letters and digits only',
      );
      return;
    }

    setState(() => _checkingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      final requestId = ++_usernameRequestId;
      try {
        final result = await ref
            .read(authRepositoryProvider)
            .checkSignupAvailability(username: username);
        if (!mounted ||
            requestId != _usernameRequestId ||
            _username.text.trim() != username) {
          return;
        }
        final field = result.username;
        setState(() {
          _checkingUsername = false;
          _usernameAvailable = field?.available == true;
          _usernameError = field?.available == false
              ? (field?.reason ?? 'Username not available')
              : null;
        });
      } catch (_) {
        if (!mounted || requestId != _usernameRequestId) return;
        setState(() {
          _checkingUsername = false;
          _usernameError = 'Could not verify username right now';
        });
      }
    });
  }

  void _scheduleEmailAvailabilityCheck(String raw) {
    if (_loading) return;
    final email = raw.trim().toLowerCase();
    _emailDebounce?.cancel();
    _emailError = null;
    _emailAvailable = false;

    if (email.isEmpty) {
      setState(() {});
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email');
      return;
    }

    setState(() => _checkingEmail = true);
    _emailDebounce = Timer(const Duration(milliseconds: 500), () async {
      final requestId = ++_emailRequestId;
      try {
        final result = await ref
            .read(authRepositoryProvider)
            .checkSignupAvailability(email: email);
        if (!mounted ||
            requestId != _emailRequestId ||
            _email.text.trim().toLowerCase() != email) {
          return;
        }
        final field = result.email;
        setState(() {
          _checkingEmail = false;
          _emailAvailable = field?.available == true;
          _emailError = field?.available == false
              ? (field?.reason ?? 'Email not available')
              : null;
        });
      } catch (_) {
        if (!mounted || requestId != _emailRequestId) return;
        setState(() {
          _checkingEmail = false;
          _emailError = 'Could not verify email right now';
        });
      }
    });
  }

  void _applyServerFieldErrors(String message) {
    _usernameError = null;
    _emailError = null;
    final lower = message.toLowerCase();
    if (lower.contains('username') && lower.contains('taken') ||
        lower.contains('username') && lower.contains('exists')) {
      _usernameError = 'Username already exists';
      return;
    }
    if (lower.contains('email') && lower.contains('already')) {
      _emailError = 'Email already exists';
    }
  }

  Future<void> _sendOtp() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _usernameError = null;
      _emailError = null;
      _loading = true;
    });
    try {
      final ageText = _age.text.trim();
      final age = ageText.isEmpty ? null : int.tryParse(ageText);
      await ref
          .read(authRepositoryProvider)
          .requestSignupOtp(
            displayName: _name.text.trim(),
            username: _username.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            age: age,
          );
      if (!mounted) return;
      context.push(
        AuthOtpScreen.path,
        extra: AuthOtpRouteExtra(
          identifier: _email.text.trim(),
          destinationLabel: _email.text.trim(),
          flow: AuthOtpFlow.signup,
        ),
      );
    } catch (e) {
      final message = e is ApiException
          ? e.message
          : 'Something went wrong. Try again.';
      setState(() {
        _error = message;
        _applyServerFieldErrors(message);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: Text(
          'SIGN UP',
          style: AppTextStyles.display(
            28,
            color: AppColors.primary,
            letterSpacing: 0.08,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + insets),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Name', required: true),
                const SizedBox(height: 6),
                TextField(
                  controller: _name,
                  readOnly: _loading,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Your full name',
                    hintStyle: AppTextStyles.body(
                      13,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _fieldLabelWithStatus(
                  'Username',
                  required: true,
                  checking: _checkingUsername,
                  error: _usernameError,
                  available: _usernameAvailable,
                ),
                const SizedBox(height: 6),
                // Text(
                //   'Lowercase, no spaces (letters and numbers only)',
                //   style: AppTextStyles.body(12, color: AppColors.mutedForeground),
                // ),
                // const SizedBox(height: 8),
                TextField(
                  controller: _username,
                  readOnly: _loading,
                  inputFormatters: [_LowercaseAlphanumericUsernameFormatter()],
                  autocorrect: false,
                  onChanged: _scheduleUsernameAvailabilityCheck,
                  decoration: InputDecoration(
                    hintStyle: AppTextStyles.body(
                      13,
                      color: AppColors.mutedForeground,
                    ),
                    hintText: 'janesmith (letters and numbers only)',
                  ),
                ),
                if (_usernameError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _usernameError!,
                    style: AppTextStyles.body(13, color: AppColors.destructive),
                  ),
                ],
                const SizedBox(height: 14),
                _fieldLabelWithStatus(
                  'Email',
                  required: true,
                  checking: _checkingEmail,
                  error: _emailError,
                  available: _emailAvailable,
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _email,
                  readOnly: _loading,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  onChanged: _scheduleEmailAvailabilityCheck,
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    hintStyle: AppTextStyles.body(
                      13,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                if (_emailError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _emailError!,
                    style: AppTextStyles.body(13, color: AppColors.destructive),
                  ),
                ],
                const SizedBox(height: 14),
                _fieldLabel('Age', optional: true),
                const SizedBox(height: 6),
                TextField(
                  controller: _age,
                  readOnly: _loading,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g. 24',
                    hintStyle: AppTextStyles.body(
                      13,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Password', required: true),
                const SizedBox(height: 6),
                // Text(
                //   'At least 8 characters; letters and numbers only (include both)',
                //   style: AppTextStyles.body(
                //     12,
                //     color: AppColors.mutedForeground,
                //   ),
                // ),
                // const SizedBox(height: 4),
                TextField(
                  controller: _password,
                  readOnly: _loading,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: _loading
                          ? null
                          : () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: AppTextStyles.body(14, color: AppColors.destructive),
                  ),
                ],
                const SizedBox(height: 28),
                BeTherPrimaryButton(
                  label: _loading ? 'VERIFYING...' : 'VERIFY OTP',
                  enabled: !_loading,
                  onPressed: _sendOtp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(
    String text, {
    bool required = false,
    bool optional = false,
  }) {
    return RichText(
      text: TextSpan(
        style: AppTextStyles.body(
          16,
          color: AppColors.black,
          weight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: text),
          if (required)
            TextSpan(
              text: ' *',
              style: AppTextStyles.body(
                14,
                color: AppColors.destructive,
                weight: FontWeight.w800,
              ),
            ),
          if (optional)
            TextSpan(
              text: ' (optional)',
              style: AppTextStyles.body(12, color: AppColors.mutedForeground),
            ),
        ],
      ),
    );
  }

  Widget _fieldLabelWithStatus(
    String text, {
    bool required = false,
    bool optional = false,
    required bool checking,
    required String? error,
    required bool available,
  }) {
    return Row(
      children: [
        Expanded(child: _fieldLabel(text, required: required, optional: optional)),
        _InlineFieldStatusText(
          checking: checking,
          error: error,
          available: available,
        ),
      ],
    );
  }
}

class _InlineFieldStatusText extends StatelessWidget {
  const _InlineFieldStatusText({
    required this.checking,
    required this.error,
    required this.available,
  });

  final bool checking;
  final String? error;
  final bool available;

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return Text(
        'Checking...',
        style: AppTextStyles.body(12, color: AppColors.mutedForeground, weight: FontWeight.w700),
      );
    }
    if (error != null) {
      return Text(
        'Not available',
        style: AppTextStyles.body(12, color: AppColors.destructive, weight: FontWeight.w700),
      );
    }
    if (!available) return const SizedBox.shrink();
    return Text(
      'Available',
      style: AppTextStyles.body(12, color: Colors.green.shade700, weight: FontWeight.w700),
    );
  }
}
