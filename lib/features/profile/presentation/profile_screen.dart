import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/be_ther_network_image.dart';
import '../../settings/presentation/settings_screen.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const path = '/profile';
  static const name = 'profile';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(profileMeProvider);

    return AppShell(
      activeTab: ShellTab.home,
      showRail: true,
      header: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.secondary,
            border: Border(bottom: BorderSide(color: AppColors.border, width: AppDimens.borderThick)),
          ),
          child: Row(
            children: [
              Expanded(
                child: me.maybeWhen(
                  data: (user) => Text(
                    '@${user['username'] ?? ''}',
                    style: AppTextStyles.display(24, color: AppColors.primary, letterSpacing: 0.1),
                  ),
                  orElse: () => Text('PROFILE', style: AppTextStyles.display(24, color: AppColors.primary, letterSpacing: 0.1)),
                ),
              ),
              IconButton(
                onPressed: () => context.push(SettingsScreen.path),
                icon: const Icon(Icons.settings, color: AppColors.background),
              ),
            ],
          ),
        ),
      ),
      child: me.when(
        data: (user) {
          final username = user['username'] as String? ?? '';
          final calendar = ref.watch(profileCalendarProvider(username));

          final avatar = user['avatarUrl'] as String? ?? '';
          final display = user['displayName'] as String? ?? '';
          final bio = user['bio'] as String? ?? '';
          final stars = user['starsReceived'] as int? ?? 0;
          final places = user['placesVisited'] as int? ?? 0;
          final events = user['eventsAttended'] as int? ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(profileMeProvider);
              ref.invalidate(profileCalendarProvider(username));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppColors.card,
                    border: Border(bottom: BorderSide(color: AppColors.border, width: AppDimens.borderThick)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(border: Border.all(color: AppColors.border, width: AppDimens.borderThick)),
                            clipBehavior: Clip.hardEdge,
                            child: avatar.isNotEmpty
                                ? BeTherNetworkImage(url: avatar, fit: BoxFit.cover)
                                : Icon(Icons.person, size: 48, color: AppColors.foreground),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              children: [
                                _Stat(value: '$stars', label: 'STARS'),
                                const SizedBox(width: 8),
                                _Stat(value: '$places', label: 'HEARTS'),
                                const SizedBox(width: 8),
                                _Stat(value: '$events', label: 'PLACES'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(display, style: AppTextStyles.display(20, color: AppColors.secondary, letterSpacing: 0.02)),
                      const SizedBox(height: 8),
                      Text(bio, style: AppTextStyles.body(15, height: 1.5)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.accentForeground,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () {},
                              child: Text('STAR', style: AppTextStyles.display(16, color: AppColors.accentForeground)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: AppColors.secondaryForeground,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () => context.go('/explore'),
                              child: Text('WISH TO', style: AppTextStyles.display(16, color: AppColors.secondaryForeground)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('UPCOMING', style: AppTextStyles.display(20, color: AppColors.secondary)),
                ),
                calendar.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No events yet', style: AppTextStyles.body(14, color: AppColors.mutedForeground)),
                      );
                    }
                    return Column(
                      children: items.map((p) {
                        final loc = p['location'] as String? ?? '';
                        final img = p['imageUrl'] as String? ?? '';
                        final st = p['status'] as String? ?? 'going';
                        return ListTile(
                          tileColor: AppColors.card,
                          leading: SizedBox(
                            width: 56,
                            height: 56,
                            child: img.isNotEmpty ? BeTherNetworkImage(url: img, fit: BoxFit.cover) : const Icon(Icons.event),
                          ),
                          title: Text(loc, style: AppTextStyles.body(15, weight: FontWeight.w800)),
                          subtitle: Text(st.toUpperCase(), style: AppTextStyles.display(12, color: AppColors.primary)),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('$e', style: AppTextStyles.body(14, color: AppColors.destructive)),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: SelectableText('$e')),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.display(22, color: AppColors.secondary, letterSpacing: 0.02)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.body(11, color: AppColors.mutedForeground, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}
