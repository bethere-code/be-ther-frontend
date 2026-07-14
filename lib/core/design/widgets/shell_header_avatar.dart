import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/presentation/auth_notifier.dart';
import '../../../features/profile/presentation/profile_providers.dart';
import '../../../features/profile/presentation/profile_screen.dart';
import 'author_avatar.dart';

class ShellHeaderAvatar extends ConsumerWidget {
  const ShellHeaderAvatar({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authNotifierProvider).user;
    final me = ref.watch(profileMeProvider);
    final profile = me.value;
    final avatarUrl =
        profile?['avatarUrl'] as String? ?? authUser?['avatarUrl'] as String? ?? '';
    final badge = profile?['badge'] as String? ?? authUser?['badge'] as String?;
    final username = profile?['username'] as String? ?? authUser?['username'] as String? ?? '';

    return AuthorAvatar(
      avatarUrl: avatarUrl,
      username: username,
      badge: badge,
      size: size,
      onTap: () => context.push(ProfileScreen.path),
    );
  }
}
