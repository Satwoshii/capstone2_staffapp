import 'dart:convert';
import 'dart:io';

/// Metadata read from a Windows executable's embedded version information.
///
/// Syswatch never starts the selected executable. PowerShell only asks Windows
/// for the file's VersionInfo resource and returns the values as JSON.
class ExeMetadata {
  const ExeMetadata({
    required this.path,
    required this.fileName,
    required this.productName,
    required this.fileDescription,
    required this.publisher,
    required this.productVersion,
    required this.fileVersion,
    required this.originalFileName,
  });

  final String path;
  final String fileName;
  final String productName;
  final String fileDescription;
  final String publisher;
  final String productVersion;
  final String fileVersion;
  final String originalFileName;

  String get displayName => _firstNonEmpty([
        productName,
        fileDescription,
        _withoutExe(fileName),
      ]);

  /// Text used by the existing installed-software registry matcher.
  String get suggestedMatchText => displayName;

  /// Keeps only the numeric portion so the API can compare versions reliably.
  String get suggestedMinimumVersion {
    final source = _firstNonEmpty([productVersion, fileVersion]);
    return RegExp(r'\d+(?:\.\d+){0,3}').firstMatch(source)?.group(0) ?? '';
  }

  static String _firstNonEmpty(Iterable<String> values) {
    for (final value in values) {
      final clean = value.trim();
      if (clean.isNotEmpty) return clean;
    }
    return '';
  }

  static String _withoutExe(String value) {
    final clean = value.trim();
    if (clean.toLowerCase().endsWith('.exe')) {
      return clean.substring(0, clean.length - 4);
    }
    return clean;
  }
}

class ExeMetadataService {
  ExeMetadataService._();

  static final ExeMetadataService instance = ExeMetadataService._();

  static const String _powershellScript = r'''
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$selectedPath = $env:SYSWATCH_EXE_INSPECTION_PATH
$item = Get-Item -LiteralPath $selectedPath -ErrorAction Stop
$info = $item.VersionInfo
[ordered]@{
  fileName = [string]$item.Name
  productName = [string]$info.ProductName
  fileDescription = [string]$info.FileDescription
  companyName = [string]$info.CompanyName
  productVersion = [string]$info.ProductVersion
  fileVersion = [string]$info.FileVersion
  originalFilename = [string]$info.OriginalFilename
} | ConvertTo-Json -Compress
''';

  Future<ExeMetadata> inspect(String sourcePath) async {
    if (!Platform.isWindows) {
      throw const FileSystemException(
        'EXE metadata import is available only in the Windows application.',
      );
    }

    final path = sourcePath.trim();
    if (path.isEmpty || !path.toLowerCase().endsWith('.exe')) {
      throw const FormatException('Select a Windows .exe file.');
    }

    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('The selected EXE file was not found.');
    }
    if (await file.length() == 0) {
      throw const FileSystemException('The selected EXE file is empty.');
    }

    final result = await Process.run(
      'powershell.exe',
      const [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        _powershellScript,
      ],
      environment: {'SYSWATCH_EXE_INSPECTION_PATH': path},
      includeParentEnvironment: true,
      runInShell: false,
      stdoutEncoding: utf8,
    );

    if (result.exitCode != 0) {
      final message = result.stderr.toString().trim();
      throw FileSystemException(
        message.isEmpty
            ? 'Windows could not read metadata from this EXE.'
            : 'Windows could not read this EXE: $message',
        path,
      );
    }

    final output = result.stdout.toString().trim();
    final jsonStart = output.indexOf('{');
    if (jsonStart < 0) {
      throw FileSystemException(
        'The EXE does not contain readable Windows version information.',
        path,
      );
    }

    final decoded = jsonDecode(output.substring(jsonStart));
    if (decoded is! Map) {
      throw FileSystemException('Invalid EXE metadata was returned.', path);
    }

    String read(String key) => (decoded[key] ?? '').toString().trim();
    final fileName = read('fileName').isNotEmpty
        ? read('fileName')
        : path.replaceAll('\\', '/').split('/').last;

    return ExeMetadata(
      path: path,
      fileName: fileName,
      productName: read('productName'),
      fileDescription: read('fileDescription'),
      publisher: read('companyName'),
      productVersion: read('productVersion'),
      fileVersion: read('fileVersion'),
      originalFileName: read('originalFilename'),
    );
  }
}
