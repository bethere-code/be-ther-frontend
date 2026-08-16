import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/utils/link_utils.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../launch/presentation/launch_screen.dart';
import '../../profile/presentation/profile_providers.dart';
import 'widgets/profile_edit_section.dart';

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

  /// Default for every account until the user explicitly changes it.
  String _calendarView = 'full';
  var _hydrateStarted = false;

  /// True after server settings are applied (or failed → local defaults).
  var _settingsReady = false;

  static String _normalizeCalendarView(Object? raw) {
    return raw == 'events-only' ? 'events-only' : 'full';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrateStarted) return;
    _hydrateStarted = true;
    Future.microtask(() async {
      try {
        final user = await ref.read(profileMeProvider.future);
        if (!mounted) return;
        setState(() {
          _private = user.settings.isPrivateProfile;
          _push = user.settings.pushEnabled;
          _calendarView = _normalizeCalendarView(user.settings.calendarView);
          _settingsReady = true;
        });
        return;
      } catch (_) {
        // Keep local defaults (full calendar).
      }
      if (mounted) setState(() => _settingsReady = true);
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
        title: Text(
          'SETTINGS',
          style: AppTextStyles.display(
            32,
            color: AppColors.primary,
            letterSpacing: 0.1,
          ),
        ),
      ),
      body: me.when(
        data: (_) {
          return ListView(
            children: [
              _sectionTitle('PROFILE'),
              const ProfileEditSection(),
              // SwitchListTile(
              //   title: Text(
              //     _private ? 'Private Profile' : 'Public Profile',
              //     style: AppTextStyles.body(16, weight: FontWeight.w800),
              //   ),
              //   subtitle: Text(
              //     _private
              //         ? 'Only starred users can see your posts'
              //         : 'Anyone can view your profile and posts',
              //     style: AppTextStyles.body(
              //       13,
              //       color: AppColors.mutedForeground,
              //     ),
              //   ),
              //   value: _private,
              //   onChanged: (v) async {
              //     setState(() => _private = v);
              //     await _save();
              //   },
              // ),
              const Divider(
                height: 1,
                thickness: AppDimens.borderThick,
                color: AppColors.border,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'CALENDAR VIEW',
                  style: AppTextStyles.display(
                    13,
                    color: AppColors.mutedForeground,
                    letterSpacing: 0.08,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _CalendarViewButton(
                        label: 'FULL CALENDAR',
                        selected: _calendarView == 'full',
                        onTap: () async {
                          if (_calendarView == 'full') return;
                          setState(() {
                            _calendarView = 'full';
                            _settingsReady = true;
                          });
                          await _save();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CalendarViewButton(
                        label: 'EVENTS ONLY',
                        selected: _calendarView == 'events-only',
                        onTap: () async {
                          if (_calendarView == 'events-only') return;
                          setState(() {
                            _calendarView = 'events-only';
                            _settingsReady = true;
                          });
                          await _save();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Events only lists every event on your profile — past and upcoming.',
                  style: AppTextStyles.body(
                    12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              _sectionTitle('NOTIFICATIONS'),
              SwitchListTile(
                title: Text(
                  'Push Notifications',
                  style: AppTextStyles.body(16, weight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Stars and wishlists',
                  style: AppTextStyles.body(
                    13,
                    color: AppColors.mutedForeground,
                  ),
                ),
                value: _push,
                onChanged: (v) async {
                  setState(() => _push = v);
                  await _save();
                },
              ),
              const Divider(
                height: 1,
                thickness: AppDimens.borderThick,
                color: AppColors.border,
              ),
              _sectionTitle('ACCOUNT'),
              ListTile(
                title: Text(
                  'Log Out',
                  style: AppTextStyles.body(
                    16,
                    weight: FontWeight.w800,
                    color: AppColors.destructive,
                  ),
                ),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(
                        'LOG OUT?',
                        style: AppTextStyles.display(
                          22,
                          color: AppColors.secondary,
                        ),
                      ),
                      content: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('CANCEL'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.destructive,
                          ),
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
              const Divider(
                height: 1,
                thickness: AppDimens.borderThick,
                color: AppColors.border,
              ),
              _sectionTitle('SUPPORT'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Need help? \nJust drop us an email—we\'re here for you! 😊',
                  style: AppTextStyles.body(
                    14,
                    color: AppColors.mutedForeground,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.mail_outline,
                  color: AppColors.secondary,
                ),
                title: Text(
                  'be.there.accnts@gmail.com',
                  style: AppTextStyles.body(
                    15,
                    weight: FontWeight.w700,
                    color: AppColors.secondary,
                  ),
                ),
                onTap: () => unawaited(
                  openExternalUrl(context, 'mailto:be.there.accnts@gmail.com'),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'BE THER v1.0.0',
                  style: AppTextStyles.body(
                    13,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
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
      child: Text(
        text,
        style: AppTextStyles.display(
          13,
          color: AppColors.mutedForeground,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Future<void> _save() async {
    try {
      final settings = <String, dynamic>{
        'isPrivateProfile': _private,
        'pushEnabled': _push,
      };
      // Avoid writing a stale calendarView before hydrate finishes.
      if (_settingsReady) {
        settings['calendarView'] = _calendarView;
      }
      final updated = await ref.read(userRepositoryProvider).patchMe({
        'settings': settings,
      });
      ref.read(authNotifierProvider.notifier).updateUser(updated);
      ref.invalidate(profileMeProvider);
      ref.invalidate(profileViewProvider(null));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save settings')),
        );
      }
    }
  }
}

class _CalendarViewButton extends StatelessWidget {
  const _CalendarViewButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.accent : AppColors.card;
    final fg = selected ? AppColors.accentForeground : AppColors.primary;
    return SizedBox(
      height: 48,
      child: Material(
        color: bg,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.border,
                width: selected ? AppDimens.borderThick : AppDimens.border,
              ),
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.display(
                  13,
                  color: fg,
                  letterSpacing: 0.04,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
