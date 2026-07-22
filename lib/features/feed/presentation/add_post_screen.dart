import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/be_ther_buttons.dart';
import '../../../core/media/ticket_link_preview.dart';
import '../../../core/network/api_client.dart';
import '../data/places_repository.dart';
import '../data/posts_repository.dart';
import 'feed_providers.dart';
import 'widgets/event_place_field.dart';

class AddPostScreen extends ConsumerStatefulWidget {
  const AddPostScreen({super.key});

  static const path = '/add';
  static const name = 'add';

  @override
  ConsumerState<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends ConsumerState<AddPostScreen> {
  static const _fieldBorder = AppDimens.border;
  static const _hintColor = Color(0xFFB8BCC4);

  final _eventName = TextEditingController();
  final _description = TextEditingController();
  final _ticket = TextEditingController();
  final _tagInput = TextEditingController();
  final _sheetController = DraggableScrollableController();

  bool _private = false;

  /// false = Interested (default); true = Going / attending.
  bool _isGoing = false;
  String? _imagePath;

  /// Selected Google Place / GPS result — required; free text is not allowed.
  StructuredPlace? _selectedPlace;
  ({double lat, double lng})? _userLatLng;

  /// True when the current photo came from ticket-link metadata (not gallery).
  bool _imageFromTicketLink = false;
  bool _ticketPreviewLoading = false;
  String? _ticketPreviewMessage;
  Timer? _ticketPreviewDebounce;
  int _ticketPreviewRequestId = 0;
  String? _lastTicketPreviewUrl;

  bool _busy = false;
  bool _attemptedSubmit = false;
  bool _closing = false;
  bool _dismissQueued = false;
  final _touched = <String, bool>{};
  final _taggedUsers = <String>[];
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  static const _fieldEventName = 'eventName';
  static const _fieldDescription = 'description';
  static const _fieldDate = 'date';
  static const _fieldTicket = 'ticket';
  static const _fieldImage = 'image';

  @override
  void initState() {
    super.initState();
    _ticket.addListener(_onTicketTextChanged);
    // If permission was already granted elsewhere in the app, capture poster GPS.
    unawaited(_tryCaptureUserLatLng());
  }

  @override
  void dispose() {
    _ticketPreviewDebounce?.cancel();
    _ticket.removeListener(_onTicketTextChanged);
    _sheetController.dispose();
    _eventName.dispose();
    _description.dispose();
    _ticket.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _unfocus() => FocusScope.of(context).unfocus();

  bool _hasUnsavedChanges() {
    return _imagePath != null ||
        _eventName.text.trim().isNotEmpty ||
        _description.text.trim().isNotEmpty ||
        _selectedPlace != null ||
        _ticket.text.trim().isNotEmpty ||
        _taggedUsers.isNotEmpty ||
        _selectedDate != null ||
        _selectedTime != null ||
        _private ||
        _isGoing;
  }

  Future<void> _snapSheetOpen() async {
    if (!_sheetController.isAttached) return;
    try {
      await _sheetController.animateTo(
        0.92,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {}
  }

  void _popRoute() {
    if (!mounted || _closing) return;
    _closing = true;
    // Pop immediately — never leave the route parked at min sheet size
    // (that caused the stuck blank cream panel + dim overlay).
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/feed');
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_hasUnsavedChanges()) return true;
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
    return discard == true;
  }

  /// Close from the X button / backdrop / system back.
  Future<void> _close(BuildContext context) async {
    if (_closing || _dismissQueued) return;
    _dismissQueued = true;
    _unfocus();
    try {
      final ok = await _confirmDiscardIfNeeded();
      if (!ok) return;
      if (!mounted) return;
      _popRoute();
    } finally {
      _dismissQueued = false;
    }
  }

  /// Dragged below the close threshold — restore UI first if we need a dialog.
  Future<void> _onSheetCollapsed() async {
    if (_closing || _dismissQueued) return;
    _dismissQueued = true;
    _unfocus();
    try {
      if (_hasUnsavedChanges()) {
        // Bring the sheet back up so we never sit on the blank compact panel.
        await _snapSheetOpen();
        if (!mounted) return;
        final ok = await _confirmDiscardIfNeeded();
        if (!ok) return;
      }
      if (!mounted) return;
      _popRoute();
    } finally {
      _dismissQueued = false;
    }
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
        _imageFromTicketLink = false;
        _ticketPreviewMessage = null;
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

  void _clearEventPhoto() {
    setState(() {
      _imagePath = null;
      _imageFromTicketLink = false;
      _ticketPreviewMessage = null;
    });
  }

  void _onTicketTextChanged() {
    _ticketPreviewDebounce?.cancel();
    final url = _normalizeTicketUrl();
    if (url == null) {
      _lastTicketPreviewUrl = null;
      if (_ticketPreviewLoading || _ticketPreviewMessage != null) {
        setState(() {
          _ticketPreviewLoading = false;
          _ticketPreviewMessage = null;
        });
      }
      return;
    }

    if (url == _lastTicketPreviewUrl &&
        (_imageFromTicketLink || _ticketPreviewLoading)) {
      return;
    }

    _ticketPreviewDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_fetchTicketLinkPreview(url));
    });
  }

  Future<void> _fetchTicketLinkPreview(String url) async {
    // Never replace a photo the user picked from the gallery.
    if (_imagePath != null && !_imageFromTicketLink) return;

    final requestId = ++_ticketPreviewRequestId;
    if (mounted) {
      setState(() {
        _ticketPreviewLoading = true;
        _ticketPreviewMessage = null;
      });
    }

    try {
      // Resolve OG image on our server (WhatsApp-style). Phone scrapes are
      // often blocked by Cloudflare on BookMyShow / similar ticket sites.
      final api = ref.read(apiClientProvider);
      final imageUrl = await PostsRepository(api).fetchLinkPreviewImageUrl(url);
      if (!mounted || requestId != _ticketPreviewRequestId) return;

      if (_imagePath != null && !_imageFromTicketLink) {
        setState(() => _ticketPreviewLoading = false);
        return;
      }

      if (imageUrl == null) {
        setState(() {
          _ticketPreviewLoading = false;
          _lastTicketPreviewUrl = url;
          _ticketPreviewMessage = 'No preview image found for this link';
        });
        return;
      }

      final savePath = await downloadPreviewImageToTemp(imageUrl);
      if (!mounted || requestId != _ticketPreviewRequestId) return;

      if (_imagePath != null && !_imageFromTicketLink) {
        setState(() => _ticketPreviewLoading = false);
        return;
      }

      if (savePath == null) {
        setState(() {
          _ticketPreviewLoading = false;
          _lastTicketPreviewUrl = url;
          _ticketPreviewMessage = 'Could not load preview image';
        });
        return;
      }

      setState(() {
        _imagePath = savePath;
        _imageFromTicketLink = true;
        _ticketPreviewLoading = false;
        _ticketPreviewMessage = null;
        _lastTicketPreviewUrl = url;
        _touched[_fieldImage] = true;
      });
    } catch (_) {
      if (!mounted || requestId != _ticketPreviewRequestId) return;
      setState(() {
        _ticketPreviewLoading = false;
        _lastTicketPreviewUrl = url;
        _ticketPreviewMessage = 'Could not load preview from this link';
      });
    }
  }

  String? _validateEventName(String value) {
    if (value.trim().isEmpty) return 'Event name is required';
    if (value.trim().length > 200) {
      return 'Event name must be less than 200 characters';
    }
    return null;
  }

  String? _validateLocation() {
    if (_selectedPlace == null) {
      return 'Select a location from the list or use GPS';
    }
    return null;
  }

  /// Location error only after submit — not while typing / focusing the field.
  String? _locationSubmitError() {
    if (!_attemptedSubmit) return null;
    return _validateLocation();
  }

  /// If the app already has location permission, read GPS for userLocation.
  /// Does not prompt — only uses an existing grant.
  Future<void> _tryCaptureUserLatLng() async {
    if (_userLatLng != null) return;
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) return;

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      setState(() {
        _userLatLng = (lat: position.latitude, lng: position.longitude);
      });
    } catch (_) {
      // Optional — posting still works without poster coordinates.
    }
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
        _validateLocation() != null ||
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
    // Dismiss any open keyboard before the system picker appears.
    FocusManager.instance.primaryFocus?.unfocus();
    _markTouched(_fieldDate);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();

