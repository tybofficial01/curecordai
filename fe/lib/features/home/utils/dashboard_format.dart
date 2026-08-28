// Date/time formatting helpers for the home dashboard, ported from
// web/app/dashboard/page.tsx. Web does not localize these either (they are
// plain English unit words regardless of locale), so this mirrors that
// behaviour rather than inventing a new, unmatched translation surface.

/// "1 minute", "5 minutes", "2 hours", "3 days", "1 month", "2 years".
String formatRelativeTime(DateTime date, DateTime now) {
  final diffMinutes =
      (now.difference(date).inSeconds / 60).round().clamp(0, 1 << 31);
  if (diffMinutes < 60) {
    return diffMinutes <= 1 ? '1 minute' : '$diffMinutes minutes';
  }
  final diffHours = (diffMinutes / 60).round();
  if (diffHours < 24) {
    return diffHours == 1 ? '1 hour' : '$diffHours hours';
  }
  final diffDays = (diffHours / 24).round();
  if (diffDays < 30) {
    return diffDays == 1 ? '1 day' : '$diffDays days';
  }
  final diffMonths = (diffDays / 30).round();
  if (diffMonths < 12) {
    return diffMonths == 1 ? '1 month' : '$diffMonths months';
  }
  final diffYears = (diffMonths / 12).round();
  return diffYears == 1 ? '1 year' : '$diffYears years';
}

/// Compact form for list rows: "5m", "3h", "2d", "1w", "2mo", "1y".
String formatCompactRelativeTime(DateTime date, DateTime now) {
  final diffMinutes =
      (now.difference(date).inSeconds / 60).round().clamp(0, 1 << 31);
  if (diffMinutes < 1) return 'just now';
  if (diffMinutes < 60) return '${diffMinutes}m';
  final diffHours = (diffMinutes / 60).round();
  if (diffHours < 24) return '${diffHours}h';
  final diffDays = (diffHours / 24).round();
  if (diffDays < 7) return '${diffDays}d';
  if (diffDays < 30) return '${(diffDays / 7).round()}w';
  final diffMonths = (diffDays / 30).round();
  if (diffMonths < 12) return '${diffMonths}mo';
  return '${(diffMonths / 12).round()}y';
}

bool isWithinHours(DateTime date, int hours, DateTime now) {
  final diff = now.difference(date);
  return !diff.isNegative && diff.inHours <= hours;
}

/// One slice of the Total Documents stat card's category breakdown bar.
class DocumentCategorySegment {
  const DocumentCategorySegment({
    required this.key,
    required this.label,
    required this.count,
  });

  final String key;
  final String label;
  final int count;
}

/// Same grouping as web's getDocumentCategorySegments: prescriptions, radiology
/// and lab reports get their own named slice, everything else rolls into "Other".
List<DocumentCategorySegment> documentCategorySegments(
  List<Map<String, dynamic>> records,
  String prescriptionsLabel,
  String radiologyLabel,
  String labReportsLabel,
  String otherLabel,
) {
  final counts = <String, int>{};
  for (final record in records) {
    final type = record['record_type'] as String? ?? 'other';
    counts[type] = (counts[type] ?? 0) + 1;
  }

  final segments = [
    DocumentCategorySegment(
        key: 'prescription',
        label: prescriptionsLabel,
        count: counts['prescription'] ?? 0),
    DocumentCategorySegment(
        key: 'radiology', label: radiologyLabel, count: counts['radiology'] ?? 0),
    DocumentCategorySegment(
        key: 'lab_report',
        label: labReportsLabel,
        count: counts['lab_report'] ?? 0),
  ];

  final namedCount = segments.fold<int>(0, (sum, s) => sum + s.count);
  final otherCount = records.length - namedCount;
  if (otherCount > 0) {
    segments.add(
        DocumentCategorySegment(key: 'other', label: otherLabel, count: otherCount));
  }

  return segments;
}
