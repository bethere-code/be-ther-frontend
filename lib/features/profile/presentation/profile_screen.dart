import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/author_avatar.dart';
import '../../../core/design/widgets/be_ther_network_image.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_route_observer.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../explore/presentation/explore_providers.dart';
import '../../feed/presentation/feed_providers.dart';
import '../../search/presentation/search_providers.dart';
import '../../settings/presentation/settings_screen.dart';
import 'block_session.dart';
import 'profile_connections_screen.dart';
import 'profile_events_screen.dart';
import 'profile_providers.dart';
import 'widgets/profile_actions_sheet.dart';
import 'widgets/profile_event_sheet.dart';
import 'widgets/profile_private_notice.dart';
import 'package:be_ther/core/ui/app_toast.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.username});

  /// When null, shows the authenticated user's profile.
  final String? username;

  static const path = '/profile';
  static const name = 'profile';

  static String pathForUser(String username) => '/profile/$username';

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with RouteAware {
  static const _daysPerChunk = 28;
  static const _dayNames = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  static const _monthNames = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  final _profileScrollController = ScrollController();
  final _calendarScrollController = ScrollController();

  /// First date in the grid. One past page is cached on open for smooth scroll-back.
  late DateTime _gridStart;
  int _dayCount = _daysPerChunk * 2;
  bool _loadingMoreDays = false;
  bool _pendingJumpToToday = true;
  bool _routeSubscribed = false;

  /// Username we already refreshed lists for on this visit.
  String? _hydratedListsFor;

  @override
  void initState() {
    super.initState();
    _seedCalendarAroundToday();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_routeSubscribed && route is PageRoute<void>) {
      appRouteObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username) {
      // Switching profiles — allow a fresh hydrate for the new user.
      _hydratedListsFor = null;
      _pendingJumpToToday = true;
    }
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    _profileScrollController.dispose();
    _calendarScrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Returning to this profile (e.g. from Events / settings) — refresh lists.
    _hydratedListsFor = null;
  }

  DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Cache one past chunk + one future chunk. Viewport jumps to today after layout.
  void _seedCalendarAroundToday() {
    final today = _todayDate();
    _gridStart = today.subtract(const Duration(days: _daysPerChunk));
    _dayCount = _daysPerChunk * 2;
    _pendingJumpToToday = true;
  }

  void _jumpCalendarToTodayIfNeeded() {
    if (!_pendingJumpToToday) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pendingJumpToToday) return;
      if (!_calendarScrollController.hasClients) return;
      _pendingJumpToToday = false;
      final cell = MediaQuery.sizeOf(context).width / 4;
      // Today is at index [_daysPerChunk] after the cached past page.
      final offset = (_daysPerChunk / 4) * cell;
      final max = _calendarScrollController.position.maxScrollExtent;
      _calendarScrollController.jumpTo(offset.clamp(0.0, max));
    });
  }

  /// Only the calendar grid scrolls for past/future — nav bar stays fixed.
  bool _onCalendarScrollNotification(ScrollNotification notification) {
    if (_loadingMoreDays) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is! ScrollUpdateNotification &&
        notification is! OverscrollNotification) {
      return false;
    }

    final m = notification.metrics;

    final scrollingTowardPast =
        notification is ScrollUpdateNotification &&
        notification.scrollDelta != null &&
        notification.scrollDelta! < 0;
    final pullingPast =
        notification is OverscrollNotification && notification.overscroll < 0;

    // Past: near the top of the calendar grid (scroll toward older days).
    if (m.pixels < 220 && (scrollingTowardPast || pullingPast)) {
      _prependPastDays();
      return false;
    }

    // Future: near the bottom of the calendar grid.
    if (m.maxScrollExtent > 0 && m.pixels >= m.maxScrollExtent - 280) {
      _appendFutureDays();
    }

    return false;
  }

  void _appendFutureDays() {
    if (_loadingMoreDays) return;
    _loadingMoreDays = true;
    setState(() => _dayCount += _daysPerChunk);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadingMoreDays = false;
    });
  }

  void _prependPastDays() {
    if (_loadingMoreDays || !_calendarScrollController.hasClients) return;

    _loadingMoreDays = true;
    final beforeMax = _calendarScrollController.position.maxScrollExtent;
    final beforePixels = _calendarScrollController.position.pixels;

    setState(() {
      _gridStart = _gridStart.subtract(const Duration(days: _daysPerChunk));
      _dayCount += _daysPerChunk;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_calendarScrollController.hasClients) {
        _loadingMoreDays = false;
        return;
      }
      final delta =
          _calendarScrollController.position.maxScrollExtent - beforeMax;
      if (delta > 0) {
        _calendarScrollController.jumpTo(beforePixels + delta);
      }
      _loadingMoreDays = false;
    });
  }

  void _goToToday() {
    setState(_seedCalendarAroundToday);
  }

  void _shiftWeek(int direction) {
    setState(() {
      _gridStart = _gridStart.add(Duration(days: 7 * direction));
    });
  }

  void _scrollToProfileSection() {
    if (!_profileScrollController.hasClients) return;
    _profileScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Map<String, ProfileCalendarEvent> _eventsByDate(
    List<Map<String, dynamic>> items,
  ) {
    final deleted = ref.read(deletedPostIdsProvider);
    final blocked = ref.read(sessionBlockedAuthorsProvider);
    final editedPosts = ref.read(editedPostsProvider);
    final map = <String, ProfileCalendarEvent>{};
    for (final item in items) {
      var event = ProfileCalendarEvent.fromJson(item);
      event = overlayEditedProfileCalendarEvent(event, editedPosts);
      if (deleted.contains(event.postId)) continue;
      if (isAuthorSessionBlocked(
        blocked,
        username: event.author?.username,
        userId: event.author?.id,
      )) {
        continue;
      }
      final key = DateFormat('yyyy-MM-dd').format(event.date);
      map.putIfAbsent(key, () => event);
    }
    return map;
  }

  List<ProfileCalendarEvent> _eventsChronological(
    List<Map<String, dynamic>> items,
  ) {
    final deleted = ref.read(deletedPostIdsProvider);
    final blocked = ref.read(sessionBlockedAuthorsProvider);
    final editedPosts = ref.read(editedPostsProvider);
    final events =
        items
            .map(ProfileCalendarEvent.fromJson)
            .map((e) => overlayEditedProfileCalendarEvent(e, editedPosts))
            .where(
              (e) =>
                  !deleted.contains(e.postId) &&
                  !isAuthorSessionBlocked(
                    blocked,
                    username: e.author?.username,
                    userId: e.author?.id,
                  ),
            )
            .toList()
          ..sort((a, b) {
            final byDate = a.date.compareTo(b.date);
            if (byDate != 0) return byDate;
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });
    return events;
  }

  String _calendarViewMode(ProfileUser user, {required bool isOwn}) {
    if (!isOwn) return 'full';
    return user.settings.calendarView;
  }

  String _profileErrorMessage(Object error) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _setOwnCalendarView(String mode) async {
    try {
      final updated = await ref.read(userRepositoryProvider).patchMe({
        'settings': {'calendarView': mode},
      });
      ref.read(authNotifierProvider.notifier).updateUser(updated);
      ref.invalidate(profileMeProvider);
      ref.invalidate(profileViewProvider(widget.username));
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _refresh(String calendarUsername) async {
    ref.invalidate(profileViewProvider(widget.username));
    ref.invalidate(profileCalendarProvider(calendarUsername));
    ref.invalidate(profileEventsProvider(calendarUsername));
    await Future.wait([
      ref.read(profileViewProvider(widget.username).future),
      ref.read(profileCalendarProvider(calendarUsername).future),
      ref.read(profileEventsProvider(calendarUsername).future),
    ]);
  }

  /// Fresh calendar + authored-events fetch for this profile visit.
  /// Does not block the UI; Events tab and calendar pick up the new data.
  void _hydrateProfileLists(String username) {
    if (username.isEmpty || _hydratedListsFor == username) return;
    _hydratedListsFor = username;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(profileCalendarProvider(username));
      ref.invalidate(profileEventsProvider(username));
      // Soft refresh header counts (events / followers) without a full spinner.
      ref.invalidate(profileViewProvider(widget.username));

      unawaited(ref.read(profileCalendarProvider(username).future));
      unawaited(ref.read(profileEventsProvider(username).future));
      unawaited(ref.read(profileViewProvider(widget.username).future));
    });
  }

  Widget _buildCalendarGrid({
    required Map<String, ProfileCalendarEvent> eventsByDate,
    required DateTime todayDate,
    required String username,
    required bool isOwnProfile,
  }) {
    // 4 equal square cells → one row height == cell width.
    final rowHeight = MediaQuery.sizeOf(context).width / 4;
    return NotificationListener<ScrollNotification>(
      onNotification: _onCalendarScrollNotification,
      child: GridView.builder(
        controller: _calendarScrollController,
        physics: AlwaysScrollableScrollPhysics(
          parent: _WeekRowSnapScrollPhysics(rowHeight: rowHeight),
        ),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1,
        ),
        itemCount: _dayCount,
        itemBuilder: (context, index) {
          final date = _gridStart.add(Duration(days: index));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final event = eventsByDate[dateKey];
          final isToday =
              date.year == todayDate.year &&
              date.month == todayDate.month &&
              date.day == todayDate.day;
          final isPast = date.isBefore(todayDate);
          final faded = isPast && event == null;

          return _CalendarDayCell(
            date: date,
            event: event,
            isToday: isToday,
            isMonthStart: date.day == 1,
            faded: faded,
            monthNames: _monthNames,
            dayNames: _dayNames,
            onTap: event == null
                ? null
                : () => _openEvent(
                    event: event,
                    username: username,
                    isOwnProfile: isOwnProfile,
                  ),
          );
        },
      ),
    );
  }

  void _openEvent({
    required ProfileCalendarEvent event,
    required String username,
    required bool isOwnProfile,
  }) {
    showProfileEventSheet(
      context: context,
      event: event,
      profileUsername: username,
      isOwnProfile: isOwnProfile,
      onCalendarChanged: () {
        ref.invalidate(profileCalendarProvider(username));
        ref.invalidate(profileEventsProvider(username));
        ref.invalidate(feedProvider);
        ref.invalidate(exploreEventsProvider);
        ref.invalidate(searchResultsProvider);
        if (isOwnProfile) {
          ref.invalidate(profileViewProvider(widget.username));
          ref.invalidate(profileMeProvider);
        }
      },
    );
  }

  Future<({bool following, bool requested, int followersCount})> _toggleFollow(
    String username,
  ) async {
    final result = await ref.read(userRepositoryProvider).toggleFollow(username);
    _refreshAfterProfileSocial(username);
    return result;
  }

  void _refreshAfterProfileSocial(String username) {
    ref.invalidate(profileViewProvider(widget.username));
    ref.invalidate(profileViewProvider(username));
    ref.invalidate(profileCalendarProvider(username));
    ref.invalidate(profileEventsProvider(username));
    ref.invalidate(
      profileConnectionsProvider((
        username: username,
        mode: ProfileConnectionsMode.followers,
      )),
    );
    ref.invalidate(
      profileConnectionsProvider((
        username: username,
        mode: ProfileConnectionsMode.following,
      )),
    );
    ref.invalidate(feedProvider);
    ref.invalidate(exploreEventsProvider);
  }

  Future<void> _openProfileActions(ProfileUser user) async {
    final username = user.username;
    await showProfileActionsSheet(
      context: context,
      username: username,
      isFollowedBy: user.isFollowedBy,
      isBlocked: user.isBlocked,
      onRemoveFollower: () async {
        try {
          await ref.read(userRepositoryProvider).removeFollower(username);
          _refreshAfterProfileSocial(username);
          if (!mounted) return;
          AppToast.show(context, 'Follower removed');
        } catch (e) {
          if (!mounted) return;
          AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
        }
      },
      onBlock: () async {
        try {
          await blockUserOptimistic(ref, username: username);
          _refreshAfterProfileSocial(username);
          if (!mounted) return;
          AppToast.show(context, 'User blocked');
        } catch (e) {
          if (!mounted) return;
          AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
        }
      },
      onUnblock: () async {
        try {
          await unblockUserOptimistic(ref, username: username);
          _refreshAfterProfileSocial(username);
          if (!mounted) return;
          AppToast.show(context, 'User unblocked');
        } catch (e) {
          if (!mounted) return;
          AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
        }
      },
      onReport: (reason, details) async {
        try {
          await ref.read(userRepositoryProvider).reportUser(
                username: username,
                reason: reason,
                details: details,
              );
          if (!mounted) return;
          AppToast.show(context, 'Report sent. The team will review it.');
        } catch (e) {
          if (!mounted) return;
          AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileViewProvider(widget.username));
    final routeUsername = widget.username ?? '';

    return profileAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => AppShell(
        activeTab: ShellTab.home,
        header: routeUsername.isEmpty
            ? null
            : _ProfileHeader(
                username: routeUsername,
                isOwnProfile: false,
                onBack: () => context.pop(),
              ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) {
        final private = isPrivateProfileError(e);
        return AppShell(
          activeTab: ShellTab.home,
          header: _ProfileHeader(
            username: routeUsername,
            isOwnProfile: widget.username == null,
            onBack: () => context.pop(),
          ),
          child: private
              ? _PrivateProfilePane(
                  username: routeUsername,
                  onFollow: routeUsername.isEmpty
                      ? null
                      : () async {
                          await _toggleFollow(routeUsername);
                        },
                )
              : _ProfileErrorPane(
                  message: _profileErrorMessage(e),
                  onRetry: () =>
                      ref.invalidate(profileViewProvider(widget.username)),
                ),
        );
      },
      data: (user) {
        final username = user.username;
        final isOwnProfile = user.isOwnProfile || widget.username == null;
        final locked = !isOwnProfile && isPrivateProfileLocked(user);
        if (!locked) {
          _hydrateProfileLists(username);
        }
        final calendarAsync = locked
            ? const AsyncValue<List<Map<String, dynamic>>>.data([])
            : ref.watch(profileCalendarProvider(username));
        if (!locked) {
          ref.watch(profileEventsProvider(username));
        }
        ref.watch(deletedPostIdsProvider);
        ref.watch(sessionBlockedAuthorsProvider);
        ref.watch(editedPostsProvider);

        final calendarBlocked = calendarAsync.hasError &&
            isPrivateProfileError(calendarAsync.error!);
        final showPrivateCalendar = locked || calendarBlocked;

        Widget profileInfo({bool lockCounts = false}) => _ProfileInfoSection(
          user: user,
          isOwnProfile: isOwnProfile,
          lockCounts: lockCounts,
          onToggleFollow: isOwnProfile || user.isBlocked
              ? null
              : () => _toggleFollow(username),
        );

        return AppShell(
          activeTab: ShellTab.home,
          header: _ProfileHeader(
            username: username,
            isOwnProfile: isOwnProfile,
            onBack: () => context.pop(),
            onTitleTap: _scrollToProfileSection,
            onSettings: isOwnProfile
                ? () => context.push(SettingsScreen.path)
                : null,
            onMore: isOwnProfile ? null : () => _openProfileActions(user),
          ),
          child: showPrivateCalendar
              ? ColoredBox(
                  color: AppColors.background,
                  child: Column(
                    children: [
                      profileInfo(lockCounts: true),
                      const Expanded(child: ProfilePrivateNotice()),
                    ],
                  ),
                )
              : calendarAsync.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            data: (items) {
              final eventsByDate = _eventsByDate(items);
              final todayDate = _todayDate();
              final calendarView = _calendarViewMode(user, isOwn: isOwnProfile);
              final eventsOnly = calendarView == 'events-only';
              if (!eventsOnly) {
                _jumpCalendarToTodayIfNeeded();
              }

              // Profile (natural height, capped) → fixed nav → scrolling calendar.
              return ColoredBox(
                color: AppColors.background,
                child: Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                      ),
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.card,
                        onRefresh: () => _refresh(username),
                        child: SingleChildScrollView(
                          controller: _profileScrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: profileInfo(),
                        ),
                      ),
                    ),
                    if (eventsOnly)
                      Expanded(
                        child: _EventsOnlyGrid(
                          events: _eventsChronological(items),
                          todayDate: todayDate,
                          monthNames: _monthNames,
                          dayNames: _dayNames,
                          onShowFullCalendar: isOwnProfile
                              ? () => _setOwnCalendarView('full')
                              : null,
                          onOpenEvent: (event) => _openEvent(
                            event: event,
                            username: username,
                            isOwnProfile: isOwnProfile,
                          ),
                        ),
                      )
                    else ...[
                      _CalendarNavBar(
                        onPrevious: () => _shiftWeek(-1),
                        onToday: _goToToday,
                        onNext: () => _shiftWeek(1),
                      ),
                      Expanded(
                        child: _buildCalendarGrid(
                          eventsByDate: eventsByDate,
                          todayDate: todayDate,
                          username: username,
                          isOwnProfile: isOwnProfile,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => ColoredBox(
              color: AppColors.background,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: profileInfo()),
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
            ),
            error: (e, _) => ColoredBox(
              color: AppColors.background,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: profileInfo()),
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _profileErrorMessage(e),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(
                            14,
                            color: AppColors.destructive,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileErrorPane extends StatelessWidget {
  const _ProfileErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined, size: 40, color: AppColors.secondary),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(16, color: AppColors.secondary),
              ),
              const SizedBox(height: 20),
              Material(
                color: AppColors.primary,
                child: InkWell(
                  onTap: onRetry,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        'TRY AGAIN',
                        style: AppTextStyles.display(
                          15,
                          color: AppColors.primaryForeground,
                          letterSpacing: 0.06,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivateProfilePane extends StatefulWidget {
  const _PrivateProfilePane({required this.username, this.onFollow});

  final String username;
  final Future<void> Function()? onFollow;

  @override
  State<_PrivateProfilePane> createState() => _PrivateProfilePaneState();
}

class _PrivateProfilePaneState extends State<_PrivateProfilePane> {
  bool _busy = false;

  Future<void> _follow() async {
    final follow = widget.onFollow;
    if (follow == null || _busy) return;
    setState(() => _busy = true);
    try {
      await follow();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.username;
    return ColoredBox(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            username.isEmpty ? 'Private profile' : '@$username',
            style: AppTextStyles.display(22, color: AppColors.secondary),
          ),
          const SizedBox(height: 12),
          Text(
            'This profile is private. Follow to see their calendar and events.',
            style: AppTextStyles.body(15, color: AppColors.mutedForeground, height: 1.4),
          ),
          if (widget.onFollow != null) ...[
            const SizedBox(height: 20),
            _FollowButton(
              isFollowing: false,
              busy: _busy,
              onPressed: _follow,
            ),
          ],
        ],
      ),
    );
  }
}

class _EventsOnlyGrid extends StatelessWidget {
  const _EventsOnlyGrid({
    required this.events,
    required this.todayDate,
    required this.monthNames,
    required this.dayNames,
    required this.onOpenEvent,
    this.onShowFullCalendar,
  });

  final List<ProfileCalendarEvent> events;
  final DateTime todayDate;
  final List<String> monthNames;
  final List<String> dayNames;
  final void Function(ProfileCalendarEvent event) onOpenEvent;
  final VoidCallback? onShowFullCalendar;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'There are no events to show.',
                textAlign: TextAlign.center,
                style: AppTextStyles.display(
                  22,
                  color: AppColors.secondary,
                  letterSpacing: 0.04,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Add events from the feed or switch back to the full calendar.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  14,
                  color: AppColors.mutedForeground,
                  height: 1.35,
                ),
              ),
              if (onShowFullCalendar != null) ...[
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentForeground,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: onShowFullCalendar,
                    child: Text(
                      'SHOW FULL CALENDAR',
                      style: AppTextStyles.display(
                        14,
                        color: AppColors.accentForeground,
                        letterSpacing: 0.05,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Same square cells as the full calendar — only days that have events.
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1,
      ),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final date = DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
        );
        final isToday =
            date.year == todayDate.year &&
            date.month == todayDate.month &&
            date.day == todayDate.day;
        // Month banner when this event starts a new month vs the previous box.
        final prev = index > 0 ? events[index - 1].date : null;
        final isMonthStart =
            prev == null || prev.year != date.year || prev.month != date.month;

        return _CalendarDayCell(
          date: date,
          event: event,
          isToday: isToday,
          isMonthStart: isMonthStart,
          faded: false,
          monthNames: monthNames,
          dayNames: dayNames,
          onTap: () => onOpenEvent(event),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget implements PreferredSizeWidget {
  const _ProfileHeader({
    required this.username,
    required this.isOwnProfile,
    required this.onBack,
    this.onTitleTap,
    this.onSettings,
    this.onMore,
  });

  final String username;
  final bool isOwnProfile;
  final VoidCallback onBack;
  final VoidCallback? onTitleTap;
  final VoidCallback? onSettings;
  final VoidCallback? onMore;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
        children: [
          if (!isOwnProfile)
            IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.background,
                size: 24,
              ),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: GestureDetector(
              onTap: onTitleTap,
              behavior: HitTestBehavior.opaque,
              child: Text(
                '@$username',
                textAlign: TextAlign.center,
                style: AppTextStyles.display(
                  24,
                  color: AppColors.primary,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
          if (onSettings != null)
            IconButton(
              onPressed: onSettings,
              icon: const Icon(
                Icons.settings,
                color: AppColors.background,
                size: 24,
              ),
            )
          else if (onMore != null)
            IconButton(
              tooltip: 'More options',
              onPressed: onMore,
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.background,
                size: 24,
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _ProfileInfoSection extends ConsumerStatefulWidget {
  const _ProfileInfoSection({
    required this.user,
    required this.isOwnProfile,
    this.onToggleFollow,
    this.lockCounts = false,
  });

  final ProfileUser user;
  final bool isOwnProfile;
  final bool lockCounts;
  final Future<({bool following, bool requested, int followersCount})> Function()?
  onToggleFollow;

  @override
  ConsumerState<_ProfileInfoSection> createState() =>
      _ProfileInfoSectionState();
}

class _ProfileInfoSectionState extends ConsumerState<_ProfileInfoSection> {
  bool _followBusy = false;
  late bool _isFollowing;
  late bool _followRequestPending;
  late int _followersCount;

  @override
  void initState() {
    super.initState();
    _readFollowState(widget.user);
  }

  @override
  void didUpdateWidget(covariant _ProfileInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Don't clobber an in-flight optimistic update with stale provider data.
    if (_followBusy) return;
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.isFollowing != widget.user.isFollowing ||
        oldWidget.user.followRequestPending != widget.user.followRequestPending ||
        oldWidget.user.followersCount != widget.user.followersCount) {
      setState(() => _readFollowState(widget.user));
    }
  }

  void _readFollowState(ProfileUser user) {
    _isFollowing = user.isFollowing;
    _followRequestPending = user.followRequestPending;
    _followersCount = user.followersCount;
  }

  Future<void> _handleToggleFollow() async {
    final toggle = widget.onToggleFollow;
    if (toggle == null || _followBusy) return;

    final wasFollowing = _isFollowing;
    final wasRequested = _followRequestPending;
    if (wasFollowing) {
      final username = widget.user.username.trim();
      final label = username.isNotEmpty ? '@$username' : 'this user';
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'UNFOLLOW?',
            style: AppTextStyles.display(22, color: AppColors.secondary),
          ),
          content: Text('Stop following $label?'),
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
              child: const Text('UNFOLLOW'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final previousCount = _followersCount;
    final isPrivate = widget.user.settings.isPrivateProfile;

    // Optimistic UI — private requests do not change follower count.
    setState(() {
      _followBusy = true;
      if (wasFollowing) {
        _isFollowing = false;
        _followRequestPending = false;
        _followersCount = (previousCount - 1).clamp(0, 1 << 30);
      } else if (wasRequested) {
        _followRequestPending = false;
      } else if (isPrivate) {
        _followRequestPending = true;
      } else {
        _isFollowing = true;
        _followersCount = previousCount + 1;
      }
    });

    try {
      final result = await toggle();
      if (!mounted) return;
      setState(() {
        _isFollowing = result.following;
        _followRequestPending = result.requested;
        _followersCount = result.followersCount;
        _followBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFollowing = wasFollowing;
        _followRequestPending = wasRequested;
        _followersCount = previousCount;
        _followBusy = false;
      });
      AppToast.show(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.user.avatarUrl;
    final display = widget.user.displayName;
    final bio = widget.user.bio;
    final events = widget.user.eventsCount;
    final following = widget.user.followingCount;
    final joined = widget.user.joined;
    // Badges paused — multi-signal scoring later (activity, events, followers, …).
    // final badge = widget.user.badge;
    final username = widget.user.username;
    final privateLocked = !widget.isOwnProfile &&
        !widget.user.isFollowing &&
        (widget.user.settings.isPrivateProfile || widget.lockCounts);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: AppDimens.borderThick,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthorAvatar(
                avatarUrl: avatar,
                username: username,
                // badge: badge,
                size: 96,
                interactive: false,
                heroTag: GoRouterState.of(context).extra is String
                    ? GoRouterState.of(context).extra as String
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    _Stat(
                      value: '$events',
                      label: 'EVENTS',
                      onTap: username.isEmpty || privateLocked
                          ? null
                          : () => context.push(
                              ProfileEventsScreen.pathFor(username),
                            ),
                    ),
                    const SizedBox(width: 8),
                    _Stat(
                      value: '$_followersCount',
                      label: 'FOLLOWERS',
                      onTap: username.isEmpty ||
                              privateLocked ||
                              _followersCount < 1
                          ? null
                          : () => context.push(
                              ProfileConnectionsScreen.followersPath(username),
                            ),
                    ),
                    const SizedBox(width: 8),
                    _Stat(
                      value: '$following',
                      label: 'FOLLOWING',
                      onTap: username.isEmpty || privateLocked || following < 1
                          ? null
                          : () => context.push(
                              ProfileConnectionsScreen.followingPath(username),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  display,
                  style: AppTextStyles.display(
                    20,
                    color: AppColors.secondary,
                    letterSpacing: 0.02,
                  ),
                ),
              ),
              // if (!widget.isOwnProfile && _isFollowing && widget.user.canDM)
              //   const Icon(
              //     Icons.mail_outline,
              //     color: AppColors.primary,
              //     size: 20,
              //   ),
            ],
          ),
          // if (badge != null) ...[
          //   const SizedBox(height: 6),
          //   Text(
          //     '${badge.toUpperCase()} MEMBER',
          //     style: AppTextStyles.body(14, weight: FontWeight.w800, color: widget.badgeColor),
          //   ),
          // ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(bio, style: AppTextStyles.body(15, height: 1.5)),
          ],
          if (joined.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 6),
                Text(
                  'Joined $joined',
                  style: AppTextStyles.body(
                    13,
                    color: AppColors.mutedForeground,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (!widget.isOwnProfile && widget.onToggleFollow != null) ...[
            const SizedBox(height: 16),
            _FollowButton(
              isFollowing: _isFollowing,
              requested: _followRequestPending,
              busy: _followBusy,
              onPressed: _handleToggleFollow,
            ),
          ],
        ],
      ),
    );
  }
}

/// Follow = coral. Requested = cream/muted. Following = navy.
class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.isFollowing,
    this.requested = false,
    required this.busy,
    required this.onPressed,
  });

  final bool isFollowing;
  final bool requested;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;
    if (isFollowing) {
      bg = AppColors.secondary;
      fg = AppColors.secondaryForeground;
      label = 'FOLLOWING';
    } else if (requested) {
      bg = AppColors.muted;
      fg = AppColors.secondary;
      label = 'REQUESTED';
    } else {
      bg = AppColors.primary;
      fg = AppColors.primaryForeground;
      label = 'FOLLOW';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(
              color: AppColors.border,
              width: AppDimens.borderThick,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.border,
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  )
                : Text(
                    label,
                    style: AppTextStyles.display(16, color: fg),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Snaps calendar scroll to whole week-rows (never stops mid-row).
class _WeekRowSnapScrollPhysics extends ScrollPhysics {
  const _WeekRowSnapScrollPhysics({required this.rowHeight, super.parent});

  final double rowHeight;

  @override
  _WeekRowSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _WeekRowSnapScrollPhysics(
      rowHeight: rowHeight,
      parent: buildParent(ancestor),
    );
  }

  double _targetPixels(ScrollMetrics position, double velocity) {
    if (rowHeight <= 0) return position.pixels;
    final page = position.pixels / rowHeight;
    final double targetPage;
    if (velocity < -toleranceFor(position).velocity) {
      targetPage = page.floorToDouble();
    } else if (velocity > toleranceFor(position).velocity) {
      targetPage = page.ceilToDouble();
    } else {
      targetPage = page.roundToDouble();
    }
    return (targetPage * rowHeight).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final target = _targetPixels(position, velocity);
    if ((target - position.pixels).abs() < tolerance.distance) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}

class _CalendarNavBar extends StatelessWidget {
  const _CalendarNavBar({
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
  });

  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.muted,
      child: Container(
        height: _height,
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.border,
              width: AppDimens.borderThick,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: _height,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: onPrevious,
                icon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.foreground,
                  size: 28,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Material(
                  color: AppColors.accent,
                  child: InkWell(
                    onTap: onToday,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.border,
                          width: AppDimens.border,
                        ),
                      ),
                      child: Text(
                        'TODAY',
                        style: AppTextStyles.display(
                          14,
                          color: AppColors.accentForeground,
                          letterSpacing: 0.05,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 48,
              height: _height,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: onNext,
                icon: const Icon(
                  Icons.chevron_right,
                  color: AppColors.foreground,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.event,
    required this.isToday,
    required this.isMonthStart,
    required this.faded,
    required this.monthNames,
    required this.dayNames,
    this.onTap,
  });

  final DateTime date;
  final ProfileCalendarEvent? event;
  final bool isToday;
  final bool isMonthStart;
  final bool faded;
  final List<String> monthNames;
  final List<String> dayNames;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final monthLabel = '${monthNames[date.month - 1]} ${date.year}';

    return Opacity(
      opacity: faded ? 0.4 : 1,
      child: Material(
        color: faded
            ? AppColors.black.withValues(alpha: 0.5)
            : (isToday
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.card),
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide.none,
                right: const BorderSide(color: AppColors.border, width: 2),
                bottom: const BorderSide(color: AppColors.border, width: 2),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (event != null && event!.imageUrl.isNotEmpty)
                  BeTherNetworkImage(url: event!.imageUrl, fit: BoxFit.cover),
                if (event != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.9),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                // Bright banner so a new month is obvious while scrolling.
                if (isMonthStart)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 5,
                      ),
                      color: AppColors.accent,
                      child: Text(
                        monthLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.display(
                          11,
                          color: AppColors.accentForeground,
                          letterSpacing: 0.04,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: isMonthStart ? 28 : 4,
                  left: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${date.day}',
                        style: AppTextStyles.display(
                          18,
                          color: isToday
                              ? AppColors.primary
                              : AppColors.foreground,
                        ),
                      ),
                      Text(
                        dayNames[date.weekday % 7],
                        style: AppTextStyles.body(
                          10,
                          color: isToday
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (event != null)
                  Positioned(
                    left: 4,
                    right: 4,
                    bottom: 4,
                    child: Text(
                      event!.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        10,
                        color: Colors.white,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Narrow phones (and large system text scale) shrink each Expanded column
    // until long labels like FOLLOWERS wrap mid-word. Scale down to keep one line.
    final content = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: AppTextStyles.display(
                22,
                color: AppColors.secondary,
                letterSpacing: 0.02,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                11,
                color: AppColors.mutedForeground,
                weight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    return Expanded(
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: content,
                ),
              ),
            ),
    );
  }
}
