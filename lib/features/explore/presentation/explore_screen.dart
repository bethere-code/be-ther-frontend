import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/be_ther_network_image.dart';
import '../../profile/presentation/profile_screen.dart';
import 'explore_providers.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  static const path = '/explore';
  static const name = 'explore';

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(exploreEventsProvider(_filter));

    return AppShell(
      activeTab: ShellTab.explore,
      header: PreferredSize(
        preferredSize: const Size.fromHeight(112),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                border: Border(bottom: BorderSide(color: AppColors.border, width: AppDimens.borderThick)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.push(ProfileScreen.path),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: AppDimens.borderThick),
                        color: AppColors.muted,
                      ),
                      child: const Icon(Icons.person, color: AppColors.background),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('EXPLORE', style: AppTextStyles.display(28, color: AppColors.primary, letterSpacing: 0.1)),
                    ),
                  ),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.search, color: AppColors.background)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.muted,
                border: Border(bottom: BorderSide(color: AppColors.border, width: AppDimens.borderThick)),
              ),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'ALL',
                    selected: _filter == 'all',
                    onTap: () {
                      setState(() => _filter = 'all');
                      ref.invalidate(exploreEventsProvider(_filter));
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'EVENTS',
                    selected: _filter == 'events',
                    onTap: () {
                      setState(() => _filter = 'events');
                      ref.invalidate(exploreEventsProvider(_filter));
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'PLACES',
                    selected: _filter == 'places',
                    onTap: () {
                      setState(() => _filter = 'places');
                      ref.invalidate(exploreEventsProvider(_filter));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      child: events.when(
        data: (items) {
          return RefreshIndicator(
            onRefresh: () => ref.refresh(exploreEventsProvider(_filter).future),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final e = items[i];
                return _ExploreTile(event: e);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: SelectableText('$e')),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          border: Border.all(color: AppColors.border, width: AppDimens.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.display(13, color: selected ? AppColors.primaryForeground : AppColors.foreground, letterSpacing: 0.05),
        ),
      ),
    );
  }
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final title = event['title'] as String? ?? '';
    final location = event['location'] as String? ?? '';
    final date = event['date'] as String? ?? '';
    final image = event['image'] as String? ?? '';
    final attendees = event['attendees'] as int? ?? 0;
    final trending = event['trending'] as bool? ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border, width: AppDimens.borderThick),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                BeTherNetworkImage(url: image, fit: BoxFit.cover),
                if (trending)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: AppColors.accent,
                      child: Text('HOT', style: AppTextStyles.display(10, color: AppColors.accentForeground, letterSpacing: 0.05)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.display(15, color: AppColors.secondary, letterSpacing: 0.02)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.place, size: 14, color: AppColors.mutedForeground),
                    const SizedBox(width: 4),
                    Expanded(child: Text(location, style: AppTextStyles.body(12, color: AppColors.mutedForeground, weight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: AppColors.mutedForeground),
                    const SizedBox(width: 4),
                    Expanded(child: Text(date, style: AppTextStyles.body(11, color: AppColors.mutedForeground, weight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('$attendees', style: AppTextStyles.body(12, weight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
