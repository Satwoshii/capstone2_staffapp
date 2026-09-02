import 'dart:io';

class NativeImagePickerService {
  NativeImagePickerService._();
  static final NativeImagePickerService instance = NativeImagePickerService._();

  Future<File?> pickJpgOrPng() async {
    if (!Platform.isWindows) return null;
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = 'Select Syswatch proof image'
$dialog.Filter = 'Image files (*.jpg;*.jpeg;*.png)|*.jpg;*.jpeg;*.png'
$dialog.Multiselect = $false
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  [Console]::Out.Write($dialog.FileName)
}
''';
    final result = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', script],
    );
    if (result.exitCode != 0) return null;
    final path = result.stdout.toString().trim();
    if (path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final lower = path.toLowerCase();
    if (!(lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png'))) {
      return null;
    }
    if (await file.length() > 8 * 1024 * 1024) {
      throw Exception('Proof image must not exceed 8 MB.');
    }
    return file;
  }
}
