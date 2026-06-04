import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
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

  @override
  void dispose() {
    _eventName.dispose();
    _description.dispose();
    _location.dispose();
    _ticket.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/feed');
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (!mounted) return;
    if (file != null) {
      setState(() => _imagePath = file.path);
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
    if (value.trim().length > 2000) {
      return 'Description must be less than 2000 characters';
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

  bool _hasValidationErrors() {
    return _validateEventName(_eventName.text) != null ||
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
    _markTouched(_fieldDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _post() async {
    if (_busy) return;
    setState(() => _attemptedSubmit = true);

    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a photo before posting')),
      );
      return;
    }
    if (_hasValidationErrors()) return;

    final ticketUrl = _normalizeTicketUrl();
    setState(() => _busy = true);
    try {
      final dio = ref.read(apiClientProvider);
      final posts = PostsRepository(dio);
      final url = await posts.uploadImage(_imagePath!);
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRequiredFields =
        _eventName.text.trim().isNotEmpty &&
        _location.text.trim().isNotEmpty &&
        _selectedDate != null &&
        _imagePath != null;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      body: Align(
        alignment: Alignment.bottomCenter,
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
                        onPressed: () => context.push(SearchScreen.path),
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
                  child: ListView(
                    padding: const EdgeInsets.all(16),
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
                                    color: AppColors.border,
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
                                            color: AppColors.mutedForeground,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'TAP TO UPLOAD',
                                            style: AppTextStyles.display(
                                              16,
                                              color: AppColors.mutedForeground,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Image.file(
                                        File(_imagePath!),
                                        fit: BoxFit.cover,
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
                      const SizedBox(height: 16),
                      const _SectionLabel('EVENT NAME *'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _eventName,
                        onChanged: (_) {
                          _markTouched(_fieldEventName);
                          setState(() {});
                        },
                        style: AppTextStyles.body(16, weight: FontWeight.w600),
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
                          hint: 'Share details about this event...',
                          errorText: _fieldError(
                            _fieldDescription,
                            () => _validateDescription(_description.text),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PrivacyToggle(
                        isPrivate: _private,
                        onChanged: (v) => setState(() => _private = v),
                      ),
                      const SizedBox(height: 16),
                      const _SectionLabel('LOCATION *'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _location,
                        onChanged: (_) {
                          _markTouched(_fieldLocation);
                          setState(() {});
                        },
                        style: AppTextStyles.body(16, weight: FontWeight.w600),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                            color: AppColors.mutedForeground,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                            color: AppColors.mutedForeground,
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
                        onChanged: (_) {
                          _markTouched(_fieldTicket);
                          setState(() {});
                        },
                        style: AppTextStyles.body(16, weight: FontWeight.w600),
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
                        onChanged: (v) => setState(() => _addToCalendar = v),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    decoration: const BoxDecoration(
                      color: AppColors.muted,
                      border: Border(
                        top: BorderSide(
                          color: AppColors.border,
                          width: AppDimens.borderThick,
                        ),
                      ),
                    ),
                    child: Material(
                      color: hasRequiredFields && !_busy
                          ? AppColors.primary
                          : AppColors.mutedForeground,
                      child: InkWell(
                        onTap: _busy ? null : _post,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.border,
                              width: AppDimens.borderThick,
                            ),
                            boxShadow: hasRequiredFields && !_busy
                                ? AppDimens.primaryButtonShadow
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.send,
                                color: AppColors.primaryForeground,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'POST EVENT',
                                style: AppTextStyles.display(
                                  20,
                                  color: AppColors.primaryForeground,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
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
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    String? errorText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: AppColors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.border,
          width: AppDimens.borderThick,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.border,
          width: AppDimens.borderThick,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.primary,
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
                  going ? 'Going To' : 'Add to Calendar',
                  style: AppTextStyles.body(16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  going
                      ? 'Confirm your attendance'
                      : 'Save for future reference',
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
