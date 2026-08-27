import 'dart:async';

import 'package:be_ther/core/design/app_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/background_tasks/notification_syncer.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../explore/domain/explore_event.dart';
import '../../explore/presentation/widgets/explore_event_sheet.dart';
import '../../feed/presentation/calendar_status_store.dart';
import '../../feed/presentation/feed_providers.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../profile/presentation/profile_screen.dart';
import 'notifications_providers.dart';
import 'widgets/notification_list_tile.dart';
import 'package:be_ther/core/ui/app_toast.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  static const path = '/notifications';
  static const name = 'notifications';

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();
  String? _busyNotificationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Full list refresh on open (badge poll alone does not load items).
      unawaited(ref.read(notificationSyncerProvider).syncNow());
      _markAllRead();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      // Badge clears on next successful refresh; avoid blocking the screen.
    }
  }

  Future<void> _respondFollowRequest({
    required Map<String, dynamic> n,
    required String action,
  }) async {
    final id = n['_id']?.toString() ?? '';
    final actor = n['actorUserId'] is Map<String, dynamic>
        ? n['actorUserId'] as Map<String, dynamic>
        : <String, dynamic>{};
    final username = (actor['username'] as String?)?.trim() ?? '';
    if (username.isEmpty || _busyNotificationId != null) return;

    setState(() => _busyNotificationId = id);
    try {
      await ref.read(notificationsRepositoryProvider).respondFollowRequest(
            username: username,
            action: action,
          );
      if (!mounted) return;
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(profileViewProvider(null));
      ref.invalidate(profileViewProvider(username));
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busyNotificationId = null);
    }
  }

  Future<void> _openNotification({
    required BuildContext context,
    required Map<String, dynamic> n,
  }) async {
    final actor = n['actorUserId'] is Map<String, dynamic>
        ? n['actorUserId'] as Map<String, dynamic>
        : <String, dynamic>{};
    final username = actor['username'] as String? ?? '';
    final type = n['type'] as String? ?? 'follow';
    final post = n['postId'] is Map<String, dynamic>
        ? n['postId'] as Map<String, dynamic>
        : null;

    if (!context.mounted) return;

    final isFollow =
        type == 'follow' ||
        type == 'star' ||
        type == 'follow_request' ||
        type == 'follow_request_accepted' ||
        type == 'follow_request_accepted_owner' ||
        type == 'follow_request_rejected_owner';
    if (isFollow && username.isNotEmpty) {
      context.push(ProfileScreen.pathForUser(username));
      return;
    }
    if (post != null && post.isNotEmpty) {
      final postId = (post['postId'] ?? post['_id'])?.toString() ?? '';
      var payload = <String, dynamic>{
        ...post,
        'postId': postId,
      };

      // Fresh fetch wins — notification embeds can omit viewer calendar fields.
      if (postId.isNotEmpty) {
        try {
          final fresh =
              await ref.read(postsRepositoryProvider).fetchPost(postId);
          payload = {
            ...fresh.toJson(),
            'postId': fresh.id,
          };
          final status = fresh.calendarStatus;
          final inCal = fresh.inCalendar;
          ref.read(calendarStatusStoreProvider.notifier).syncFromApi(
                postId,
                status ?? (inCal ? 'going' : null),
              );
        } catch (_) {
          // Fall back to enriched notification payload / local store.
          final status = payload['calendarStatus'] as String?;
          final inCal = payload['inCalendar'] as bool? ?? false;
          if (status != null || inCal) {
            ref.read(calendarStatusStoreProvider.notifier).syncFromApi(
                  postId,
                  status ?? 'going',
                );
          }
        }
      }

      if (!context.mounted) return;
      await showExploreEventSheet(
        context: context,
        event: ExploreEvent.fromJson(payload),
      );
    } else if (username.isNotEmpty) {
      context.push(ProfileScreen.pathForUser(username));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(notificationsProvider);

    return AppShell(
      activeTab: ShellTab.notifications,
      showRail: true,
      header: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: const BoxDecoration(
            color: AppColors.secondary,
            border: Border(
              bottom: BorderSide(
                color: AppColors.border,
                width: AppDimens.borderThick,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Matches Figma Make header spacer (no avatar in alerts header).
              InkWell(
                onTap: _scrollToTop,
                child: Image.asset(
                  AppImages.betherNewLogo,
                  fit: BoxFit.contain,
                  width: 60,
                ),
              ),
              Center(
                child: Text(
                  'ALERTS',
                  style: AppTextStyles.display(
                    28,
                    color: AppColors.primary,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(width: 50),
              // IconButton(
              //   onPressed: () => _showMessagesInfo(context),
              //   icon: const Icon(
              //     Icons.mail_outline,
              //     color: AppColors.background,
              //     size: 24,
              //   ),
              // ),
            ],
          ),
        ),
      ),
      child: ColoredBox(
        color: AppColors.background,
        child: list.when(
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none,
                      size: 48,
                      color: AppColors.mutedForeground,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: AppTextStyles.body(
                        15.2,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.card,
              onRefresh: () async {
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadNotificationCountProvider);
                await ref.read(notificationsProvider.future);
              },
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                // Full-width rows; right rail floats over content (Figma Make).
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final n = items[i];
                  final nId = n['_id']?.toString() ?? '';
                  final type = n['type'] as String? ?? '';
                  return NotificationListTile(
                    notification: n,
                    onOpen: () => _openNotification(context: context, n: n),
                    actionsBusy: _busyNotificationId == nId,
                    onAcceptFollowRequest: type == 'follow_request'
                        ? () => _respondFollowRequest(n: n, action: 'accept')
                        : null,
                    onRejectFollowRequest: type == 'follow_request'
                        ? () => _respondFollowRequest(n: n, action: 'reject')
                        : null,
                  );
                },
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelectableText(
                    '$e',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(14, color: AppColors.foreground),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                    },
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
