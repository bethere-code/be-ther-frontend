import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_colors.dart';
import '../app_dimens.dart';
import '../app_text_styles.dart';
import '../../network/connectivity_controller.dart';

/// Full-screen offline state — brand chrome, clear CTA, safe-area aware.
class OfflineScreen extends ConsumerStatefulWidget {
  const OfflineScreen({super.key});

  @override
  ConsumerState<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends ConsumerState<OfflineScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await ref.read(connectivityProvider.notifier).checkNow();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + bottom.clamp(0, 12)),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(
                    color: AppColors.border,
                    width: AppDimens.borderThick,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.border,
                      offset: Offset(4, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 44,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'NO CONNECTION',
                textAlign: TextAlign.center,
                style: AppTextStyles.display(40, color: AppColors.secondary),
              ),
              const SizedBox(height: 14),
              Text(
                "You're offline. Check your Wi-Fi or mobile data,\n"
                'then try again - we will pick up where you left off.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  15,
                  color: AppColors.mutedForeground,
                  weight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _retrying ? null : _retry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryForeground,
                    disabledBackgroundColor: AppColors.muted,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                      side: BorderSide(
                        color: AppColors.border,
                        width: AppDimens.borderThick,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: _retrying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.secondary,
                          ),
                        )
                      : Text(
                          'TRY AGAIN',
                          style: AppTextStyles.display(
                            20,
                            color: AppColors.primaryForeground,
                          ),
                        ),
                ),
              ),
              const Spacer(flex: 3),
              Text(
                'BE THER',
                style: AppTextStyles.display(
                  16,
                  color: AppColors.mutedForeground.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Covers the whole navigator when offline; keeps route tree alive underneath.
class OfflineBarrier extends ConsumerWidget {
  const OfflineBarrier({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (status == NetStatus.offline)
          const Positioned.fill(
            child: OfflineScreen(),
          ),
      ],
    );
  }
}
