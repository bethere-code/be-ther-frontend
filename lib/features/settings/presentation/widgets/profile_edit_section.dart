import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/author_avatar.dart';
import '../../../../core/media/photo_picker.dart';
import '../../../profile/presentation/profile_providers.dart';

class ProfileEditSection extends ConsumerStatefulWidget {
  const ProfileEditSection({super.key});

  @override
  ConsumerState<ProfileEditSection> createState() => _ProfileEditSectionState();
}

class _ProfileEditSectionState extends ConsumerState<ProfileEditSection> {
  bool _saving = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save(Map<String, dynamic> patch) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final user = await ref.read(userRepositoryProvider).patchMe(patch);
      refreshProfileCaches(ref, user);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    final user = ref.read(profileMeProvider).value;
    if (user == null) return;
    final hasAvatar = (user['avatarUrl'] as String? ?? '').isNotEmpty;
    final mobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (mobile)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
            if (hasAvatar)
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.destructive),
                title: Text('Remove photo', style: TextStyle(color: AppColors.destructive)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ListTile(
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'remove') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('REMOVE PHOTO?', style: AppTextStyles.display(22, color: AppColors.secondary)),
          content: const Text('Your profile will show the default avatar.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('REMOVE'),
            ),
          ],
        ),
      );
      if (ok == true) await _save({'avatarUrl': ''});
      return;
    }

    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final path = await pickPhoto(context, source: source, square: true);
    if (!mounted || path == null) return;

    setState(() => _saving = true);
    try {
      final file = await compressPhoto(path);
      final repo = ref.read(userRepositoryProvider);
      final url = await repo.uploadImage(file.path);
      final user = await repo.patchMe({'avatarUrl': url});
      refreshProfileCaches(ref, user);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editName(String current) async {
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _NameEditSheet(initial: current, saving: _saving),
    );
    if (saved == null || !mounted) return;
    final name = saved.trim();
    if (name.isEmpty || name == current) return;
    await _save({'displayName': name});
  }

  Future<void> _editBio(String current) async {
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BioEditSheet(initial: current, saving: _saving),
    );
    if (saved == null || !mounted) return;
    final bio = saved.trim();
    if (bio == current) return;
    await _save({'bio': bio});
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(profileMeProvider);

    return me.when(
      data: (user) {
        final avatar = user['avatarUrl'] as String? ?? '';
        final name = user['displayName'] as String? ?? '';
        final bio = user['bio'] as String? ?? '';
        final username = user['username'] as String? ?? '';
        final badge = user['badge'] as String?;

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(bottom: BorderSide(color: AppColors.border, width: AppDimens.borderThick)),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _saving ? null : _changePhoto,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AuthorAvatar(
                          avatarUrl: avatar,
                          username: username,
                          badge: badge,
                          size: 88,
                          interactive: false,
                        ),
                        if (_saving)
                          Container(
                            width: 88,
                            height: 88,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black45,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            ),
                          )
                        else
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.card, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 14, color: AppColors.background),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: AppTextStyles.display(18, color: AppColors.secondary, letterSpacing: 0.02),
                    textAlign: TextAlign.center,
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '@$username',
                      style: AppTextStyles.body(14, color: AppColors.mutedForeground, weight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            ListTile(
              title: Text('Name', style: AppTextStyles.body(16, weight: FontWeight.w800)),
              subtitle: Text(
                name,
                style: AppTextStyles.body(14, color: AppColors.mutedForeground),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _saving ? null : () => _editName(name),
            ),
            const Divider(height: 1, thickness: AppDimens.borderThick, color: AppColors.border),
            ListTile(
              title: Text('Bio', style: AppTextStyles.body(16, weight: FontWeight.w800)),
              subtitle: Text(
                bio.isEmpty ? 'Add a bio…' : bio,
                style: AppTextStyles.body(
                  14,
                  color: bio.isEmpty ? AppColors.mutedForeground : AppColors.foreground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _saving ? null : () => _editBio(bio),
            ),
            const Divider(height: 1, thickness: AppDimens.borderThick, color: AppColors.border),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Could not load profile: $e', style: AppTextStyles.body(14, color: AppColors.destructive)),
      ),
    );
  }
}

class _NameEditSheet extends StatefulWidget {
  const _NameEditSheet({required this.initial, required this.saving});

  final String initial;
  final bool saving;

  @override
  State<_NameEditSheet> createState() => _NameEditSheetState();
}

class _NameEditSheetState extends State<_NameEditSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'NAME',
                style: AppTextStyles.display(20, color: AppColors.secondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLength: 80,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Your name',
                  errorText: _error,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.saving
                          ? null
                          : () {
                              final name = _controller.text.trim();
                              if (name.isEmpty) {
                                setState(() => _error = 'Name is required');
                                return;
                              }
                              Navigator.pop(context, name);
                            },
                      child: const Text('SAVE'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BioEditSheet extends StatefulWidget {
  const _BioEditSheet({required this.initial, required this.saving});

  final String initial;
  final bool saving;

  @override
  State<_BioEditSheet> createState() => _BioEditSheetState();
}

class _BioEditSheetState extends State<_BioEditSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final len = _controller.text.length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'BIO',
                style: AppTextStyles.display(20, color: AppColors.secondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLength: 200,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Write a short bio…',
                  errorText: _error,
                  alignLabelWithHint: true,
                  // Hide Flutter’s built-in counter — we render one below.
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$len/200',
                  style: AppTextStyles.body(
                    12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.saving
                          ? null
                          : () {
                              if (_controller.text.length > 200) {
                                setState(() => _error = 'Bio is too long');
                                return;
                              }
                              Navigator.pop(context, _controller.text);
                            },
                      child: const Text('SAVE'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
