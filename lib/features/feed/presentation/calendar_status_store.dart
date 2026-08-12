import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_colors.dart';

/// Cross-screen RSVP overrides so feed / explore / search stay in sync
/// without waiting for a full list refresh.
///
/// Important: a stored `null` means “explicitly not on calendar” and must
/// win over stale API / local widget state (do not use `??` on map lookups).
final calendarStatusStoreProvider =
    NotifierProvider<CalendarStatusStore, Map<String, String?>>(
  CalendarStatusStore.new,
);

class CalendarStatusStore extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() => const {};

  /// `interested` | `going` | `null` (cleared / not on calendar).
  void setStatus(String postId, String? status) {
    final id = postId.trim();
    if (id.isEmpty) return;
    state = {...state, id: status};
  }

  bool hasOverride(String postId) => state.containsKey(postId.trim());

  /// Prefers an explicit override (including `null` clear) over [fallback].
  String? statusFor(String postId, {String? fallback}) {
    final id = postId.trim();
    if (id.isEmpty) return fallback;
    if (state.containsKey(id)) return state[id];
    return fallback;
  }

  /// Write server truth into the store (including `null` = not on calendar).
  void syncFromApi(String postId, String? status) {
    setStatus(postId, status);
  }
}

/// Shared RSVP resolution used by feed, explore sheet, and notifications.
///
/// Priority: in-memory store → API calendar fields → own-post `status` fallback.
String? resolveViewerCalendarStatus({
  required CalendarStatusStore store,
  required String postId,
  String? apiCalendarStatus,
  bool inCalendar = false,
  bool isMine = false,
  String? postStatus,
}) {
  final api =
      apiCalendarStatus ??
      (inCalendar ? 'going' : null);
  final ownFallback = isMine
      ? (postStatus == 'interested' ? 'interested' : 'going')
      : null;
  return store.statusFor(postId, fallback: api ?? ownFallback);
}

String calendarButtonLabel(String? status) {
  return switch (status) {
    'interested' => 'INTERESTED',
    'going' => 'GOING',
    _ => 'ADD TO CALENDAR',
  };
}

String calendarTileLabel(String? status) {
  return switch (status) {
    'interested' => 'INTERESTED',
    'going' => 'GOING',
    _ => 'ADD TO CALENDAR',
  };
}

/// Bright RSVP CTA colors — same on feed, explore, search, and profile.
/// Add = amber · Interested = coral · Going = navy (clearly distinct from Add).
Color calendarButtonBackground(String? status) {
  return switch (status) {
    'going' => AppColors.secondary,
    'interested' => AppColors.primary,
    _ => AppColors.accent,
  };
}

Color calendarButtonForeground(String? status) {
  return switch (status) {
    'going' => AppColors.secondaryForeground,
    'interested' => AppColors.primaryForeground,
    _ => AppColors.accentForeground,
  };
}

