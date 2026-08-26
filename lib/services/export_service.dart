import 'dart:convert';
import 'dart:io';

class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  Future<String> exportCsv({
    required String filePrefix,
    required List<String> headers,
    required List<List<Object?>> rows,
  }) async {
    final directory = await _exportDirectory();
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    final safePrefix = filePrefix
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    final file = File(
      '${directory.path}${Platform.pathSeparator}${safePrefix}_$stamp.csv',
    );

    final buffer = StringBuffer();
    buffer.writeln(headers.map(_csvCell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_csvCell).join(','));
    }

    // UTF-8 BOM makes Excel on Windows open Unicode text reliably.
    await file.writeAsBytes(
      <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())],
      flush: true,
    );
    return file.path;
  }

  Future<Directory> _exportDirectory() async {
    final profile = Platform.environment['USERPROFILE']?.trim();
    final candidates = <String>[
      if (profile != null && profile.isNotEmpty)
        '$profile${Platform.pathSeparator}Downloads${Platform.pathSeparator}Syswatch Exports',
      '${Directory.current.path}${Platform.pathSeparator}Syswatch Exports',
    ];

    for (final path in candidates) {
      try {
        final directory = Directory(path);
        await directory.create(recursive: true);
        return directory;
      } catch (_) {}
    }

    final fallback = Directory.systemTemp.createTempSync('syswatch_exports_');
    return fallback;
  }

  String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}
