import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/be_ther_buttons.dart';
import '../../../core/network/api_client.dart';
import '../../search/presentation/search_screen.dart';
import '../data/posts_repository.dart';
import 'feed_providers.dart';

class AddPostScreen extends ConsumerStatefulWidget {
  const AddPostScreen({super.key});

  static const path = '/add';
  static const name = 'add';

  @override
  ConsumerState<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends ConsumerState<AddPostScreen> {
  final _eventName = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _ticket = TextEditingController();
  final _tagInput = TextEditingController();

  bool _private = false;
  bool _addToCalendar = false;
  String? _imagePath;
  bool _busy = false;
  bool _attemptedSubmit = false;
  final _touched = <String, bool>{};
  final _taggedUsers = <String>[];
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  static const _fieldEventName = 'eventName';
  static const _fieldDescription = 'description';
  static const _fieldLocation = 'location';
  static const _fieldDate = 'date';
  static const _fieldTicket = 'ticket';
  static const _fieldImage = 'image';

  @override
  void dispose() {
    _eventName.dispose();
    _description.dispose();
    _location.dispose();
    _ticket.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _unfocus() => FocusScope.of(context).unfocus();

  bool _hasUnsavedChanges() {
    return _imagePath != null ||
        _eventName.text.trim().isNotEmpty ||
        _description.text.trim().isNotEmpty ||
        _location.text.trim().isNotEmpty ||
        _ticket.text.trim().isNotEmpty ||
        _taggedUsers.isNotEmpty ||
        _selectedDate != null ||
        _selectedTime != null ||
        _private ||
        _addToCalendar;
  }

  Future<void> _close(BuildContext context) async {
    _unfocus();
    if (_hasUnsavedChanges()) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(
            'DISCARD CHANGES?',
            style: AppTextStyles.display(20, color: AppColors.secondary),
          ),
          content: Text(
            'You have unsaved changes. Are you sure you want to leave this page?',
            style: AppTextStyles.body(15, color: AppColors.foreground),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'STAY',
                style: AppTextStyles.body(
                  14,
                  weight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.destructive,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('DISCARD'),
            ),
          ],
        ),
      );
      if (discard != true) return;
      if (!context.mounted) return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/feed');
  }

  static int _wordCount(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  Future<void> _pick() async {
    _unfocus();
    try {
      final path = await _pickEventPhoto(context);
      if (!mounted || path == null) return;
      setState(() {
        _imagePath = path;
        _touched[_fieldImage] = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load photo. Please try again.'),
        ),
      );
    }
  }

  String? _validateEventName(String value) {
    if (value.trim().isEmpty) return 'Event name is required';
    if (value.trim().length > 200) {
      return 'Event name must be less than 200 characters';
    }
    return null;
  }

  String? _validateLocation(String value) {
    if (value.trim().isEmpty) return 'Location is required';
    if (value.trim().length > 200) {
      return 'Location must be less than 200 characters';
    }
    return null;
  }

  String? _validateDate() {
    if (_selectedDate == null) return 'Date is required';
    return null;
  }

  String? _validateDescription(String value) {
    if (_wordCount(value) > 2000) {
      return 'Description must be less than 2000 words';
    }
    return null;
  }

  String? _validateTicket(String value) {
    if (value.trim().isEmpty) return null;
    if (_normalizeTicketUrl() == null) {
      return 'Please enter a valid URL (e.g., https://example.com/tickets)';
    }
    return null;
  }

  bool _showFieldError(String field) =>
      _attemptedSubmit || (_touched[field] ?? false);

  void _markTouched(String field) {
    if (_touched[field] == true) return;
    setState(() => _touched[field] = true);
  }

  String? _fieldError(String field, String? Function() validate) {
    if (!_showFieldError(field)) return null;
    return validate();
  }

  bool _showImageError() => _attemptedSubmit && _imagePath == null;

  bool _hasValidationErrors() {
    return _imagePath == null ||
        _validateEventName(_eventName.text) != null ||
        _validateLocation(_location.text) != null ||
        _validateDate() != null ||
        _validateDescription(_description.text) != null ||
        _validateTicket(_ticket.text) != null;
  }

  String? _normalizeTicketUrl() {
    final raw = _ticket.text.trim();
    if (raw.isEmpty) return null;
    final withScheme = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasAuthority) return null;
    return withScheme;
  }

  String? _formatDateForApi() {
    if (_selectedDate == null) return null;
    return DateFormat('yyyy-MM-dd').format(_selectedDate!);
  }

