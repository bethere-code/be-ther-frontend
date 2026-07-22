import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../data/places_repository.dart';

/// Location field: search Google Places (min 3 chars) or use GPS.
/// Manual free-text is not allowed — user must pick a suggestion or GPS result.
class EventPlaceField extends ConsumerStatefulWidget {
  const EventPlaceField({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onCleared,
    required this.userLatLng,
    required this.onUserLatLng,
    this.errorText,
  });

  final StructuredPlace? selected;
  final ValueChanged<StructuredPlace> onSelected;
  final VoidCallback onCleared;
  final ({double lat, double lng})? userLatLng;
  final ValueChanged<({double lat, double lng})> onUserLatLng;
  final String? errorText;

  @override
  ConsumerState<EventPlaceField> createState() => _EventPlaceFieldState();
}

class _EventPlaceFieldState extends ConsumerState<EventPlaceField> {
  static const _hintColor = Color(0xFFB8BCC4);

  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _sessionToken = _newSessionToken();

  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _searching = false;
  bool _resolving = false;
  bool _gpsBusy = false;
  String? _inlineMessage;
  int _searchGen = 0;

  /// Ignore text changes while we programmatically fill after a pick / GPS.
  bool _suppressTextListener = false;

  /// True while the user is touching/scrolling the suggestion list.
  /// Keeps the dropdown visible even after the TextField loses focus.
  bool _holdingDropdown = false;
  Timer? _releaseDropdownTimer;

