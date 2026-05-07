import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../launch/presentation/launch_screen.dart';
import '../../profile/presentation/profile_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const path = '/settings';
  static const name = 'settings';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _private = false;
  bool _push = true;
  String _calendarView = 'full';
  var _hydrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    _hydrated = true;
    Future.microtask(() async {
      try {
        final user = await ref.read(profileMeProvider.future);
        if (!mounted) return;
        final settings = user['settings'];
        if (settings is Map<String, dynamic>) {
          setState(() {
            _private = settings['isPrivateProfile'] as bool? ?? false;
            _push = settings['pushEnabled'] as bool? ?? true;
            _calendarView = settings['calendarView'] as String? ?? 'full';
          });
        }
      } catch (_) {
        // ignore
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(profileMeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('SETTINGS', style: AppTextStyles.display(32, color: AppColors.primary, letterSpacing: 0.1)),
      ),
      body: me.when(
        data: (_) {
          return ListView(
            children: [
              _sectionTitle('PROFILE'),
              SwitchListTile(
                title: Text(_private ? 'Private Profile' : 'Public Profile', style: AppTextStyles.body(16, weight: FontWeight.w800)),
                subtitle: Text(
                  _private ? 'Only starred users can see your posts' : 'Anyone can view your profile and posts',
                  style: AppTextStyles.body(13, color: AppColors.mutedForeground),
                ),
                value: _private,
                onChanged: (v) async {
                  setState(() => _private = v);
                  await _save();
                },
              ),
              const Divider(height: 1, thickness: AppDimens.borderThick, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          setState(() => _calendarView = 'full');
                          await _save();
                        },
                        child: const Text('FULL CALENDAR'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          setState(() => _calendarView = 'events-only');
                          await _save();
                        },
                        child: const Text('EVENTS ONLY'),
                      ),
                    ),
                  ],
                ),
              ),
              _sectionTitle('NOTIFICATIONS'),
              SwitchListTile(
                title: Text('Push Notifications', style: AppTextStyles.body(16, weight: FontWeight.w800)),
                subtitle: Text('Stars and wishlists', style: AppTextStyles.body(13, color: AppColors.mutedForeground)),
                value: _push,
                onChanged: (v) async {
                  setState(() => _push = v);
                  await _save();
                },
              ),
              const Divider(height: 1, thickness: AppDimens.borderThick, color: AppColors.border),
              _sectionTitle('ACCOUNT'),
              ListTile(
                title: Text('Log Out', style: AppTextStyles.body(16, weight: FontWeight.w800, color: AppColors.destructive)),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('LOG OUT?', style: AppTextStyles.display(22, color: AppColors.secondary)),
                      content: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('LOG OUT'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    await ref.read(authNotifierProvider.notifier).logout();
                    if (!context.mounted) return;
                    context.go(LaunchScreen.path);
                  }
                },
              ),
              const SizedBox(height: 24),
              Center(child: Text('BE THER v1.0.0', style: AppTextStyles.body(13, color: AppColors.mutedForeground))),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: SelectableText('$e')),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.muted,
      child: Text(text, style: AppTextStyles.display(13, color: AppColors.mutedForeground, letterSpacing: 0.1)),
    );
  }

  Future<void> _save() async {
    try {
      await ref.read(userRepositoryProvider).patchMe({
        'settings': {
          'isPrivateProfile': _private,
          'pushEnabled': _push,
          'calendarView': _calendarView,
        },
      });
      ref.invalidate(profileMeProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save settings')));
      }
    }
  }
}
