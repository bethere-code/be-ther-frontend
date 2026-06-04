import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/be_ther_network_image.dart';
import '../../feed/presentation/feed_providers.dart';
import '../../settings/presentation/settings_screen.dart';
import 'profile_providers.dart';
import 'widgets/profile_event_sheet.dart';

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

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _daysPerChunk = 28;
  static const _dayNames = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  static const _monthNames = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  final _scrollController = ScrollController();
  late DateTime _gridStart;
  int _dayCount = _daysPerChunk;
  bool _loadingMoreDays = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _gridStart = DateTime(now.year, now.month, now.day);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMoreDays) return;
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 240) {
      return;
    }
    setState(() {
      _loadingMoreDays = true;
      _dayCount += _daysPerChunk;
      _loadingMoreDays = false;
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _gridStart = DateTime(now.year, now.month, now.day);
      _dayCount = _daysPerChunk;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _shiftWeek(int direction) {
    setState(() {
      _gridStart = _gridStart.add(Duration(days: 7 * direction));
    });
  }

  Color _badgeColor(String? badge) {
    switch (badge) {
      case 'blue':
        return const Color(0xFF3B82F6);
      case 'silver':
        return const Color(0xFF94A3B8);
      case 'gold':
        return AppColors.accent;
      default:
        return AppColors.border;
    }
  }

  Map<String, ProfileCalendarEvent> _eventsByDate(List<Map<String, dynamic>> items) {
    final map = <String, ProfileCalendarEvent>{};
    for (final item in items) {
      final event = ProfileCalendarEvent.fromJson(item);
      final key = DateFormat('yyyy-MM-dd').format(event.date);
      map.putIfAbsent(key, () => event);
    }
    return map;
  }

  Future<void> _refresh(String calendarUsername) async {
    ref.invalidate(profileViewProvider(widget.username));
    ref.invalidate(profileCalendarProvider(calendarUsername));
    await ref.read(profileViewProvider(widget.username).future);
    await ref.read(profileCalendarProvider(calendarUsername).future);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileViewProvider(widget.username));

    return profileAsync.when(
      loading: () => AppShell(
        activeTab: ShellTab.home,
        showRail: true,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppShell(
        activeTab: ShellTab.home,
        showRail: true,
        child: Center(child: SelectableText('$e')),
      ),
      data: (user) {
        final username = user['username'] as String? ?? '';
        final isOwnProfile = user['isOwnProfile'] as bool? ?? (widget.username == null);
        final calendarAsync = ref.watch(profileCalendarProvider(username));

        return AppShell(
          activeTab: ShellTab.home,
          showRail: true,
          header: _ProfileHeader(
            username: username,
            isOwnProfile: isOwnProfile,
            onBack: () => context.pop(),
            onSettings: isOwnProfile ? () => context.push(SettingsScreen.path) : null,
          ),
          child: RefreshIndicator(
            onRefresh: () => _refresh(username),
            child: calendarAsync.when(
              data: (items) {
                final eventsByDate = _eventsByDate(items);
                final today = DateTime.now();
                final todayDate = DateTime(today.year, today.month, today.day);

                return CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _ProfileInfoSection(
                        user: user,
                        isOwnProfile: isOwnProfile,
                        badgeColor: _badgeColor(user['badge'] as String?),
                        onToggleFollow: () async {
                          final starred = await ref.read(userRepositoryProvider).starToggle(username);
                          ref.invalidate(profileViewProvider(widget.username));
                          return starred;
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _CalendarNavBar(
                        onPrevious: () => _shiftWeek(-1),
                        onToday: _goToToday,
                        onNext: () => _shiftWeek(1),
                      ),
                    ),
                    SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final date = _gridStart.add(Duration(days: index));
                          final dateKey = DateFormat('yyyy-MM-dd').format(date);
                          final event = eventsByDate[dateKey];
                          final isToday = date.year == todayDate.year &&
                              date.month == todayDate.month &&
                              date.day == todayDate.day;
                          final isPast = date.isBefore(todayDate);
                          final faded = isPast && event == null;

                          return _CalendarDayCell(
                            date: date,
                            event: event,
                            isToday: isToday,
                            faded: faded,
                            monthNames: _monthNames,
                            dayNames: _dayNames,
                            onTap: event == null
                                ? null
                                : () => showProfileEventSheet(
                                      context: context,
                                      event: event,
                                      showWishlist: !isOwnProfile,
                                      onToggleWishlist: () async {
                                        final saved = await ref
                                            .read(postsRepositoryProvider)
                                            .toggleBookmark(event.postId);
                                        ref.invalidate(profileCalendarProvider(username));
                                        return saved;
                                      },
                                    ),
                          );
                        },
                        childCount: _dayCount,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                );
              },
              loading: () => CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _ProfileInfoSection(
                      user: user,
                      isOwnProfile: isOwnProfile,
                      badgeColor: _badgeColor(user['badge'] as String?),
                    ),
                  ),
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
              error: (e, _) => CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _ProfileInfoSection(
                      user: user,
                      isOwnProfile: isOwnProfile,
                      badgeColor: _badgeColor(user['badge'] as String?),
                    ),
                  ),
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('$e', style: AppTextStyles.body(14, color: AppColors.destructive)),
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

class _ProfileHeader extends StatelessWidget implements PreferredSizeWidget {
  const _ProfileHeader({
    required this.username,
    required this.isOwnProfile,
    required this.onBack,
    this.onSettings,
  });

  final String username;
  final bool isOwnProfile;
  final VoidCallback onBack;
  final VoidCallback? onSettings;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: AppColors.secondary,
        border: Border(bottom: BorderSide(color: AppColors.border, width: AppDimens.borderThick)),
      ),
      child: Row(
        children: [
          if (!isOwnProfile)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: AppColors.background, size: 24),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              '@$username',
              textAlign: TextAlign.center,
              style: AppTextStyles.display(24, color: AppColors.primary, letterSpacing: 0.1),
            ),
          ),
          if (onSettings != null)
            IconButton(
              onPressed: onSettings,
              icon: const Icon(Icons.settings, color: AppColors.background, size: 24),
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
    required this.badgeColor,
    this.onToggleFollow,
  });

  final Map<String, dynamic> user;
  final bool isOwnProfile;
  final Color badgeColor;
  final Future<bool> Function()? onToggleFollow;

  @override
  ConsumerState<_ProfileInfoSection> createState() => _ProfileInfoSectionState();
}

class _ProfileInfoSectionState extends ConsumerState<_ProfileInfoSection> {
  bool _followBusy = false;

  @override
  Widget build(BuildContext context) {
    final avatar = widget.user['avatarUrl'] as String? ?? '';
    final display = widget.user['displayName'] as String? ?? '';
    final bio = widget.user['bio'] as String? ?? '';
    final stars = widget.user['starsReceived'] as int? ?? 0;
    final places = widget.user['placesVisited'] as int? ?? 0;
    final events = widget.user['eventsAttended'] as int? ?? 0;
    final joined = widget.user['joined'] as String? ?? '';
    final badge = widget.user['badge'] as String?;
    final isStarred = widget.user['isStarredByMe'] as bool? ?? false;
    final canDM = widget.user['canDM'] as bool? ?? false;
    final username = widget.user['username'] as String? ?? '';

    return Container(
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.badgeColor, width: AppDimens.borderThick),
                ),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  display,
                  style: AppTextStyles.display(20, color: AppColors.secondary, letterSpacing: 0.02),
                ),
              ),
              if (!widget.isOwnProfile && isStarred && canDM)
                const Icon(Icons.mail_outline, color: AppColors.primary, size: 20),
            ],
          ),
          if (badge != null) ...[
            const SizedBox(height: 6),
            Text(
              '${badge.toUpperCase()} MEMBER',
              style: AppTextStyles.body(14, weight: FontWeight.w800, color: widget.badgeColor),
            ),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(bio, style: AppTextStyles.body(15, height: 1.5)),
          ],
          if (joined.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: AppColors.mutedForeground),
                const SizedBox(width: 6),
                Text('Joined $joined', style: AppTextStyles.body(13, color: AppColors.mutedForeground, weight: FontWeight.w600)),
              ],
            ),
          ],
          if (!widget.isOwnProfile && widget.onToggleFollow != null) ...[
            const SizedBox(height: 16),
            Material(
              color: isStarred ? AppColors.primary : AppColors.accent,
              child: InkWell(
                onTap: _followBusy
                    ? null
                    : () async {
                        setState(() => _followBusy = true);
                        try {
                          await widget.onToggleFollow!();
                        } finally {
                          if (mounted) setState(() => _followBusy = false);
                        }
                      },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border, width: AppDimens.borderThick),
                    boxShadow: AppDimens.primaryButtonShadow,
                  ),
                  child: Text(
                    isStarred
                        ? 'FOLLOWING @${username.toUpperCase()} JOURNEY'
                        : 'FOLLOW @${username.toUpperCase()} JOURNEY',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display(
                      14,
                      color: isStarred ? AppColors.primaryForeground : AppColors.accentForeground,
                      letterSpacing: 0.05,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.muted,
        border: Border(bottom: BorderSide(color: AppColors.border, width: AppDimens.borderThick)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left, color: AppColors.foreground, size: 28),
          ),
          Expanded(
            child: Center(
              child: Material(
                color: AppColors.primary,
                child: InkWell(
                  onTap: onToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border, width: AppDimens.border),
                    ),
                    child: Text(
                      'TODAY',
                      style: AppTextStyles.display(14, color: AppColors.primaryForeground, letterSpacing: 0.05),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, color: AppColors.foreground, size: 28),
          ),
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.event,
    required this.isToday,
    required this.faded,
    required this.monthNames,
    required this.dayNames,
    this.onTap,
  });

  final DateTime date;
  final ProfileCalendarEvent? event;
  final bool isToday;
  final bool faded;
  final List<String> monthNames;
  final List<String> dayNames;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = event?.status == 'been' ? AppColors.primary : AppColors.accent;
    final statusFg = event?.status == 'been' ? AppColors.primaryForeground : AppColors.accentForeground;
    final statusLabel = event?.status == 'been'
        ? 'BEEN'
        : event?.status == 'going'
            ? 'GOING'
            : 'INTERESTED';

    return Opacity(
      opacity: faded ? 0.4 : 1,
      child: Material(
        color: isToday ? AppColors.primary.withValues(alpha: 0.1) : AppColors.card,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.border, width: 2),
                bottom: BorderSide(color: AppColors.border, width: 2),
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
                Positioned(
                  top: 4,
                  left: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${date.day}',
                        style: AppTextStyles.display(
                          18,
                          color: isToday ? AppColors.primary : AppColors.foreground,
                        ),
                      ),
                      Text(
                        dayNames[date.weekday % 7],
                        style: AppTextStyles.body(
                          10,
                          color: isToday ? AppColors.primary : AppColors.mutedForeground,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (date.day == 1)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      color: AppColors.secondary,
                      child: Text(
                        monthNames[date.month - 1],
                        style: AppTextStyles.display(9, color: AppColors.background),
                      ),
                    ),
                  ),
                if (event != null)
                  Positioned(
                    left: 4,
                    right: 4,
                    bottom: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor,
                            border: Border.all(color: AppColors.background, width: 2),
                          ),
                          child: Text(statusLabel, style: AppTextStyles.display(8, color: statusFg)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event!.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(10, color: Colors.white, weight: FontWeight.w800),
                        ),
                      ],
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
