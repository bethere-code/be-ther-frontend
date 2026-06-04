import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/be_ther_network_image.dart';
import '../../../core/design/widgets/shell_header_avatar.dart';
import '../../search/presentation/search_screen.dart';
import 'explore_providers.dart';
import 'widgets/explore_event_sheet.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  static const path = '/explore';
  static const name = 'explore';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(exploreEventsProvider);

    return AppShell(
      activeTab: ShellTab.explore,
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
              const ShellHeaderAvatar(),
              Expanded(
                child: Center(
                  child: Text('EXPLORE', style: AppTextStyles.display(28, color: AppColors.primary, letterSpacing: 0.1)),
                ),
              ),
              IconButton(
                onPressed: () => context.push(SearchScreen.path),
                icon: const Icon(Icons.search, color: AppColors.background),
              ),
            ],
          ),
        ),
      ),
      child: events.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No posts to explore yet',
                style: AppTextStyles.body(16, color: AppColors.mutedForeground),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(exploreEventsProvider.future),
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
              itemBuilder: (context, i) => _ExploreTile(event: items[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: SelectableText('$e')),
      ),
    );
  }
}

class _ExploreTile extends ConsumerWidget {
  const _ExploreTile({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = event['title'] as String? ?? '';
    final location = event['location'] as String? ?? '';
    final date = event['date'] as String? ?? '';
    final image = event['image'] as String? ?? event['imageUrl'] as String? ?? '';
    final postId = event['postId']?.toString() ?? event['_id']?.toString() ?? '';
    final attendees = event['attendees'] as int? ?? 0;
    final trending = event['trending'] as bool? ?? false;
    final bookmarked = event['bookmarked'] as bool? ?? false;
    return Material(
      color: AppColors.card,
      child: InkWell(
        onTap: postId.isEmpty
            ? null
            : () => showExploreEventSheet(
                  context: context,
                  event: event,
                  bookmarked: bookmarked,
                  onToggleBookmark: () async {
                    final next = await ref.read(exploreRepositoryProvider).toggleBookmark(postId);
                    ref.invalidate(exploreEventsProvider);
                    return next;
                  },
                ),
        child: Container(
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
                    if (bookmarked)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(Icons.bookmark, color: AppColors.primary),
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
        ),
      ),
    );
  }
}