    if (picked == null) return;

    setState(() => _selectedDate = picked);
    // Continuously ask for time — user should not need a second tap.
    await _pickTime();
  }

  Future<void> _pickTime() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _post() async {
    if (_busy) return;
    _unfocus();
    setState(() => _attemptedSubmit = true);

    if (_hasValidationErrors()) return;

    // Last chance to attach poster coordinates if permission already exists.
    await _tryCaptureUserLatLng();
    if (!mounted) return;

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
      final place = _selectedPlace!;
      final eventDetails = <String, dynamic>{
        'type': 'event',
        'date': _formatDateForApi(),
        'venue': place.name,
        'time': ?_formatTimeForApi(),
        'ticketUrl': ?ticketUrl,
        'eventLocation': place.toJson(),
        if (_userLatLng != null)
          'userLocation': {'lat': _userLatLng!.lat, 'lng': _userLatLng!.lng},
      };
      await posts.createPost({
        'location': _eventName.text.trim(),
        'country': place.country.isNotEmpty ? place.country : place.city,
        'status': _isGoing ? 'going' : 'interested',
        'imageUrl': url,
        'caption': _description.text.trim(),
        'isPrivate': _private,
        'addToCalendar': _isGoing,
        if (_taggedUsers.isNotEmpty) 'taggedUsernames': _taggedUsers,
        'eventDetails': eventDetails,
      });
      ref.invalidate(feedProvider);
      if (!mounted) return;
      _popRoute();
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
      backgroundColor: Colors.black.withValues(alpha: 0.55),
      resizeToAvoidBottomInset: false,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close(context);
        },
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _close(context),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
            ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                // Hit the floor of the sheet — close the route (don't park here).
                if (!_closing &&
                    !_dismissQueued &&
                    notification.extent <= notification.minExtent + 0.02) {
                  _onSheetCollapsed();
                }
                return false;
              },
              child: DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: 0.92,
                minChildSize: 0.35,
                maxChildSize: 0.96,
                snap: true,
                snapSizes: const [0.55, 0.92],
                builder: (context, scrollController) {
                  return Material(
                    color: AppColors.background,
                    clipBehavior: Clip.hardEdge,
                    child: Column(
                      children: [
                        const _SheetDragHandle(),
                        Container(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.border,
                                width: AppDimens.border,
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
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _unfocus,
                            behavior: HitTestBehavior.translucent,
                            child: ListView(
                              controller: scrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                24 + keyboard,
                              ),
                              children: [
                                const _SectionLabel('EVENT NAME *'),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _eventName,
                                  textCapitalization:
                                      TextCapitalization.sentences,
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
                                  textCapitalization:
                                      TextCapitalization.sentences,
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
                                    hint: 'Add how you feel about this event!',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 11.5,
                                    ),
                                    errorText: _fieldError(
                                      _fieldDescription,
                                      () => _validateDescription(
                                        _description.text,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const _SectionLabel('LOCATION *'),
                                const SizedBox(height: 8),
                                EventPlaceField(
                                  selected: _selectedPlace,
                                  userLatLng: _userLatLng,
                                  errorText: _locationSubmitError(),
                                  onSelected: (place) {
                                    setState(() {
                                      _selectedPlace = place;
                                    });
                                  },
                                  onCleared: () {
                                    setState(() => _selectedPlace = null);
                                  },
                                  onUserLatLng: (coords) {
                                    setState(() => _userLatLng = coords);
                                  },
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
                                              isEmpty: _selectedDate == null,
                                              decoration:
                                                  _inputDecoration(
                                                    hint: 'Select date',
                                                    errorText: _fieldError(
                                                      _fieldDate,
                                                      _validateDate,
                                                    ),
                                                  ).copyWith(
                                                    suffixIcon: const Icon(
                                                      Icons.calendar_today,
                                                      color: _hintColor,
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
                                              isEmpty: _selectedTime == null,
                                              decoration:
                                                  _inputDecoration(
                                                    hint: 'Select time',
                                                  ).copyWith(
                                                    suffixIcon: const Icon(
                                                      Icons.access_time,
                                                      color: _hintColor,
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
                                _PrivacyToggle(
                                  isPrivate: _private,
                                  onChanged: (v) {
                                    _unfocus();
                                    setState(() => _private = v);
                                  },
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
                                    prefixIcon: const Icon(
                                      Icons.open_in_new,
                                      color: _hintColor,
                                      size: 18,
                                    ),
                                    errorText: _fieldError(
                                      _fieldTicket,
                                      () => _validateTicket(_ticket.text),
                                    ),
                                  ),
                                ),
                                if (_ticketPreviewLoading) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Looking up event photo from this link…',
                                          style: AppTextStyles.body(
                                            13,
                                            color: AppColors.mutedForeground,
                                            weight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (_ticketPreviewMessage != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _ticketPreviewMessage!,
                                    style: AppTextStyles.body(
                                      13,
                                      color: AppColors.mutedForeground,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                const _SectionLabel('EVENT PHOTO'),
                                const SizedBox(height: 8),
                                AspectRatio(
                                  aspectRatio: 16 / 7,
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
                                              width: _fieldBorder,
                                            ),
                                          ),
                                          child: _imagePath == null
                                              ? Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.image_outlined,
                                                      size: 36,
                                                      color: AppColors
                                                          .mutedForeground,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'TAP TO UPLOAD',
                                                      style:
                                                          AppTextStyles.display(
                                                            14,
                                                            color: AppColors
                                                                .mutedForeground,
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
                                              onTap: _clearEventPhoto,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: AppColors.background,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: AppColors.background,
                                                  size: 18,
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
                                _EventStatusToggle(
                                  isGoing: _isGoing,
                                  onChanged: (v) {
                                    _unfocus();
                                    setState(() => _isGoing = v);
                                  },
                                ),
                                const SizedBox(height: 60),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    String? errorText,
    Widget? prefixIcon,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    final borderColor = hasError ? AppColors.destructive : AppColors.border;

    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.body(
        14,
        color: _hintColor,
        weight: FontWeight.w500,
      ),
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
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: borderColor, width: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: borderColor, width: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: hasError ? AppColors.destructive : AppColors.primary,
          width: _fieldBorder,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.destructive,
          width: _fieldBorder,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.destructive,
          width: _fieldBorder,
        ),
      ),
    );
  }
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.secondary,
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
          ),
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

/// Bright, soft pill switch — clearer for a broad audience than chunky squares.
class _BrightSwitch extends StatelessWidget {
  const _BrightSwitch({
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 56,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? activeColor : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              if (value)
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
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

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({required this.isPrivate, required this.onChanged});

  final bool isPrivate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: AppDimens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isPrivate
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : const Color(0xFFE8F5E9),
            ),
            child: Icon(
              isPrivate ? Icons.lock_rounded : Icons.public_rounded,
              color: isPrivate ? AppColors.primary : const Color(0xFF2E7D32),
              size: 22,
            ),
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
                    13,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          _BrightSwitch(
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
  const _EventStatusToggle({required this.isGoing, required this.onChanged});

  /// Off = Interested (default). On = Going / attending.
  final bool isGoing;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: AppDimens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isGoing
                  ? AppColors.accent.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.15),
            ),
            child: Icon(
              isGoing ? Icons.event_available_rounded : Icons.bookmark_rounded,
              color: isGoing ? AppColors.accent : AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGoing ? 'Going' : 'Interested',
                  style: AppTextStyles.body(16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  isGoing
                      ? 'You\'re attending this event'
                      : 'Interested, not confirmed yet',
                  style: AppTextStyles.body(
                    13,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          _BrightSwitch(
            value: isGoing,
            onChanged: onChanged,
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

/// Allowed crop ratios for new-post photos — no freeform / original / square.
const _eventPhotoAspectPresets = <CropAspectRatioPresetData>[
  CropAspectRatioPreset.ratio3x2,
  CropAspectRatioPreset.ratio16x9,
  CropAspectRatioPreset.ratio4x3,
];

Future<String?> _pickEventPhoto(BuildContext context) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 80,
  );
  if (picked == null) return null;

  if (!context.mounted) return null;
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
    return picked.path;
  }

  try {
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.ratio3x2,
          aspectRatioPresets: _eventPhotoAspectPresets,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: true,
          aspectRatioPickerButtonHidden: false,
          aspectRatioPresets: _eventPhotoAspectPresets,
        ),
      ],
    );
    // Cancel / back without tick → do not keep the gallery pick.
    return cropped?.path;
  } catch (_) {
    return null;
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
