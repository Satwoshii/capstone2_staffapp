import 'dart:io';

/// Enables the shared Syswatch Staff/Teacher app to start automatically for the
/// current Windows profile after a verified Teacher has signed in once.
///
/// This allows the automatic Teacher Windows-session recorder to start shortly
/// after future Windows logins. It does not store any Windows credentials.
class TeacherStartupService {
  TeacherStartupService._();

  static final TeacherStartupService instance = TeacherStartupService._();

  Future<void> ensureEnabled() async {
    if (!Platform.isWindows) return;

    final executable = Platform.resolvedExecutable.trim();
    if (executable.isEmpty) return;

    try {
      await Process.run(
        'reg.exe',
        [
          'ADD',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
          '/v',
          'SyswatchTeacherSession',
          '/t',
          'REG_SZ',
          '/d',
          '"$executable"',
          '/f',
        ],
        runInShell: false,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Startup registration is helpful but must never block Teacher access.
    }
  }
}
