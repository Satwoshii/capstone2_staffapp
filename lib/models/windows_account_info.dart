class WindowsAccountInfo {
  final String username;
  final String domain;
  final String upn;
  final String sid;
  final String computerName;
  final String qualifiedName;

  /// Friendly name shown by Windows when it can be resolved, for example:
  /// "Sato Valerio".
  final String displayName;

  /// Useful account email/UPN shown by Syswatch, for example:
  /// "student@school.edu" or a Microsoft account email.
  final String accountEmail;

  /// One of: work_school, microsoft, windows_local, other.
  final String accountType;

  const WindowsAccountInfo({
    required this.username,
    required this.domain,
    required this.upn,
    required this.sid,
    required this.computerName,
    required this.qualifiedName,
    required this.displayName,
    required this.accountEmail,
    required this.accountType,
  });

  /// The identity Syswatch stores as the account/email field.
  /// Work/school UPN has first priority, then Microsoft account email,
  /// then the Windows security name as a safe fallback.
  String get accountIdentifier {
    if (upn.trim().isNotEmpty) return upn.trim();
    if (accountEmail.trim().isNotEmpty) return accountEmail.trim();
    if (qualifiedName.trim().isNotEmpty) return qualifiedName.trim();
    return username.trim();
  }

  /// Privacy-safe primary label used on the Syswatch UI.
  /// The database can retain the Windows identity for auditing, but the
  /// dashboard reveals only a friendly display name.
  String get displayLabel {
    final name = displayName.trim();
    if (name.isNotEmpty &&
        !name.contains('\\') &&
        !_looksLikeEmail(name)) {
      return name;
    }
    return 'Windows User';
  }

  /// Raw Windows security account such as DESKTOP-ABC\\user.
  String get securityIdentity {
    if (qualifiedName.trim().isNotEmpty) return qualifiedName.trim();
    if (domain.trim().isNotEmpty && username.trim().isNotEmpty) {
      return '${domain.trim()}\\${username.trim()}';
    }
    return username.trim();
  }

  bool get hasUsefulEmail => accountIdentifier.contains('@');


  static bool _looksLikeEmail(String value) {
    final text = value.trim();
    final at = text.indexOf('@');
    return at > 0 && at < text.length - 3 && text.substring(at + 1).contains('.');
  }
}
