import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Shared event date parsing and past/upcoming checks (mirrors backend event-date.ts).
abstract final class EventDateUtils {
  static const _monthMap = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  /// Minutes after start before an event counts as past (`EVENT_PAST_GRACE_MINUTES`).
  static int get pastGraceMinutes {
    final raw = dotenv.maybeGet('EVENT_PAST_GRACE_MINUTES')?.trim();
    final n = int.tryParse(raw ?? '');
    if (n == null || n < 0) return 60;
    return n;
  }

  /// Normalizes event date strings (ISO or "Jul 15, 2026") to YYYY-MM-DD.
  static String? parseEventDateToIso(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(trimmed)) {
      return trimmed.substring(0, 10);
    }

    final rangeMatch = RegExp(
      r'([A-Za-z]+)\s+(\d+)(?:-\d+)?,\s*(\d{4})',
    ).firstMatch(trimmed);
    if (rangeMatch != null) {
      final monthRaw = rangeMatch.group(1)!;
      final day = int.tryParse(rangeMatch.group(2)!);
      final year = int.tryParse(rangeMatch.group(3)!);
      final month = _monthMap[monthRaw.substring(0, 3).toLowerCase()];
      if (month != null && day != null && year != null) {
        return '${year.toString().padLeft(4, '0')}-'
            '${month.toString().padLeft(2, '0')}-'
            '${day.toString().padLeft(2, '0')}';
      }
    }

    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return '${parsed.year.toString().padLeft(4, '0')}-'
          '${parsed.month.toString().padLeft(2, '0')}-'
          '${parsed.day.toString().padLeft(2, '0')}';
    }

    return null;
  }

  static ({int hour, int minute})? _parseTimeParts(String timeRaw) {
    final trimmed = timeRaw.trim();
    final twelve = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$',
    ).firstMatch(trimmed);
    if (twelve != null) {
      var hour = int.tryParse(twelve.group(1)!);
      final minute = int.tryParse(twelve.group(2)!);
      if (hour == null || minute == null || minute < 0 || minute > 59) {
        return null;
      }
      final period = twelve.group(3)!.toUpperCase();
      if (period == 'AM') {
        hour = hour % 12;
      } else {
        hour = (hour % 12) + 12;
      }
      if (hour < 0 || hour > 23) return null;
      return (hour: hour, minute: minute);
    }

    final twentyFour = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    if (twentyFour != null) {
      final hour = int.tryParse(twentyFour.group(1)!);
      final minute = int.tryParse(twentyFour.group(2)!);
      if (hour == null ||
          minute == null ||
          hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59) {
        return null;
      }
      return (hour: hour, minute: minute);
    }

    return null;
  }

  static DateTime? _eventStartLocal(String isoDate, String timeRaw) {
    final parts = _parseTimeParts(timeRaw);
    if (parts == null) return null;
    final bits = isoDate.split('-');
    if (bits.length < 3) return null;
    final y = int.tryParse(bits[0]);
    final m = int.tryParse(bits[1]);
    final d = int.tryParse(bits[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d, parts.hour, parts.minute);
  }

  /// With a time: past only after start + [pastGraceMinutes].
  /// Date-only: past once the calendar day is before today.
  static bool isEventPast({
    String? dateRaw,
    String? timeRaw,
    DateTime? now,
  }) {
    final iso = parseEventDateToIso(dateRaw);
    if (iso == null) return false;

    final current = now ?? DateTime.now();
    final time = timeRaw?.trim();
    if (time != null && time.isNotEmpty) {
      final start = _eventStartLocal(iso, time);
      if (start == null) return false;
      final cutoff = start.add(Duration(minutes: pastGraceMinutes));
      return !current.isBefore(cutoff);
    }

    final todayIso =
        '${current.year.toString().padLeft(4, '0')}-'
        '${current.month.toString().padLeft(2, '0')}-'
        '${current.day.toString().padLeft(2, '0')}';
    return iso.compareTo(todayIso) < 0;
  }

  static bool isEventPastFromDateTime(DateTime date, {String? timeRaw, DateTime? now}) {
    final iso =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return isEventPast(dateRaw: iso, timeRaw: timeRaw, now: now);
  }

  static bool isPostPast(Map<String, dynamic> post, {DateTime? now}) {
    final details = post['eventDetails'] as Map<String, dynamic>?;
    if (details != null && details['date'] != null) {
      // Always compute locally so EVENT_PAST_GRACE_MINUTES applies.
      return isEventPast(
        dateRaw: details['date'] as String?,
        timeRaw: details['time'] as String?,
        now: now,
      );
    }

    final apiFlag = post['isEventPast'];
    if (apiFlag is bool) return apiFlag;

    final createdAt = post['createdAt'] as String?;
    if (createdAt != null) {
      final created = DateTime.tryParse(createdAt);
      if (created != null) {
        return isEventPastFromDateTime(created, now: now);
      }
    }
    return false;
  }

  static bool isExploreItemPast(Map<String, dynamic> event, {DateTime? now}) {
    final dateRaw = event['date'] as String?;
    final timeRaw = event['time'] as String?;
    if (dateRaw != null && dateRaw.trim().isNotEmpty) {
      return isEventPast(dateRaw: dateRaw, timeRaw: timeRaw, now: now);
    }
    final apiFlag = event['isPast'] ?? event['isEventPast'];
    if (apiFlag is bool) return apiFlag;
    return false;
  }

  /// RSVP-style label for badges. Returns "PAST EVENT" when the event has ended.
  static String statusLabel({
    required String status,
    required bool isPast,
  }) {
    if (isPast) return 'PAST EVENT';
    return switch (status) {
      'been' => 'BEEN',
      'going' => 'GOING',
      _ => 'INTERESTED',
    };
  }

  /// `HH:mm` or already-localized → `h:mm AM/PM`. Returns null for blank input.
  static String? formatTime12h(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final twelve = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$',
    ).firstMatch(trimmed);
    if (twelve != null) {
      var hour = int.parse(twelve.group(1)!);
      final minute = twelve.group(2)!;
      final period = twelve.group(3)!.toUpperCase();
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $period';
    }

    final twentyFour = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    if (twentyFour != null) {
      var hour = int.parse(twentyFour.group(1)!);
      final minute = twentyFour.group(2)!;
      if (hour < 0 || hour > 23) return trimmed;
      final period = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $period';
    }

    return trimmed;
  }
}
