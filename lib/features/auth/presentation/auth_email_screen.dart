import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/be_ther_buttons.dart';
import '../../../core/network/api_exception.dart';
import 'auth_notifier.dart';
import 'auth_otp_route_extra.dart';
import 'auth_otp_screen.dart';

class AuthEmailScreen extends ConsumerStatefulWidget {
  const AuthEmailScreen({super.key});

  static const path = '/auth/email';
  static const name = 'authEmail';

  @override
  ConsumerState<AuthEmailScreen> createState() => _AuthEmailScreenState();
}

class _AuthEmailScreenState extends ConsumerState<AuthEmailScreen> {
  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _usePassword = false;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateIdentifier(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Enter email or username';
    if (value.contains('@')) {
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
    } else {
      if (value.length < 3) return 'Username must be at least 3 characters';
      if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
        return 'Username can contain only letters and numbers';
      }
    }
    return null;
  }

  Future<void> _requestOtpLogin() async {
    final identifier = _identifier.text.trim();
    final validation = _validateIdentifier(identifier);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final result = await ref.read(authRepositoryProvider).requestLoginOtp(identifier);
      if (!mounted) return;
      context.push(
        AuthOtpScreen.path,
        extra: AuthOtpRouteExtra(
          identifier: identifier,
          destinationLabel: result.destinationLabel,
          flow: AuthOtpFlow.login,
        ),
      );
    } catch (e) {
      final message = e is ApiException
          ? e.message
          : 'Unable to continue. Please try again.';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithPassword() async {
    final identifier = _identifier.text.trim();
    final validation = _validateIdentifier(identifier);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final tokens = await ref.read(authRepositoryProvider).loginWithPassword(
            identifier: identifier,
            password: _password.text,
          );
      await ref.read(authNotifierProvider.notifier).applyTokens(tokens);
      if (!mounted) return;
      context.go('/feed');
    } catch (e) {
      final message = e is ApiException
          ? e.message
          : 'Login failed. Please try again.';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final tokens = await ref.read(authRepositoryProvider).signInWithGoogle();
      await ref.read(authNotifierProvider.notifier).applyTokens(tokens);
      if (!mounted) return;
      context.go('/feed');
    } catch (e) {
      final message = e is ApiException ? e.message : 'Google sign-in failed. Please try again.';
      setState(() => _error = message);
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
        title: Text('SIGN IN', style: AppTextStyles.display(28, color: AppColors.primary, letterSpacing: 0.08)),
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
                Text(
                  'Email or username',
                  style: AppTextStyles.body(14, color: AppColors.mutedForeground, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _identifier,
                  readOnly: _loading,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'you@example.com or username'),
                ),
                if (_usePassword) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Password',
                    style: AppTextStyles.body(14, color: AppColors.mutedForeground, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _password,
                    readOnly: _loading,
                    obscureText: _obscurePassword,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Enter password',
                      suffixIcon: IconButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: AppTextStyles.body(14, color: AppColors.destructive)),
                ],
                const SizedBox(height: 24),
                BeTherPrimaryButton(
                  label: _loading
                      ? (_usePassword ? 'SIGNING IN...' : 'VERIFYING...')
                      : (_usePassword ? 'SIGN IN' : 'VERIFY OTP'),
                  enabled: !_loading,
                  onPressed: _usePassword ? _loginWithPassword : _requestOtpLogin,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _error = null;
                              _usePassword = !_usePassword;
                            }),
                    child: Text(
                      _usePassword ? 'Use OTP instead' : 'Login with password instead',
                      style: AppTextStyles.body(12, color: AppColors.mutedForeground, weight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                BeTherSecondaryButton(
                  label: 'GOOGLE',
                  enabled: !_loading,
                  onPressed: _google,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