  String? _formatTimeForApi() {
    if (_selectedTime == null) return null;
    final h = _selectedTime!.hour.toString().padLeft(2, '0');
    final m = _selectedTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatTimeDisplay() {
    if (_selectedTime == null) return '';
    final dt = DateTime(2000, 1, 1, _selectedTime!.hour, _selectedTime!.minute);
    return DateFormat.jm().format(dt);
  }

  Future<void> _pickDate() async {
    _unfocus();
    _markTouched(_fieldDate);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    _unfocus();
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    _unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (!mounted) return;
    _unfocus();
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _post() async {
    if (_busy) return;
    _unfocus();
    setState(() => _attemptedSubmit = true);

    if (_hasValidationErrors()) return;

    if (!await File(_imagePath!).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo file is missing. Please select it again.'),
        ),
      );
      return;
    }

    final ticketUrl = _normalizeTicketUrl();
    setState(() => _busy = true);

    File? compressedFile;
    try {
      compressedFile = await _compressPhoto(_imagePath!);
      final dio = ref.read(apiClientProvider);
      final posts = PostsRepository(dio);
      final url = await posts.uploadImage(compressedFile.path);
      final eventDetails = <String, dynamic>{
        'type': 'event',
        'date': _formatDateForApi(),
        'venue': _location.text.trim(),
        'time': ?_formatTimeForApi(),
        'ticketUrl': ?ticketUrl,
      };
      await posts.createPost({
        'location': _eventName.text.trim(),
        'country': _location.text.trim(),
        'status': 'going',
        'imageUrl': url,
        'caption': _description.text.trim(),
        'isPrivate': _private,
        'addToCalendar': _addToCalendar,
        if (_taggedUsers.isNotEmpty) 'taggedUsernames': _taggedUsers,
        'eventDetails': eventDetails,
      });
      ref.invalidate(feedProvider);
      if (!mounted) return;
      _close(context);
    } on DioException catch (e) {
      if (!mounted) return;
      final message = PostsRepository(
        ref.read(apiClientProvider),
      ).apiMessage(e, fallback: 'Failed to post event');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (compressedFile != null) {
        try {
          if (await compressedFile.exists()) await compressedFile.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      resizeToAvoidBottomInset: false,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _close(context);
          }
        },
        child: Align(
          alignment: Alignment.bottomCenter,
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: FractionallySizedBox(
              heightFactor: 0.9,
              child: Material(
                color: AppColors.background,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
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
                          IconButton(
                            onPressed: () => _close(context),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.background,
                              size: 28,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'NEW POST',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.display(
                                28,
                                color: AppColors.primary,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _unfocus();
                              context.push(SearchScreen.path);
                            },
                            icon: const Icon(
                              Icons.search,
                              color: AppColors.background,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _unfocus,
                        behavior: HitTestBehavior.translucent,
                        child: ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            120 + keyboard,
                          ),
                          children: [
                            const _SectionLabel('EVENT PHOTO'),
                            const SizedBox(height: 8),
                            AspectRatio(
                              aspectRatio: 16 / 10,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  InkWell(
                                    onTap: _pick,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.muted,
                                        border: Border.all(
                                          color: _showImageError()
                                              ? AppColors.destructive
                                              : AppColors.border,
                                          width: AppDimens.borderThick,
                                        ),
                                      ),
                                      child: _imagePath == null
                                          ? Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.image_outlined,
                                                  size: 48,
                                                  color:
                                                      AppColors.mutedForeground,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'TAP TO UPLOAD',
                                                  style: AppTextStyles.display(
                                                    16,
                                                    color: AppColors
                                                        .mutedForeground,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Image.file(
                                              File(_imagePath!),
                                              fit: BoxFit.contain,
                                            ),
                                    ),
                                  ),
                                  if (_imagePath != null)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Material(
                                        color: AppColors.secondary,
                                        child: InkWell(
                                          onTap: () =>
                                              setState(() => _imagePath = null),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: AppColors.background,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: AppColors.background,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_showImageError()) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Event photo is required',
                                style: AppTextStyles.body(
                                  12,
                                  color: AppColors.destructive,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            const _SectionLabel('EVENT NAME *'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _eventName,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) {
                                _markTouched(_fieldEventName);
                                setState(() {});
                              },
                              style: AppTextStyles.body(
                                16,
                                weight: FontWeight.w600,
                              ),
                              decoration: _inputDecoration(
                                hint: 'Coachella Valley Music Festival',
                                errorText: _fieldError(
                                  _fieldEventName,
                                  () => _validateEventName(_eventName.text),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _SectionLabel('DESCRIPTION'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _description,
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) {
                                _markTouched(_fieldDescription);
                                setState(() {});
                              },
                              style: AppTextStyles.body(
                                16,
                                weight: FontWeight.w600,
                                height: 1.5,
                              ),
                              decoration: _inputDecoration(
                                hint: 'Add how you feel about this event! 🎉',
                                errorText: _fieldError(
                                  _fieldDescription,
                                  () => _validateDescription(_description.text),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _PrivacyToggle(
                              isPrivate: _private,
                              onChanged: (v) {
                                _unfocus();
                                setState(() => _private = v);
                              },
                            ),
                            const SizedBox(height: 16),
                            const _SectionLabel('LOCATION *'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _location,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) {
                                _markTouched(_fieldLocation);
                                setState(() {});
                              },
                              style: AppTextStyles.body(
                                16,
                                weight: FontWeight.w600,
                              ),
                              decoration: _inputDecoration(
                                hint: 'Indio, California',
                                prefixIcon: Icon(
                                  Icons.place,
                                  color: AppColors.mutedForeground,
                                  size: 20,
                                ),
                                errorText: _fieldError(
                                  _fieldLocation,
                                  () => _validateLocation(_location.text),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _SectionLabel('DATE *'),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: _pickDate,
                                        child: InputDecorator(
                                          decoration:
                                              _inputDecoration(
                                                hint: 'Select date',
                                                errorText: _fieldError(
                                                  _fieldDate,
                                                  _validateDate,
                                                ),
                                              ).copyWith(
                                                suffixIcon: Icon(
                                                  Icons.calendar_today,
                                                  color:
                                                      AppColors.mutedForeground,
                                                  size: 18,
                                                ),
                                              ),
                                          child: Text(
                                            _selectedDate == null
                                                ? ''
                                                : DateFormat.yMMMd().format(
                                                    _selectedDate!,
                                                  ),
                                            style: AppTextStyles.body(
                                              16,
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _SectionLabel('TIME'),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: _pickTime,
                                        child: InputDecorator(
                                          decoration:
                                              _inputDecoration(
                                                hint: 'Select time',
                                              ).copyWith(
                                                suffixIcon: Icon(
                                                  Icons.access_time,
                                                  color:
                                                      AppColors.mutedForeground,
                                                  size: 18,
                                                ),
                                              ),
                                          child: Text(
                                            _formatTimeDisplay(),
                                            style: AppTextStyles.body(
                                              16,
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const _SectionLabel('TICKET URL (OPTIONAL)'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _ticket,
                              keyboardType: TextInputType.url,
                              textCapitalization: TextCapitalization.none,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) {
                                _markTouched(_fieldTicket);
                                setState(() {});
                              },
                              onSubmitted: (_) => _unfocus(),
                              style: AppTextStyles.body(
                                16,
                                weight: FontWeight.w600,
                              ),
                              decoration: _inputDecoration(
                                hint: 'https://example.com/tickets',
                                prefixIcon: Icon(
                                  Icons.open_in_new,
                                  color: AppColors.mutedForeground,
                                  size: 18,
                                ),
                                errorText: _fieldError(
                                  _fieldTicket,
                                  () => _validateTicket(_ticket.text),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // const _SectionLabel('GOING WITH'),
                            // const SizedBox(height: 8),
                            // if (_taggedUsers.isNotEmpty)
                            //   Padding(
                            //     padding: const EdgeInsets.only(bottom: 8),
                            //     child: Wrap(
                            //       spacing: 8,
                            //       runSpacing: 8,
                            //       children: _taggedUsers.map((tag) {
                            //         return Container(
                            //           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            //           decoration: BoxDecoration(
                            //             color: AppColors.primary,
                            //             border: Border.all(color: AppColors.border, width: AppDimens.border),
                            //           ),
                            //           child: Row(
                            //             mainAxisSize: MainAxisSize.min,
                            //             children: [
                            //               Text(
                            //                 '@$tag',
                            //                 style: AppTextStyles.display(14, color: AppColors.primaryForeground),
                            //               ),
                            //               const SizedBox(width: 6),
                            //               GestureDetector(
                            //                 onTap: () => _removeTag(tag),
                            //                 child: Icon(Icons.close, size: 16, color: AppColors.primaryForeground),
                            //               ),
                            //             ],
                            //           ),
                            //         );
                            //       }).toList(),
                            //     ),
                            //   ),
                            // if (_showTagInput)
                            //   Row(
                            //     children: [
                            //       Expanded(
                            //         child: TextField(
                            //           controller: _tagInput,
                            //           autofocus: true,
                            //           onSubmitted: (_) => _addTag(),
                            //           style: AppTextStyles.body(16, weight: FontWeight.w600),
                            //           decoration: _inputDecoration(hint: 'username'),
                            //         ),
                            //       ),
                            //       const SizedBox(width: 8),
                            //       Material(
                            //         color: AppColors.accent,
                            //         child: InkWell(
                            //           onTap: _addTag,
                            //           child: Container(
                            //             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            //             decoration: BoxDecoration(
                            //               border: Border.all(color: AppColors.border, width: AppDimens.borderThick),
                            //             ),
                            //             child: Text(
                            //               'ADD',
                            //               style: AppTextStyles.display(14, color: AppColors.accentForeground),
                            //             ),
                            //           ),
                            //         ),
                            //       ),
                            //     ],
                            //   )
                            // else
                            //   InkWell(
                            //     onTap: () => setState(() => _showTagInput = true),
                            //     child: Container(
                            //       width: double.infinity,
                            //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            //       decoration: BoxDecoration(
                            //         color: AppColors.muted,
                            //         border: Border.all(color: AppColors.border, width: AppDimens.borderThick, style: BorderStyle.solid),
                            //       ),
                            //       child: Row(
                            //         mainAxisAlignment: MainAxisAlignment.center,
                            //         children: [
                            //           Icon(Icons.people_outline, color: AppColors.mutedForeground, size: 20),
                            //           const SizedBox(width: 8),
                            //           Text(
                            //             'TAG FRIENDS',
                            //             style: AppTextStyles.display(14, color: AppColors.mutedForeground),
                            //           ),
                            //         ],
                            //       ),
                            //     ),
                            //   ),
                            const SizedBox(height: 16),
                            _EventStatusToggle(
                              addToCalendar: _addToCalendar,
                              onChanged: (v) {
                                _unfocus();
                                setState(() => _addToCalendar = v);
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: const BoxDecoration(
                          color: AppColors.muted,
                          border: Border(
                            top: BorderSide(
                              color: AppColors.border,
                              width: AppDimens.border,
                            ),
                          ),
                        ),
                        child: BeTherPrimaryButton(
                          label: _busy ? 'POSTING…' : 'POST EVENT',
                          enabled: !_busy,
                          onPressed: _post,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    String? errorText,
    Widget? prefixIcon,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    final borderColor = hasError ? AppColors.destructive : AppColors.border;

    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      errorStyle: AppTextStyles.body(
        12,
        color: AppColors.destructive,
        weight: FontWeight.w600,
      ),
      errorMaxLines: 2,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: AppColors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: borderColor,
          width: AppDimens.borderThick,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: borderColor,
          width: AppDimens.borderThick,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: hasError ? AppColors.destructive : AppColors.primary,
          width: AppDimens.borderThick,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.destructive,
          width: AppDimens.borderThick,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.destructive,
          width: AppDimens.borderThick,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.display(
        13,
        color: AppColors.mutedForeground,
        letterSpacing: 0.05,
      ),
    );
  }
}

class _BrutalistToggle extends StatelessWidget {
  const _BrutalistToggle({
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 36,
        decoration: BoxDecoration(
          color: value ? activeColor : AppColors.background,
          border: Border.all(
            color: AppColors.border,
            width: AppDimens.borderThick,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: double.infinity,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              border: Border.all(color: AppColors.border, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({required this.isPrivate, required this.onChanged});

  final bool isPrivate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.muted,
        border: Border.all(
          color: AppColors.border,
          width: AppDimens.borderThick,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPrivate ? Icons.lock : Icons.public,
            color: isPrivate ? AppColors.primary : AppColors.mutedForeground,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPrivate ? 'Private Event' : 'Public Event',
                  style: AppTextStyles.body(16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  isPrivate
                      ? 'Only tagged users can see this'
                      : 'Visible to everyone',
                  style: AppTextStyles.body(
                    14,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          _BrutalistToggle(
            value: isPrivate,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _EventStatusToggle extends StatelessWidget {
  const _EventStatusToggle({
    required this.addToCalendar,
    required this.onChanged,
  });

  final bool addToCalendar;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final going = !addToCalendar;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.muted,
        border: Border.all(
          color: AppColors.border,
          width: AppDimens.borderThick,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  going ? 'Going To' : 'Interested',
                  style: AppTextStyles.body(16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  going
                      ? 'Confirm your attendance'
                      : 'Show interest without confirming',
                  style: AppTextStyles.body(
                    14,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          _BrutalistToggle(
            value: addToCalendar,
            onChanged: onChanged,
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

Future<String?> _pickEventPhoto(BuildContext context) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 100,
  );
  if (picked == null) return null;

  if (!context.mounted) return picked.path;
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
    return picked.path;
  }

  try {
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Crop Photo', lockAspectRatio: false),
        IOSUiSettings(title: 'Crop Photo'),
      ],
    );
    return cropped?.path ?? picked.path;
  } catch (_) {
    return picked.path;
  }
}

Future<File> _compressPhoto(String path) async {
  final size = await File(path).length();
  final target = (size * 0.6).round();

  List<int>? bytes;
  for (var q = 90; q >= 40; q -= 5) {
    final out = await FlutterImageCompress.compressWithFile(
      path,
      quality: q,
      format: CompressFormat.jpeg,
    );
    if (out == null) continue;
    bytes = out;
    if (out.length <= target) break;
  }

  if (bytes == null) {
    throw Exception('Could not compress image.');
  }

  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/post_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  await file.writeAsBytes(bytes);
  return file;
}
