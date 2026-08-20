import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/be_ther_buttons.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
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
  static const _nameMaxLength = 30;
  static const _usernameMaxLength = 20;
  static const _usernameMinLength = 3;

  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _age = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  String? _nameError;
  String? _usernameError;
  String? _emailError;
  String? _ageError;
  String? _passwordError;
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
  static final _passwordRegex = RegExp(r'^.{8,}$');

  bool _applyFieldValidation() {
    final name = _name.text;
    if (name.trim().isEmpty) {
      _nameError = 'Enter your name';
    } else if (name.length > _nameMaxLength) {
      _nameError = 'Name must be at most $_nameMaxLength characters';
    } else {
      _nameError = null;
    }

    final u = _username.text.trim();
    if (u.length < _usernameMinLength || u.length > _usernameMaxLength) {
      _usernameError =
          'Username must be $_usernameMinLength–$_usernameMaxLength characters';
    } else if (!RegExp(r'^[a-z0-9]+$').hasMatch(u)) {
      _usernameError = 'Username: lowercase letters and digits only';
    } else if (_checkingUsername) {
      _usernameError = 'Wait until username is checked';
    } else if (!_usernameAvailable) {
      _usernameError ??= 'Username not available';
    } else {
      _usernameError = null;
    }

    final e = _email.text.trim();
    if (!_emailRegex.hasMatch(e)) {
      _emailError = 'Enter a valid email';
    } else if (_checkingEmail) {
      _emailError = 'Wait until email is checked';
    } else if (!_emailAvailable) {
      _emailError ??= 'Email not available';
    } else {
      _emailError = null;
    }

    final ageText = _age.text.trim();
    if (ageText.isEmpty) {
      _ageError = null;
    } else {
      final n = int.tryParse(ageText);
      _ageError = (n == null || n < 10 || n > 125)
          ? 'Age must be between 10 and 125'
          : null;
    }

    _passwordError = !_passwordRegex.hasMatch(_password.text)
        ? 'Password must be at least 8 characters'
        : null;

    return _nameError == null &&
        _usernameError == null &&
        _emailError == null &&
        _ageError == null &&
        _passwordError == null;
  }

  void _onNameChanged(String raw) {
    // Count includes spaces; no counter UI — surface as an error only.
    final error = raw.length > _nameMaxLength
        ? 'Name must be at most $_nameMaxLength characters'
        : null;
    setState(() {
      _nameError = error;
      if (_error != null) _error = null;
    });
  }

  void _scheduleUsernameAvailabilityCheck(String raw) {
    if (_loading) return;
    final username = raw.trim().toLowerCase();
    _usernameDebounce?.cancel();
    _usernameRequestId++;

    if (username.isEmpty) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = false;
        _usernameError = null;
      });
      return;
    }
    if (username.length < _usernameMinLength) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = false;
        _usernameError =
            'Username must be at least $_usernameMinLength characters';
      });
      return;
    }
    if (username.length > _usernameMaxLength) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = false;
        _usernameError =
            'Username must be at most $_usernameMaxLength characters';
      });
      return;
    }
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(username)) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = false;
        _usernameError = 'Username: lowercase letters and digits only';
      });
      return;
    }

    setState(() {
      _checkingUsername = true;
      _usernameAvailable = false;
      _usernameError = null;
    });
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      final requestId = _usernameRequestId;
      try {
        final result = await ref
            .read(authRepositoryProvider)
            .checkSignupAvailability(username: username);
        if (!mounted || requestId != _usernameRequestId) return;
        if (_username.text.trim() != username) {
          setState(() => _checkingUsername = false);
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
    _emailRequestId++;

    if (email.isEmpty) {
      setState(() {
        _checkingEmail = false;
        _emailAvailable = false;
        _emailError = null;
      });
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() {
        _checkingEmail = false;
        _emailAvailable = false;
        _emailError = 'Enter a valid email';
      });
      return;
    }

    setState(() {
      _checkingEmail = true;
      _emailAvailable = false;
      _emailError = null;
    });
    _emailDebounce = Timer(const Duration(milliseconds: 500), () async {
      final requestId = _emailRequestId;
      try {
        final result = await ref
            .read(authRepositoryProvider)
            .checkSignupAvailability(email: email);
        if (!mounted || requestId != _emailRequestId) return;
        if (_email.text.trim().toLowerCase() != email) {
          setState(() => _checkingEmail = false);
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
    setState(() {
      _error = null;
      if (!_applyFieldValidation()) return;
      _loading = true;
    });
    if (!_loading) return;
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
    return Theme(
      data: AppTheme.authFields(Theme.of(context)),
      child: Scaffold(
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
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Name', required: true),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _name,
                    readOnly: _loading,
                    textCapitalization: TextCapitalization.words,
                    onChanged: _onNameChanged,
                    decoration: InputDecoration(
                      hintText: 'first name',
                      hintStyle: AppTextStyles.body(
                        13,
                        color: AppColors.mutedForeground,
                      ),
                      // Never show Flutter's character counter.
                      counterText: '',
                    ),
                  ),
                  if (_nameError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _nameError!,
                      style: AppTextStyles.body(
                        13,
                        color: AppColors.destructive,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _fieldLabelWithStatus(
                    'Username',
                    required: true,
                    checking: _checkingUsername,
                    error: _usernameError,
                    available: _usernameAvailable,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _username,
                    readOnly: _loading,
                    inputFormatters: [
                      _LowercaseAlphanumericUsernameFormatter(),
                    ],
                    autocorrect: false,
                    onChanged: _scheduleUsernameAvailabilityCheck,
                    decoration: InputDecoration(
                      hintStyle: AppTextStyles.body(
                        13,
                        color: AppColors.mutedForeground,
                      ),
                      hintText: 'janesmith (letters and numbers only)',
                      counterText: '',
                    ),
                  ),
                  if (_usernameError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _usernameError!,
                      style: AppTextStyles.body(
                        13,
                        color: AppColors.destructive,
                      ),
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
                      style: AppTextStyles.body(
                        13,
                        color: AppColors.destructive,
                      ),
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
                    onChanged: (_) {
                      final ageText = _age.text.trim();
                      setState(() {
                        if (ageText.isEmpty) {
                          _ageError = null;
                        } else {
                          final n = int.tryParse(ageText);
                          _ageError = (n == null || n < 10 || n > 125)
                              ? 'Age must be between 10 and 125'
                              : null;
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'e.g. 24',
                      hintStyle: AppTextStyles.body(
                        13,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  if (_ageError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _ageError!,
                      style: AppTextStyles.body(
                        13,
                        color: AppColors.destructive,
                      ),
                    ),
                  ],
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
                    onChanged: (_) => setState(() => _passwordError = null),
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
                  if (_passwordError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _passwordError!,
                      style: AppTextStyles.body(
                        13,
                        color: AppColors.destructive,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: AppTextStyles.body(
                        14,
                        color: AppColors.destructive,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  BeTherPrimaryButton(
                    label: _loading ? 'VERIFYING...' : 'VERIFY OTP',
                    enabled: !_loading,
                    onPressed: _sendOtp,
                  ),
                  const SizedBox(height: 12),
                  Center(child: Text('OR')),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 230,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.card,
                          side: BorderSide(color: AppColors.border, width: 2),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        onPressed: _loading
                            ? null
                            : () async {
                                setState(() {
                                  _error = null;
                                  _loading = true;
                                });
                                try {
                                  // One Google action for both cases:
                                  // - New Google user: sign up
                                  // - Existing Google user: sign in
                                  final tokens = await ref
                                      .read(authRepositoryProvider)
                                      .signInWithGoogle();
                                  await ref
                                      .read(authNotifierProvider.notifier)
                                      .applyTokens(
                                        tokens,
                                        authAction: 'signup',
                                      );
                                  if (!mounted) return;
                                  if (!context.mounted) return;
                                  context.go('/feed');
                                } catch (e) {
                                  final message = e is ApiException
                                      ? e.message
                                      : 'Google sign-in failed. Please try again.';
                                  setState(() => _error = message);
                                } finally {
                                  if (mounted) setState(() => _loading = false);
                                }
                              },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/google.png',
                              width: 18,
                              height: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _loading
                                  ? 'CONNECTING...'
                                  : 'Continue with Google',
                              style: AppTextStyles.body(
                                13,
                                color: AppColors.foreground,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
        Expanded(
          child: _fieldLabel(text, required: required, optional: optional),
        ),
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
        style: AppTextStyles.body(
          12,
          color: AppColors.mutedForeground,
          weight: FontWeight.w700,
        ),
      );
    }
    if (error != null) {
      return Text(
        'Not available',
        style: AppTextStyles.body(
          12,
          color: AppColors.destructive,
          weight: FontWeight.w700,
        ),
      );
    }
    if (!available) return const SizedBox.shrink();
    return Text(
      'Available',
      style: AppTextStyles.body(
        12,
        color: Colors.green.shade700,
        weight: FontWeight.w700,
      ),
    );
  }
}
