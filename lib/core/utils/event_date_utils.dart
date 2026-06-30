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

  static bool isEventPast({
    String? dateRaw,
    String? timeRaw,
    DateTime? now,
  }) {
    final iso = parseEventDateToIso(dateRaw);
    if (iso == null) return false;

    final current = now ?? DateTime.now();
    final todayIso =
        '${current.year.toString().padLeft(4, '0')}-'
        '${current.month.toString().padLeft(2, '0')}-'
        '${current.day.toString().padLeft(2, '0')}';

    if (iso.compareTo(todayIso) < 0) return true;
    if (iso.compareTo(todayIso) > 0) return false;

    final time = timeRaw?.trim();
    if (time == null || time.isEmpty) return false;

    final combined = DateTime.tryParse('${iso}T$time') ?? DateTime.tryParse('$iso $time');
    if (combined == null) return false;
    return combined.isBefore(current);
  }

  static bool isEventPastFromDateTime(DateTime date, {String? timeRaw, DateTime? now}) {
    final iso =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return isEventPast(dateRaw: iso, timeRaw: timeRaw, now: now);
  }

  static bool isPostPast(Map<String, dynamic> post, {DateTime? now}) {
    final apiFlag = post['isEventPast'];
    if (apiFlag is bool) return apiFlag;

    final details = post['eventDetails'] as Map<String, dynamic>?;
    final fromDetails = isEventPast(
      dateRaw: details?['date'] as String?,
      timeRaw: details?['time'] as String?,
      now: now,
    );
    if (details?['date'] != null) return fromDetails;

    final createdAt = post['createdAt'] as String?;
    if (createdAt != null) {
      final created = DateTime.tryParse(createdAt);
      if (created != null) {
        return isEventPastFromDateTime(created, now: now);
      }
    }
    return fromDetails;
  }

  static bool isExploreItemPast(Map<String, dynamic> event, {DateTime? now}) {
    final apiFlag = event['isPast'] ?? event['isEventPast'];
    if (apiFlag is bool) return apiFlag;
    return isEventPast(
      dateRaw: event['date'] as String?,
      timeRaw: event['time'] as String?,
      now: now,
    );
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
}
