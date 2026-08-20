import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/author_avatar.dart';
import '../../../../core/media/photo_picker.dart';
import '../../../profile/presentation/profile_providers.dart';
import 'package:be_ther/core/ui/app_toast.dart';

class ProfileEditSection extends ConsumerStatefulWidget {
  const ProfileEditSection({super.key});

  @override
  ConsumerState<ProfileEditSection> createState() => _ProfileEditSectionState();
}

class _ProfileEditSectionState extends ConsumerState<ProfileEditSection> {
  bool _saving = false;

  void _snack(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
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
    final hasAvatar = user.avatarUrl.isNotEmpty;
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
                leading: Icon(
                  Icons.delete_outline,
                  color: AppColors.destructive,
                ),
                title: Text(
                  'Remove photo',
                  style: TextStyle(color: AppColors.destructive),
                ),
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
          title: Text(
            'REMOVE PHOTO?',
            style: AppTextStyles.display(22, color: AppColors.secondary),
          ),
          content: const Text('Your profile will show the default avatar.'),
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
              child: const Text('REMOVE'),
            ),
          ],
        ),
      );
      if (ok == true) await _save({'avatarUrl': ''});
      return;
    }

    final source = action == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;
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

  static const _usernameCooldownToast =
      'You cannot edit your username for 7 days after the last change';

  Future<void> _editUsername(ProfileUser user) async {
    if (user.usernameEditLocked) {
      _snack(_usernameCooldownToast);
      return;
    }
    final updated = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit username',
      barrierColor: AppColors.secondary.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, animation, secondary) {
        return _UsernameEditDialog(current: user.username);
      },
      transitionBuilder: (ctx, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (updated == null || !mounted) return;
    refreshProfileCaches(ref, updated);
    _snack('Username updated');
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(profileMeProvider);

    return me.when(
      data: (user) {
        final avatar = user.avatarUrl;
        final name = user.displayName;
        final bio = user.bio;
        final username = user.username;
        final badge = user.badge;

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
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
                                border: Border.all(
                                  color: AppColors.card,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 14,
                                color: AppColors.background,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: AppTextStyles.display(
                      18,
                      color: AppColors.secondary,
                      letterSpacing: 0.02,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '@$username',
                            style: AppTextStyles.body(
                              14,
                              color: AppColors.mutedForeground,
                              weight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        // IconButton(
                        //   tooltip: 'Edit username',
                        //   onPressed: _saving ? null : () => _editUsername(user),
                        //   visualDensity: VisualDensity.compact,
                        //   padding: EdgeInsets.zero,
                        //   // constraints: const BoxConstraints(
                        //   //   minWidth: 40,
                        //   //   minHeight: 40,
                        //   // ),
                        //   icon:
                        // ),
                        InkWell(
                          onTap: _saving ? null : () => _editUsername(user),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            ListTile(
              title: Text(
                'Name',
                style: AppTextStyles.body(16, weight: FontWeight.w800),
              ),
              subtitle: Text(
                name,
                style: AppTextStyles.body(14, color: AppColors.mutedForeground),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _saving ? null : () => _editName(name),
            ),
            const Divider(
              height: 1,
              thickness: AppDimens.borderThin,
              color: AppColors.border,
            ),
            ListTile(
              title: Text(
                'Bio',
                style: AppTextStyles.body(16, weight: FontWeight.w800),
              ),
              subtitle: Text(
                bio.isEmpty ? 'Add a bio…' : bio,
                style: AppTextStyles.body(
                  14,
                  color: bio.isEmpty
                      ? AppColors.mutedForeground
                      : AppColors.foreground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _saving ? null : () => _editBio(bio),
            ),
            const Divider(
              height: 1,
              thickness: AppDimens.borderThin,
              color: AppColors.border,
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Could not load profile: $e',
          style: AppTextStyles.body(14, color: AppColors.destructive),
        ),
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

class _UsernameEditDialog extends ConsumerStatefulWidget {
  const _UsernameEditDialog({required this.current});

  final String current;

  @override
  ConsumerState<_UsernameEditDialog> createState() =>
      _UsernameEditDialogState();
}

class _UsernameEditDialogState extends ConsumerState<_UsernameEditDialog> {
  static const _min = 3;
  static const _max = 20;

  late final TextEditingController _controller;
  late final FocusNode _focus;
  Timer? _debounce;
  int _requestId = 0;
  bool _checking = false;
  bool _saving = false;
  bool _available = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current);
    _focus = FocusNode();
    _available = true;
    _status = 'This is your current username';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    _debounce?.cancel();
    final username = raw.trim().toLowerCase();
    if (username == widget.current) {
      setState(() {
        _checking = false;
        _available = true;
        _status = 'This is your current username';
      });
      return;
    }
    if (username.length < _min) {
      setState(() {
        _checking = false;
        _available = false;
        _status = 'At least $_min characters';
      });
      return;
    }
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(username)) {
      setState(() {
        _checking = false;
        _available = false;
        _status = 'Lowercase letters and digits only';
      });
      return;
    }
    setState(() {
      _checking = true;
      _available = false;
      _status = 'Checking…';
    });
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final id = ++_requestId;
      try {
        final result = await ref
            .read(userRepositoryProvider)
            .checkUsernameAvailable(username);
        if (!mounted || id != _requestId) return;
        setState(() {
          _checking = false;
          _available = result.available;
          _status = result.available
              ? 'Available'
              : (result.reason ?? 'Username already exists');
        });
      } catch (_) {
        if (!mounted || id != _requestId) return;
        setState(() {
          _checking = false;
          _available = false;
          _status = 'Could not check right now';
        });
      }
    });
  }

  Future<void> _save() async {
    final username = _controller.text.trim().toLowerCase();
    if (username == widget.current) {
      Navigator.pop(context);
      return;
    }
    if (!_available || _checking || _saving) return;
    setState(() => _saving = true);
    try {
      final user = await ref
          .read(userRepositoryProvider)
          .changeUsername(username);
      if (!mounted) return;
      Navigator.pop(context, user);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = e.toString();
        _available = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_saving && !_checking && _available;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final statusColor = _checking
        ? AppColors.mutedForeground
        : _available
        ? AppColors.secondary
        : AppColors.destructive;
    // Strip AlertDialog's own keyboard pad, then lift once so buttons
    // clear the keyboard without stacking insets (that flew it off-screen).
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width - 20,
              ),
              child: AlertDialog(
                backgroundColor: AppColors.card,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 16,
                ),
                titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(
                    color: AppColors.border,
                    width: AppDimens.borderThick,
                  ),
                  borderRadius: BorderRadius.zero,
                ),
                title: Text(
                  'USERNAME',
                  style: AppTextStyles.display(22, color: AppColors.secondary),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '3–20 lowercase letters and digits.',
                      style: AppTextStyles.body(
                        13,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: true,
                      maxLength: _max,
                      enabled: !_saving,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9]')),
                        LengthLimitingTextInputFormatter(_max),
                      ],
                      decoration: InputDecoration(
                        prefixText: '@',
                        hintText: 'username',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: AppColors.ring,
                            width: AppDimens.border,
                          ),
                        ),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: AppColors.border,
                            width: AppDimens.border,
                          ),
                        ),
                      ),
                      onChanged: _onChanged,
                      onSubmitted: (_) {
                        if (canSave) unawaited(_save());
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (_checking)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            _available
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            size: 16,
                            color: _available
                                ? AppColors.primary
                                : AppColors.destructive,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _status ?? '',
                            style: AppTextStyles.body(13, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  FilledButton(
                    onPressed: canSave ? _save : null,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryForeground,
                            ),
                          )
                        : const Text('SAVE'),
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
