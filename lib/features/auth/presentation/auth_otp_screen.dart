import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/be_ther_buttons.dart';
import '../../../core/network/api_exception.dart';
import '../../feed/presentation/feed_screen.dart';
import 'auth_email_screen.dart';
import 'auth_notifier.dart';
import 'auth_otp_route_extra.dart';
import 'auth_signup_screen.dart';

class AuthOtpScreen extends ConsumerStatefulWidget {
  const AuthOtpScreen({
    super.key,
    required this.identifier,
    required this.destinationLabel,
    required this.flow,
  });

  final String identifier;
  final String destinationLabel;
  final AuthOtpFlow flow;

  static const path = '/auth/otp';
  static const name = 'authOtp';

  @override
  ConsumerState<AuthOtpScreen> createState() => _AuthOtpScreenState();
}

class _AuthOtpScreenState extends ConsumerState<AuthOtpScreen> {
  late final List<TextEditingController> _digitControllers;
  late final List<FocusNode> _digitFocus;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _digitControllers = List.generate(6, (_) => TextEditingController());
    _digitFocus = List.generate(6, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _digitFocus) {
      f.dispose();
    }
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    if (widget.flow == AuthOtpFlow.signup) {
      context.go(AuthSignupScreen.path);
    } else {
      context.go(AuthEmailScreen.path);
    }
  }

  String get _otp => _digitControllers.map((c) => c.text).join();

  KeyEventResult _onDigitKeyEvent(int index, KeyEvent event) {
    if (_loading) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return KeyEventResult.ignored;

    // Backspace behavior requested:
    // 1) clear current box
    // 2) move to previous box
    // 3) clear previous box
    _digitControllers[index].clear();
    if (index > 0) {
      _digitControllers[index - 1].clear();
      _digitFocus[index - 1].requestFocus();
    } else {
      _digitFocus[index].requestFocus();
    }
    setState(() {});
    return KeyEventResult.handled;
  }

  void _onDigitChanged(int index, String value) {
    if (_loading) return;
    setState(() => _error = null);
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      _digitControllers[index].clear();
      setState(() {});
      return;
    }
    if (digits.length > 1) {
      var rest = digits;
      for (var j = index; j < 6 && rest.isNotEmpty; j += 1) {
        _digitControllers[j].text = rest[0];
        rest = rest.length > 1 ? rest.substring(1) : '';
      }
      final lastFilled = index + digits.length - 1;
      final next = (lastFilled + 1).clamp(0, 5);
      if (lastFilled < 5) {
        _digitFocus[next].requestFocus();
      } else {
        _digitFocus[5].requestFocus();
      }
      setState(() {});
      return;
    }
    _digitControllers[index].text = digits;
    if (index < 5) {
      _digitFocus[index + 1].requestFocus();
    } else {
      _digitFocus[index].unfocus();
    }
    setState(() {});
  }

  Future<void> _verify() async {
    final code = _otp;
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final tokens = widget.flow == AuthOtpFlow.signup
          ? await repo.verifySignupOtp(email: widget.identifier, code: code)
          : await repo.verifyLoginOtp(identifier: widget.identifier, code: code);
      await ref.read(authNotifierProvider.notifier).applyTokens(tokens);
      if (!mounted) return;
      context.go(FeedScreen.path);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Invalid code. Please try again.';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final primaryCtaLabel = widget.flow == AuthOtpFlow.signup ? 'COMPLETE SIGN UP' : 'VERIFY';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack),
        title: Text(
          'ENTER CODE',
          style: AppTextStyles.display(26, color: AppColors.primary, letterSpacing: 0.08),
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
                Text(
                  'We sent a code to',
                  style: AppTextStyles.body(14, color: AppColors.mutedForeground),
                ),
                Text(
                  widget.destinationLabel,
                  style: AppTextStyles.body(16, weight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Never share this code with anyone. It expires in a few minutes.',
                  style: AppTextStyles.body(13, color: AppColors.mutedForeground, height: 1.4),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 48,
                      child: Focus(
                        onKeyEvent: (_, event) => _onDigitKeyEvent(i, event),
                        child: TextField(
                          controller: _digitControllers[i],
                          focusNode: _digitFocus[i],
                          readOnly: _loading,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: AppTextStyles.display(
                            22,
                            color: AppColors.secondary,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: AppColors.border, width: AppDimens.borderThick),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: AppColors.border, width: AppDimens.borderThick),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: AppColors.ring, width: AppDimens.borderThick),
                            ),
                          ),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (v) => _onDigitChanged(i, v),
                        ),
                      ),
                    );
                  }),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: AppTextStyles.body(14, color: AppColors.destructive)),
                ],
                const SizedBox(height: 28),
                BeTherPrimaryButton(
                  label: primaryCtaLabel,
                  enabled: !_loading,
                  onPressed: _verify,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
