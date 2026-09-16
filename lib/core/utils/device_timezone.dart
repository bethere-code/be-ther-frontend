/// Best-effort IANA timezone id without a plugin.
/// Common abbreviations mapped; else fixed Etc/GMT±N from offset.
String deviceTimeZoneId() {
  final now = DateTime.now();
  final name = now.timeZoneName.trim().toUpperCase();
  const known = <String, String>{
    'IST': 'Asia/Kolkata',
    'INDIA STANDARD TIME': 'Asia/Kolkata',
    'PKT': 'Asia/Karachi',
    'BST': 'Asia/Dhaka',
    'NPT': 'Asia/Kathmandu',
    'GMT': 'UTC',
    'UTC': 'UTC',
    'EST': 'America/New_York',
    'EDT': 'America/New_York',
    'CST': 'America/Chicago',
    'CDT': 'America/Chicago',
    'MST': 'America/Denver',
    'MDT': 'America/Denver',
    'PST': 'America/Los_Angeles',
    'PDT': 'America/Los_Angeles',
    'JST': 'Asia/Tokyo',
    'KST': 'Asia/Seoul',
    'SGT': 'Asia/Singapore',
    'HKT': 'Asia/Hong_Kong',
    'CET': 'Europe/Berlin',
    'CEST': 'Europe/Berlin',
    'WET': 'Europe/Lisbon',
    'WEST': 'Europe/Lisbon',
    'GMT+5:30': 'Asia/Kolkata',
    'GMT+0530': 'Asia/Kolkata',
  };
  final mapped = known[name];
  if (mapped != null) return mapped;

  // Already looks like IANA.
  if (name.contains('/')) return now.timeZoneName.trim();

  final totalMin = now.timeZoneOffset.inMinutes;
  if (totalMin % 60 != 0) {
    // Odd offsets (e.g. +5:30) — India-first product default.
    if (totalMin == 330) return 'Asia/Kolkata';
    if (totalMin == 345) return 'Asia/Kathmandu';
    return 'UTC';
  }
  final hours = totalMin ~/ 60;
  if (hours == 0) return 'UTC';
  // Etc/GMT signs are inverted vs ISO offsets.
  return hours > 0 ? 'Etc/GMT-$hours' : 'Etc/GMT+${-hours}';
}
