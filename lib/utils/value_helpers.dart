String cleanError(Object error) {
  return error.toString().replaceFirst('Exception:', '').trim();
}

String formatDateTime(DateTime? value) {
  if (value == null) return 'Not available';
  final date = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}

String readableValue(dynamic value) {
  if (value == null) return '';
  if (value is Iterable) {
    return value.map(readableValue).where((item) => item.isNotEmpty).join(', ');
  }
  if (value is Map) {
    return value.entries
        .map((entry) => '${_title(entry.key.toString())}: '
            '${readableValue(entry.value)}')
        .join(' • ');
  }
  return value.toString().trim();
}

String _title(String value) {
  return value
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
