import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_images.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/be_ther_buttons.dart';
import '../../../core/design/widgets/be_ther_network_image.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const path = '/onboarding';
  static const name = 'onboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _SlideData {
  const _SlideData({
    required this.remoteUrl,
    this.localAsset,
    required this.title,
    required this.subtitle,
  });

  final String remoteUrl;
  final String? localAsset;
  final String title;
  final String subtitle;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _slides = [
    _SlideData(
      remoteUrl:
          'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=800&q=80',
      localAsset: AppImages.onboardingDiscoverFull,
      title: 'DISCOVER',
      subtitle: 'Where your friends are going',
    ),
    _SlideData(
      remoteUrl:
          'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800&q=80',
      title: 'SHARE',
      subtitle: 'Your travel adventures',
    ),
    _SlideData(
      remoteUrl:
          'https://images.unsplash.com/photo-1503220317375-aaad61436b1b?w=800&q=80',
      title: 'EXPLORE',
      subtitle: 'New places together',
    ),
  ];

  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final side = c.maxWidth.clamp(0, 360).toDouble();
                        return Center(
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (s.localAsset != null)
                                  Image.asset(s.localAsset!, fit: BoxFit.cover)
                                else
                                  BeTherNetworkImage(
                                    url: s.remoteUrl,
                                    fit: BoxFit.cover,
                                  ),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.background,
                                      width: 4,
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        AppColors.secondary.withValues(
                                          alpha: 0.95,
                                        ),
                                        AppColors.secondary.withValues(
                                          alpha: 0.35,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 24,
                                  child: Column(
                                    children: [
                                      Text(
                                        s.title,
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.display(
                                          56,
                                          color: AppColors.primary,
                                          letterSpacing: 0.05,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        s.subtitle,
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.body(
                                          20,
                                          color: AppColors.background,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: active ? 32 : 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.background,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),
            Image.asset(
              AppImages.beatherLogo,
              height: 100,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Text(
              'follow what you love',
              style: AppTextStyles.body(
                15,
                color: AppColors.background.withValues(alpha: 0.85),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: BeTherPrimaryButton(
                label: 'GET STARTED',
                onPressed: () => context.go('/'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
