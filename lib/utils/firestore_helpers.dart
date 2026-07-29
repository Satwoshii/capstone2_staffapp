import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? dateTimeFromFirestore(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  if (value is int) {
    final milliseconds = value.abs() < 100000000000 ? value * 1000 : value;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  return DateTime.tryParse(value.toString());
}

int compareFirestoreTimestamps(dynamic a, dynamic b) {
  final aDate = dateTimeFromFirestore(a);
  final bDate = dateTimeFromFirestore(b);

  if (aDate == null && bDate == null) return 0;
  if (aDate == null) return -1;
  if (bDate == null) return 1;
  return aDate.compareTo(bDate);
}

String formatFirestoreTimestamp(dynamic value) {
  final date = dateTimeFromFirestore(value)?.toLocal();
  if (date == null) return 'Not available';

  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)} '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}

bool boolFromFirestore(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == 'yes' || normalized == 'active') {
    return true;
  }
  if (normalized == 'false' ||
      normalized == 'no' ||
      normalized == 'inactive') {
    return false;
  }

  return fallback;
}

String stringFromFirestore(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String readableFirestoreValue(dynamic value) {
  if (value == null) return '';

  if (value is Iterable) {
    return value
        .map(readableFirestoreValue)
        .where((item) => item.isNotEmpty)
        .join(', ');
  }

  if (value is Map) {
    return value.entries
        .map(
          (entry) =>
              '${_titleCase(entry.key.toString())}: '
              '${readableFirestoreValue(entry.value)}',
        )
        .join(' • ');
  }

  return value.toString().trim();
}

String _titleCase(String value) {
  final words = value
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'));

  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
