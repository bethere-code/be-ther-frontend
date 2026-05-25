import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_images.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/storage/onboarding_storage.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../feed/presentation/feed_screen.dart';
import '../../launch/presentation/launch_screen.dart';
import '../../onboarding/presentation/onboarding_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const path = '/splash';
  static const name = 'splash';

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _words = ['FIND', 'FOLLOW', 'CONNECT'];
  static const _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.secondary,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  final _onboardingStorage = OnboardingStorage();
  int _wordIndex = 0;
  int _zoomStep = 0;

  @override
  void initState() {
    super.initState();
    _runStartup();
  }

  Future<void> _runStartup() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _zoomStep = 1);

    for (var i = 1; i < _words.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      setState(() {
        _wordIndex = i;
        _zoomStep += 1;
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    await ref.read(authNotifierProvider.notifier).hydrateFromStorage();
    if (!mounted) return;

    final auth = ref.read(authNotifierProvider);
    if (auth.isAuthenticated) {
      context.go(FeedScreen.path);
      return;
    }

    final seen = await _onboardingStorage.hasSeenOnboarding();
    if (!mounted) return;
    if (!seen) {
      await _onboardingStorage.markSeen();
      if (!mounted) return;
      context.go(OnboardingScreen.path);
      return;
    }

    context.go(LaunchScreen.path);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 0.2,
              child: Image.asset(AppImages.bgSecondaryFull, fit: BoxFit.cover),
            ),
            Center(
              child: SizedBox(
                height: 256,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 900),
                  curve: const Cubic(0.6, 0.05, 0.01, 0.9),
                  scale: 1 + (_zoomStep * 0.14),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_wordIndex == 0)
                        Image.asset(
                          AppImages.beatherLogo,
                          height: 300,
                          fit: BoxFit.contain,
                        )
                      else
                        for (
                          var i = (_wordIndex - 1).clamp(0, _wordIndex);
                          i <= _wordIndex;
                          i++
                        )
                          _WordLayer(word: _words[i], depth: _wordIndex - i),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordLayer extends StatelessWidget {
  const _WordLayer({required this.word, required this.depth});

  final String word;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final active = depth == 0;
    final fadedAlpha = switch (depth) {
      0 => 1.0,
      1 => 0.1,
      _ => 0.0,
    };
    final yOffset = (depth * -28).toDouble();

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 600),
      curve: const Cubic(0.6, 0.05, 0.01, 0.9),
      style:
          AppTextStyles.display(
            72,
            color: active
                ? AppColors.primary
                : AppColors.background.withValues(alpha: fadedAlpha),
            letterSpacing: 0.05,
          ).copyWith(
            shadows: active
                ? null
                : [const Shadow(blurRadius: 6, color: Colors.black26)],
          ),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 900),
        curve: const Cubic(0.6, 0.05, 0.01, 0.9),
        offset: Offset(0, yOffset / 256),
        child: Text(word, textAlign: TextAlign.center),
      ),
    );
  }
}