  bool get _showDropdown =>
      _suggestions.isNotEmpty && (_focus.hasFocus || _holdingDropdown);

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) {
      _controller.text = widget.selected!.displayLabel;
    }
    _controller.addListener(_onTextChanged);
    _focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_focus.hasFocus) {
      unawaited(_warmUserLocationForBias());
      return;
    }
    // Finger still on the dropdown (scroll / tap) — keep it open.
    if (_holdingDropdown) return;
    // Tapped elsewhere (date/time/etc.) — hide the list.
    _scheduleHideDropdownIfIdle();
  }

  void _onDropdownPointerDown() {
    _releaseDropdownTimer?.cancel();
    if (!_holdingDropdown) {
      setState(() => _holdingDropdown = true);
    }
  }

  void _onDropdownPointerUp() {
    if (_holdingDropdown) {
      setState(() => _holdingDropdown = false);
    }
    _scheduleHideDropdownIfIdle();
  }

  void _scheduleHideDropdownIfIdle() {
    _releaseDropdownTimer?.cancel();
    _releaseDropdownTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      if (_holdingDropdown || _focus.hasFocus) return;
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
    });
  }

  /// Quietly read GPS if permission is already granted (no prompt).
  /// Used for nearby search bias + saving userLocation on the post.
  Future<void> _warmUserLocationForBias() async {
    if (widget.userLatLng != null) return;
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
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      widget.onUserLatLng((lat: position.latitude, lng: position.longitude));
    } catch (_) {
      // Bias is optional — search still works without it.
    }
  }

  @override
  void didUpdateWidget(covariant EventPlaceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == null && oldWidget.selected != null) {
      _suppressTextListener = true;
      _controller.clear();
      _suppressTextListener = false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _releaseDropdownTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _focus.removeListener(_onFocusChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  static String _newSessionToken() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  void _onTextChanged() {
    if (_suppressTextListener) return;

    // Typing invalidates a previous selection until they pick again.
    if (widget.selected != null) {
      widget.onCleared();
    }

    final q = _controller.text.trim();
    _debounce?.cancel();
    if (q.length < 3) {
      setState(() {
        _suggestions = [];
        _searching = false;
        _inlineMessage = q.isEmpty
            ? null
            : 'Type at least 3 characters to search';
      });
      return;
    }

    setState(() {
      _inlineMessage = null;
      _searching = true;
    });
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_runSearch(q));
    });
  }

  Future<void> _runSearch(String query) async {
    final gen = ++_searchGen;
    try {
      final places = PlacesRepository(ref.read(apiClientProvider));
      final bias = widget.userLatLng;
      final results = await places.autocomplete(
        query: query,
        lat: bias?.lat,
        lng: bias?.lng,
        sessionToken: _sessionToken,
      );
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _suggestions = results;
        _searching = false;
        _inlineMessage = results.isEmpty ? 'No places found' : null;
      });
    } catch (e) {
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _suggestions = [];
        _searching = false;
        _inlineMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickSuggestion(PlaceSuggestion suggestion) async {
    setState(() {
      _resolving = true;
      _suggestions = [];
      _inlineMessage = null;
    });
    try {
      final places = PlacesRepository(ref.read(apiClientProvider));
      final place = await places.details(
        placeId: suggestion.placeId,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      _suppressTextListener = true;
      _controller.text = place.displayLabel;
      _suppressTextListener = false;
      widget.onSelected(place);
      _focus.unfocus();
      setState(() => _resolving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _inlineMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _gpsBusy = true;
      _inlineMessage = null;
      _suggestions = [];
    });

    try {
      final position = await _readDevicePosition();
      widget.onUserLatLng((lat: position.latitude, lng: position.longitude));

      final places = PlacesRepository(ref.read(apiClientProvider));
      final place = await places.reverseGeocode(
        lat: position.latitude,
        lng: position.longitude,
      );
      if (!mounted) return;

      _suppressTextListener = true;
      _controller.text = place.displayLabel;
      _suppressTextListener = false;
      widget.onSelected(place);
      _focus.unfocus();
      setState(() => _gpsBusy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gpsBusy = false;
        _inlineMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<Position> _readDevicePosition() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      throw Exception('Turn on location services to use GPS');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }
    if (permission == LocationPermission.deniedForever) {
      await openAppSettings();
      throw Exception('Enable location permission in Settings');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final borderColor = hasError ? AppColors.destructive : AppColors.border;
    final busy = _searching || _resolving || _gpsBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.search,
          maxLines: null,
          style: AppTextStyles.body(13, weight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Search venue, hall, auditorium…',
            hintStyle: AppTextStyles.body(
              14,
              color: _hintColor,
              weight: FontWeight.w500,
            ),
            errorText: widget.errorText,
            errorStyle: AppTextStyles.body(
              12,
              color: AppColors.destructive,
              weight: FontWeight.w600,
            ),
            errorMaxLines: 2,
            prefixIcon: const Icon(Icons.place, color: _hintColor, size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (_controller.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: () {
                      _suppressTextListener = true;
                      _controller.clear();
                      _suppressTextListener = false;
                      widget.onCleared();
                      setState(() {
                        _suggestions = [];
                        _inlineMessage = null;
                      });
                    },
                    icon: const Icon(Icons.close, size: 18, color: _hintColor),
                  ),
                IconButton(
                  tooltip: 'Use current location',
                  onPressed: _gpsBusy ? null : _useCurrentLocation,
                  icon: Icon(
                    Icons.my_location,
                    size: 20,
                    color: _gpsBusy ? _hintColor : AppColors.secondary,
                  ),
                ),
              ],
            ),
            filled: true,
            fillColor: AppColors.inputBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: borderColor,
                width: AppDimens.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: borderColor,
                width: AppDimens.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: hasError ? AppColors.destructive : AppColors.primary,
                width: AppDimens.border,
              ),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: AppColors.destructive,
                width: AppDimens.border,
              ),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: AppColors.destructive,
                width: AppDimens.border,
              ),
            ),
          ),
        ),
        if (_inlineMessage != null &&
            (widget.errorText == null || widget.errorText!.isEmpty)) ...[
          const SizedBox(height: 6),
          Text(
            _inlineMessage!,
            style: AppTextStyles.body(
              12,
              color: AppColors.mutedForeground,
              weight: FontWeight.w500,
            ),
          ),
        ],
        if (_showDropdown) ...[
          const SizedBox(height: 6),
          // Keep list while touching/scrolling it; hide when focus leaves the field.
          Listener(
            onPointerDown: (_) => _onDropdownPointerDown(),
            onPointerUp: (_) => _onDropdownPointerUp(),
            onPointerCancel: (_) => _onDropdownPointerUp(),
            child: ExcludeFocus(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification &&
                      _focus.hasFocus) {
                    _focus.unfocus();
                  }
                  // Absorb so the parent form ListView does not steal the drag.
                  return true;
                },
                child: Material(
                  color: AppColors.card,
                  elevation: 2,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      primary: false,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const ClampingScrollPhysics(),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.muted),
                      itemBuilder: (context, index) {
                        final s = _suggestions[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.secondary,
                            size: 22,
                          ),
                          title: Text(
                            s.primaryText,
                            style: AppTextStyles.body(
                              14,
                              weight: FontWeight.w700,
                            ),
                          ),
                          subtitle: s.secondaryText.isEmpty
                              ? null
                              : Text(
                                  s.secondaryText,
                                  style: AppTextStyles.body(
                                    12,
                                    color: AppColors.mutedForeground,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                          onTap: () => unawaited(_pickSuggestion(s)),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
