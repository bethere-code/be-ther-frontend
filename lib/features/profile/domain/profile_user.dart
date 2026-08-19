class ProfileSettings {
  const ProfileSettings({
    this.isPrivateProfile = false,
    this.pushEnabled = true,
    this.calendarView = 'full',
  });

  final bool isPrivateProfile;
  final bool pushEnabled;

  /// `full` | `events-only`
  final String calendarView;

  factory ProfileSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProfileSettings();
    final view = json['calendarView']?.toString();
    return ProfileSettings(
      isPrivateProfile: json['isPrivateProfile'] == true,
      pushEnabled: json['pushEnabled'] == null ? true : json['pushEnabled'] == true,
      calendarView: view == 'events-only' ? 'events-only' : 'full',
    );
  }
}

/// Typed profile payload from `/users/me` and `/users/:username`.
class ProfileUser {
  const ProfileUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.joined,
    required this.eventsCount,
    required this.followersCount,
    required this.followingCount,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.isFollowedBy,
    required this.isBlocked,
    required this.isMutualFollow,
    required this.canDM,
    required this.settings,
    this.badge,
    this.usernameChangedAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String bio;
  final String joined;
  final int eventsCount;
  final int followersCount;
  final int followingCount;
  final bool isOwnProfile;
  final bool isFollowing;
  final bool isFollowedBy;
  final bool isBlocked;
  final bool isMutualFollow;
  final bool canDM;
  final ProfileSettings settings;
  final String? badge;
  final DateTime? usernameChangedAt;

  bool get usernameEditLocked {
    final at = usernameChangedAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < const Duration(days: 7);
  }

  factory ProfileUser.fromJson(Map<String, dynamic> json) {
    final settingsRaw = json['settings'];
    return ProfileUser(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      joined: json['joined'] as String? ?? '',
      eventsCount: (json['eventsCount'] as num?)?.toInt() ?? 0,
      followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      isOwnProfile: json['isOwnProfile'] == true,
      isFollowing: json['isFollowing'] == true,
      isFollowedBy: json['isFollowedBy'] == true,
      isBlocked: json['isBlocked'] == true,
      isMutualFollow: json['isMutualFollow'] == true || json['canDM'] == true,
      canDM: json['canDM'] == true,
      settings: ProfileSettings.fromJson(
        settingsRaw is Map<String, dynamic>
            ? settingsRaw
            : settingsRaw is Map
                ? Map<String, dynamic>.from(settingsRaw)
                : null,
      ),
      badge: json['badge'] as String?,
      usernameChangedAt: DateTime.tryParse(json['usernameChangedAt']?.toString() ?? ''),
    );
  }

  ProfileUser copyWith({
    bool? isFollowing,
    bool? isFollowedBy,
    bool? isBlocked,
    bool? isMutualFollow,
    int? followersCount,
    String? avatarUrl,
    String? displayName,
    String? bio,
    ProfileSettings? settings,
    DateTime? usernameChangedAt,
  }) {
    return ProfileUser(
      id: id,
      username: username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      joined: joined,
      eventsCount: eventsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount,
      isOwnProfile: isOwnProfile,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollowedBy: isFollowedBy ?? this.isFollowedBy,
      isBlocked: isBlocked ?? this.isBlocked,
      isMutualFollow: isMutualFollow ?? this.isMutualFollow,
      canDM: canDM,
      settings: settings ?? this.settings,
      badge: badge,
      usernameChangedAt: usernameChangedAt ?? this.usernameChangedAt,
    );
  }
}

/// Lightweight row for followers / following lists.
class ProfileConnectionUser {
  const ProfileConnectionUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;

  factory ProfileConnectionUser.fromJson(Map<String, dynamic> json) {
    final username = json['username'] as String? ?? '';
    final display = (json['displayName'] as String?)?.trim() ?? '';
    return ProfileConnectionUser(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      username: username,
      displayName: display.isNotEmpty ? display : username,
      avatarUrl: json['avatarUrl'] as String? ?? '',
    );
  }
}
