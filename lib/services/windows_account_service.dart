import 'dart:convert';
import 'dart:io';

import '../models/windows_account_info.dart';

/// Reads the identity of the Windows account that has already signed in.
///
/// Syswatch does not validate the user against the Syswatch users table and it
/// never reads the user's Windows password, PIN, Windows Hello secret, or token.
/// It only reads non-secret identity information exposed to the current Windows
/// session.
class WindowsAccountService {
  WindowsAccountService._();

  static final WindowsAccountService instance = WindowsAccountService._();

  Future<WindowsAccountInfo> getCurrentAccount() async {
    if (!Platform.isWindows) {
      final username = Platform.environment['USER']?.trim() ?? 'unknown';
      final host = Platform.localHostname.trim();
      return WindowsAccountInfo(
        username: username,
        domain: '',
        upn: '',
        sid: '',
        computerName: host,
        qualifiedName: username,
        displayName: username,
        accountEmail: '',
        accountType: 'other',
      );
    }

    final envUsername = Platform.environment['USERNAME']?.trim() ?? '';
    final envDomain = Platform.environment['USERDOMAIN']?.trim() ?? '';
    final computerName =
        (Platform.environment['COMPUTERNAME']?.trim().isNotEmpty ?? false)
            ? Platform.environment['COMPUTERNAME']!.trim()
            : Platform.localHostname.trim();

    String qualifiedName = '';
    String upn = '';
    String sid = '';

    // Raw Windows security identity, e.g. DESKTOP-ABC\user or NUCLARK\student.
    qualifiedName = await _runText(
      'whoami.exe',
      const [],
      timeout: const Duration(seconds: 3),
    );

    // Real UPN for domain / Microsoft Entra / work-or-school sign-ins.
    final upnResult = await _runText(
      'whoami.exe',
      const ['/upn'],
      timeout: const Duration(seconds: 3),
    );
    if (_looksLikeEmail(upnResult) && !_looksLikeWhoamiError(upnResult)) {
      upn = upnResult;
    }

    // Stable Windows security identifier.
    try {
      final result = await Process.run(
        'whoami.exe',
        const ['/user', '/fo', 'csv', '/nh'],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        final match = RegExp(r'"[^"]*","([^"]+)"').firstMatch(output);
        if (match != null) sid = match.group(1)?.trim() ?? '';
      }
    } catch (_) {}

    var username = envUsername;
    if (username.isEmpty) {
      username = _usernameFromQualifiedName(qualifiedName);
    }

    var domain = envDomain;
    if (domain.isEmpty) {
      domain = _domainFromQualifiedName(qualifiedName);
    }

    if (qualifiedName.isEmpty) {
      qualifiedName = domain.isNotEmpty
          ? '$domain\\$username'
          : username;
    }

    // A local Windows security account may still be linked to a Microsoft
    // account. Read the friendly account identity visible to the current user.
    final friendly = await _readFriendlyWindowsIdentity(username: username);

    // Windows Shell keeps the same friendly name shown on the sign-in / Start
    // account UI in LogonUI. This is especially useful when the security token
    // is still a local DESKTOP\\user account that is linked to Microsoft.
    final logonUi = await _readLogonUiIdentity(
      qualifiedName: qualifiedName,
      username: username,
    );

    // IdentityStore is another Windows cache used by Microsoft/Entra sign-in.
    // It commonly contains DisplayName + IdentityName (email/UPN).
    final identityCache = await _readIdentityStoreIdentity(
      preferredDisplayName: logonUi.displayName,
      preferredEmail: logonUi.email,
      qualifiedName: qualifiedName,
      username: username,
    );

    String accountEmail = '';
    String accountType = 'windows_local';

    // A real work/school UPN always wins over consumer-account fallbacks.
    if (_looksLikeEmail(upn)) {
      accountEmail = upn;
      accountType = 'work_school';
    } else if (_looksLikeEmail(friendly.email)) {
      accountEmail = friendly.email;
      accountType = friendly.source;
    } else if (_looksLikeEmail(logonUi.email)) {
      accountEmail = logonUi.email;
      accountType = 'windows_logon_ui';
    } else if (_looksLikeEmail(identityCache.email)) {
      accountEmail = identityCache.email;
      accountType = 'windows_identity_store';
    }

    var displayName = friendly.displayName.trim();
    if (displayName.isEmpty ||
        displayName.toLowerCase() == username.toLowerCase() ||
        displayName.toLowerCase() == qualifiedName.toLowerCase()) {
      // A friendly Microsoft/Office profile name is preferred when available.
      final candidate = friendly.profileDisplayName.trim();
      if (candidate.isNotEmpty) displayName = candidate;
    }

    if (!_looksLikeFriendlyDisplayName(
      displayName,
      username: username,
      qualifiedName: qualifiedName,
    )) {
      final candidate = logonUi.displayName.trim();
      if (_looksLikeFriendlyDisplayName(
        candidate,
        username: username,
        qualifiedName: qualifiedName,
      )) {
        displayName = candidate;
      }
    }

    if (!_looksLikeFriendlyDisplayName(
      displayName,
      username: username,
      qualifiedName: qualifiedName,
    )) {
      final candidate = identityCache.displayName.trim();
      if (_looksLikeFriendlyDisplayName(
        candidate,
        username: username,
        qualifiedName: qualifiedName,
      )) {
        displayName = candidate;
      }
    }

    if (!_looksLikeFriendlyDisplayName(
      displayName,
      username: username,
      qualifiedName: qualifiedName,
    )) {
      displayName = await _readFullNameWithNetUser(username);
    }

    if (displayName.isEmpty) {
      displayName = accountEmail.isNotEmpty
          ? accountEmail
          : qualifiedName;
    }

    if (username.isEmpty &&
        qualifiedName.isEmpty &&
        accountEmail.isEmpty) {
      throw Exception('Syswatch could not read the current Windows account.');
    }

    return WindowsAccountInfo(
      username: username.isEmpty ? qualifiedName : username,
      domain: domain,
      upn: upn,
      sid: sid,
      computerName: computerName,
      qualifiedName: qualifiedName,
      displayName: displayName,
      accountEmail: accountEmail,
      accountType: accountType,
    );
  }

  Future<_FriendlyWindowsIdentity> _readFriendlyWindowsIdentity({
    required String username,
  }) async {
    const script = r'''
$ErrorActionPreference = 'SilentlyContinue'

$result = [ordered]@{
  displayName = ''
  profileDisplayName = ''
  email = ''
  source = 'windows_local'
}

function Test-Email([string]$value) {
  if ([string]::IsNullOrWhiteSpace($value)) { return $false }
  return $value.Trim() -match '^[^@\s]+@[^@\s]+\.[^@\s]+$'
}

function Test-FriendlyName([string]$value) {
  if ([string]::IsNullOrWhiteSpace($value)) { return $false }
  $v = $value.Trim()
  if (Test-Email $v) { return $false }
  if ($v -match '\\') { return $false }
  if ($v -ieq $env:USERNAME) { return $false }
  if ($v -ieq "$env:USERDOMAIN\$env:USERNAME") { return $false }
  if ($v.Length -lt 2) { return $false }
  return $true
}

function Use-Identity(
  [string]$email,
  [string]$displayName,
  [string]$source
) {
  if ([string]::IsNullOrWhiteSpace([string]$result.email) -and (Test-Email $email)) {
    $result.email = $email.Trim()
    $result.source = $source
  }

  if ([string]::IsNullOrWhiteSpace([string]$result.profileDisplayName) -and
      (Test-FriendlyName $displayName)) {
    $result.profileDisplayName = $displayName.Trim()
  }
}

function Name-FromProperties($props) {
  if ($null -eq $props) { return '' }

  foreach ($name in @(
    'DisplayName',
    'FriendlyName',
    'FullName',
    'AccountDisplayName',
    'UserDisplayName',
    'Name'
  )) {
    try {
      $candidate = [string]$props.$name
      if (Test-FriendlyName $candidate) {
        return $candidate.Trim()
      }
    } catch {}
  }

  $first = ''
  $last = ''

  foreach ($name in @('FirstName','GivenName','First')) {
    try {
      $candidate = [string]$props.$name
      if (-not [string]::IsNullOrWhiteSpace($candidate)) {
        $first = $candidate.Trim()
        break
      }
    } catch {}
  }

  foreach ($name in @('LastName','FamilyName','Surname','Last')) {
    try {
      $candidate = [string]$props.$name
      if (-not [string]::IsNullOrWhiteSpace($candidate)) {
        $last = $candidate.Trim()
        break
      }
    } catch {}
  }

  $combined = "$first $last".Trim()
  if (Test-FriendlyName $combined) {
    return $combined
  }

  return ''
}

function Email-FromProperties($props, [string]$keyName) {
  if (Test-Email $keyName) {
    return $keyName.Trim()
  }

  if ($null -eq $props) { return '' }

  foreach ($name in @(
    'EmailAddress',
    'Email',
    'UserEmail',
    'UserName',
    'Username',
    'AccountName',
    'PrincipalName',
    'UPN'
  )) {
    try {
      $candidate = [string]$props.$name
      if (Test-Email $candidate) {
        return $candidate.Trim()
      }
    } catch {}
  }

  return ''
}

# 0. Try the local Windows account object first. On many Microsoft-linked local
#    profiles, FullName already contains the friendly account name.
try {
  $local = Get-LocalUser -Name $env:USERNAME -ErrorAction SilentlyContinue
  if ($local -and (Test-FriendlyName ([string]$local.FullName))) {
    $result.displayName = ([string]$local.FullName).Trim()
  }
} catch {}

# 1. CIM/ADSI friendly Windows account name.
if ([string]::IsNullOrWhiteSpace([string]$result.displayName)) {
  try {
    $u = ([string]$env:USERNAME).Replace("'", "''")
    $d = ([string]$env:USERDOMAIN).Replace("'", "''")
    $account = Get-CimInstance Win32_UserAccount -Filter "Name='$u' AND Domain='$d'" |
      Select-Object -First 1

    if (-not $account) {
      $account = Get-CimInstance Win32_UserAccount -Filter "Name='$u'" |
        Select-Object -First 1
    }

    if ($account -and (Test-FriendlyName ([string]$account.FullName))) {
      $result.displayName = ([string]$account.FullName).Trim()
    }
  } catch {}
}

if ([string]::IsNullOrWhiteSpace([string]$result.displayName)) {
  try {
    $adsi = [ADSI]("WinNT://$env:COMPUTERNAME/$env:USERNAME,user")
    $fullName = [string]$adsi.FullName.Value

    if (Test-FriendlyName $fullName) {
      $result.displayName = $fullName.Trim()
    }
  } catch {}
}

# 2. Windows Runtime current-user profile. This can expose the same friendly
#    name that Windows shows in the Start/account flyout.
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction SilentlyContinue

  $userInfoType = [Windows.System.UserProfile.UserInformation,Windows.System.UserProfile,ContentType=WindowsRuntime]

  function Await-WinRTString($operation) {
    if ($null -eq $operation) { return '' }

    try {
      $method = [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
          $_.Name -eq 'AsTask' -and
          $_.IsGenericMethodDefinition -and
          $_.GetParameters().Count -eq 1 -and
          $_.GetParameters()[0].ParameterType.Name -like 'IAsyncOperation*'
        } |
        Select-Object -First 1

      if ($null -eq $method) { return '' }

      $generic = $method.MakeGenericMethod([string])
      $task = $generic.Invoke($null, @($operation))

      if ($task.Wait(2500)) {
        return ([string]$task.Result).Trim()
      }
    } catch {}

    return ''
  }

  if ([string]::IsNullOrWhiteSpace([string]$result.profileDisplayName)) {
    $winrtName = Await-WinRTString ($userInfoType::GetDisplayNameAsync())
    if (Test-FriendlyName $winrtName) {
      $result.profileDisplayName = $winrtName.Trim()
    }
  }

  if ([string]::IsNullOrWhiteSpace([string]$result.email)) {
    $principal = Await-WinRTString ($userInfoType::GetPrincipalNameAsync())
    if (Test-Email $principal) {
      $result.email = $principal.Trim()
      $result.source = 'windows_profile'
    }
  }
} catch {}

# 3. IdentityCRL is Windows' cached Microsoft-account identity. Search
#    recursively because newer Windows builds sometimes store useful properties
#    under nested child keys.
foreach ($root in @(
  'HKCU:\Software\Microsoft\IdentityCRL\StoredIdentities',
  'HKCU:\Software\Microsoft\IdentityCRL\UserExtendedProperties'
)) {
  try {
    if (Test-Path $root) {
      $items = @()
      $items += Get-Item -Path $root -ErrorAction SilentlyContinue
      $items += Get-ChildItem -Path $root -Recurse -ErrorAction SilentlyContinue

      foreach ($item in $items) {
        $props = Get-ItemProperty -Path $item.PSPath -ErrorAction SilentlyContinue
        $email = Email-FromProperties $props ([string]$item.PSChildName)
        $nameValue = Name-FromProperties $props

        Use-Identity $email $nameValue 'microsoft'

        if (-not [string]::IsNullOrWhiteSpace([string]$result.email) -and
            -not [string]::IsNullOrWhiteSpace([string]$result.profileDisplayName)) {
          break
        }
      }
    }
  } catch {}
}

# 4. OneDrive stores UserEmail and UserName for Microsoft and work/school
#    accounts. UserName is commonly the friendly account display name.
try {
  $root = 'HKCU:\Software\Microsoft\OneDrive\Accounts'
  if (Test-Path $root) {
    foreach ($item in Get-ChildItem -Path $root -ErrorAction SilentlyContinue) {
      $props = Get-ItemProperty -Path $item.PSPath -ErrorAction SilentlyContinue
      $email = ''

      foreach ($field in @('UserEmail','Email','EmailAddress')) {
        try {
          $candidate = [string]$props.$field
          if (Test-Email $candidate) {
            $email = $candidate.Trim()
            break
          }
        } catch {}
      }

      $nameValue = ''
      foreach ($field in @('UserName','DisplayName','FriendlyName')) {
        try {
          $candidate = [string]$props.$field
          if (Test-FriendlyName $candidate) {
            $nameValue = $candidate.Trim()
            break
          }
        } catch {}
      }

      Use-Identity $email $nameValue 'onedrive'

      if (-not [string]::IsNullOrWhiteSpace([string]$result.email) -and
          -not [string]::IsNullOrWhiteSpace([string]$result.profileDisplayName)) {
        break
      }
    }
  }
} catch {}

# 5. Microsoft Office/M365 connected identity. Search recursively so it works
#    with both consumer and organizational identity layouts.
try {
  $root = 'HKCU:\Software\Microsoft\Office\16.0\Common\Identity\Identities'
  if (Test-Path $root) {
    $items = @()
    $items += Get-Item -Path $root -ErrorAction SilentlyContinue
    $items += Get-ChildItem -Path $root -Recurse -ErrorAction SilentlyContinue

    foreach ($item in $items) {
      $props = Get-ItemProperty -Path $item.PSPath -ErrorAction SilentlyContinue
      $email = Email-FromProperties $props ([string]$item.PSChildName)
      $nameValue = Name-FromProperties $props

      Use-Identity $email $nameValue 'microsoft_connected'

      if (-not [string]::IsNullOrWhiteSpace([string]$result.email) -and
          -not [string]::IsNullOrWhiteSpace([string]$result.profileDisplayName)) {
        break
      }
    }
  }
} catch {}

# If the local account FullName was empty but a Microsoft/OneDrive/Office
# friendly name was found, use it as the display name too.
if ([string]::IsNullOrWhiteSpace([string]$result.displayName) -and
    (Test-FriendlyName ([string]$result.profileDisplayName))) {
  $result.displayName = ([string]$result.profileDisplayName).Trim()
}

$result | ConvertTo-Json -Compress
''';

    String displayName = '';
    String profileDisplayName = '';
    String email = '';
    String source = 'windows_local';

    try {
      final result = await Process.run(
        'powershell.exe',
        const [
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          script,
        ],
        runInShell: false,
      ).timeout(const Duration(seconds: 8));

      if (result.exitCode == 0) {
        final raw = result.stdout.toString().trim();
        if (raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            displayName = decoded['displayName']?.toString().trim() ?? '';
            profileDisplayName =
                decoded['profileDisplayName']?.toString().trim() ?? '';
            email = decoded['email']?.toString().trim() ?? '';
            source = decoded['source']?.toString().trim() ?? 'windows_local';
          }
        }
      }
    } catch (_) {}

    // Direct registry fallback if PowerShell is restricted.
    if (!_looksLikeEmail(email)) {
      email = await _readEmailWithRegExe();
      if (_looksLikeEmail(email)) source = 'microsoft';
    }

    return _FriendlyWindowsIdentity(
      displayName: displayName,
      profileDisplayName: profileDisplayName,
      email: email,
      source: source,
    );
  }

  Future<String> _readEmailWithRegExe() async {
    const roots = <String>[
      r'HKCU\Software\Microsoft\IdentityCRL\StoredIdentities',
      r'HKCU\Software\Microsoft\IdentityCRL\UserExtendedProperties',
      r'HKCU\Software\Microsoft\Office\16.0\Common\Identity\Identities',
    ];

    for (final root in roots) {
      try {
        final result = await Process.run(
          'reg.exe',
          ['query', root, '/s'],
          runInShell: false,
        ).timeout(const Duration(seconds: 4));
        if (result.exitCode != 0) continue;

        final matches = RegExp(
          r'([A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,})',
          caseSensitive: false,
        ).allMatches(result.stdout.toString());

        for (final match in matches) {
          final candidate = match.group(1)?.trim() ?? '';
          if (_looksLikeEmail(candidate)) return candidate;
        }
      } catch (_) {}
    }

    return '';
  }


  Future<_ShellWindowsIdentity> _readLogonUiIdentity({
    required String qualifiedName,
    required String username,
  }) async {
    String displayName = '';
    String email = '';

    // First use the exact values Windows keeps for the most recently logged-on
    // interactive user. These values drive the same friendly identity shown by
    // Windows in several shell/sign-in surfaces.
    final rootOutput = await _runRegQuery(
      r'HKLM\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI',
    );

    displayName = _registryStringValue(
      rootOutput,
      const ['LastLoggedOnDisplayName'],
    );

    final lastUser = _registryStringValue(
      rootOutput,
      const ['LastLoggedOnUser', 'LastLoggedOnSAMUser'],
    );
    email = _firstEmail(lastUser);

    // SessionData may be fresher than the root values. Prefer a block matching
    // the currently running Windows security identity when possible.
    final sessionOutput = await _runRegQuery(
      r'HKLM\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\SessionData',
    );
    if (sessionOutput.isNotEmpty) {
      final blocks = _registryBlocks(sessionOutput);
      var bestScore = -1;
      for (final block in blocks) {
        final blockUser = _registryStringValue(
          block,
          const ['LoggedOnUser', 'LoggedOnSAMUser', 'UserName'],
        );
        final blockName = _registryStringValue(
          block,
          const ['LoggedOnDisplayName', 'DisplayName'],
        );
        final blockEmail = _firstEmail(blockUser);
        final lower = block.toLowerCase();
        var score = 0;
        if (qualifiedName.isNotEmpty &&
            lower.contains(qualifiedName.toLowerCase())) score += 8;
        if (username.isNotEmpty &&
            lower.contains(username.toLowerCase())) score += 3;
        if (_looksLikeFriendlyDisplayName(
          blockName,
          username: username,
          qualifiedName: qualifiedName,
        )) score += 2;
        if (_looksLikeEmail(blockEmail)) score += 1;

        if (score > bestScore) {
          bestScore = score;
          if (_looksLikeFriendlyDisplayName(
            blockName,
            username: username,
            qualifiedName: qualifiedName,
          )) {
            displayName = blockName;
          }
          if (_looksLikeEmail(blockEmail)) email = blockEmail;
        }
      }
    }

    // A Microsoft account email is often cached for the current HKCU profile.
    if (!_looksLikeEmail(email)) {
      for (final root in const <String>[
        r'HKCU\Software\Microsoft\IdentityCRL\UserExtendedProperties',
        r'HKCU\Software\Microsoft\IdentityCRL\StoredIdentities',
      ]) {
        final output = await _runRegQuery(root);
        final candidate = _firstEmail(output);
        if (_looksLikeEmail(candidate)) {
          email = candidate;
          break;
        }
      }
    }

    return _ShellWindowsIdentity(displayName: displayName, email: email);
  }

  Future<_ShellWindowsIdentity> _readIdentityStoreIdentity({
    required String preferredDisplayName,
    required String preferredEmail,
    required String qualifiedName,
    required String username,
  }) async {
    var bestName = '';
    var bestEmail = '';
    var bestScore = -1;

    for (final root in const <String>[
      r'HKLM\Software\Microsoft\IdentityStore\LogonCache',
      r'HKLM\Software\Microsoft\IdentityStore\Cache',
    ]) {
      final output = await _runRegQuery(root);
      if (output.isEmpty) continue;

      for (final block in _registryBlocks(output)) {
        final name = _registryStringValue(
          block,
          const ['DisplayName', 'FriendlyName', 'FullName'],
        );
        var identity = _registryStringValue(
          block,
          const ['IdentityName', 'UserName', 'Username', 'EmailAddress'],
        );
        if (!_looksLikeEmail(identity)) identity = _firstEmail(block);

        final lower = block.toLowerCase();
        var score = 0;
        if (preferredDisplayName.isNotEmpty &&
            name.toLowerCase() == preferredDisplayName.toLowerCase()) score += 12;
        if (_looksLikeEmail(preferredEmail) &&
            identity.toLowerCase() == preferredEmail.toLowerCase()) score += 12;
        if (qualifiedName.isNotEmpty &&
            lower.contains(qualifiedName.toLowerCase())) score += 7;
        if (username.isNotEmpty &&
            lower.contains(username.toLowerCase())) score += 2;
        if (_looksLikeFriendlyDisplayName(
          name,
          username: username,
          qualifiedName: qualifiedName,
        )) score += 2;
        if (_looksLikeEmail(identity)) score += 1;

        if (score > bestScore) {
          bestScore = score;
          if (_looksLikeFriendlyDisplayName(
            name,
            username: username,
            qualifiedName: qualifiedName,
          )) bestName = name;
          if (_looksLikeEmail(identity)) bestEmail = identity;
        }
      }
    }

    return _ShellWindowsIdentity(displayName: bestName, email: bestEmail);
  }

  Future<String> _runRegQuery(String root) async {
    try {
      final result = await Process.run(
        'reg.exe',
        ['query', root, '/s'],
        runInShell: false,
      ).timeout(const Duration(seconds: 5));
      if (result.exitCode == 0) return result.stdout.toString();
    } catch (_) {}
    return '';
  }

  List<String> _registryBlocks(String output) {
    final blocks = <String>[];
    final current = <String>[];
    for (final line in output.split(RegExp(r'\r?\n'))) {
      if (line.trimLeft().toUpperCase().startsWith('HKEY_')) {
        if (current.isNotEmpty) {
          blocks.add(current.join('\n'));
          current.clear();
        }
      }
      current.add(line);
    }
    if (current.isNotEmpty) blocks.add(current.join('\n'));
    return blocks;
  }

  String _registryStringValue(String text, List<String> names) {
    for (final name in names) {
      final match = RegExp(
        '^\\s*${RegExp.escape(name)}\\s+REG_(?:SZ|EXPAND_SZ)\\s+(.+?)\\s*\$',
        caseSensitive: false,
        multiLine: true,
      ).firstMatch(text);
      final value = match?.group(1)?.trim() ?? '';
      if (value.isNotEmpty && value != '(value not set)') return value;
    }
    return '';
  }

  String _firstEmail(String text) {
    final match = RegExp(
      r'([A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,})',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }

  bool _looksLikeFriendlyDisplayName(
    String value, {
    required String username,
    required String qualifiedName,
  }) {
    final text = value.trim();
    if (text.isEmpty || text.length < 2) return false;
    if (_looksLikeEmail(text) || text.contains('\\')) return false;
    if (text.toLowerCase() == username.trim().toLowerCase()) return false;
    if (text.toLowerCase() == qualifiedName.trim().toLowerCase()) return false;
    if (text.toLowerCase() == 'windows user') return false;
    return true;
  }

  Future<String> _readFullNameWithNetUser(String username) async {
    if (username.trim().isEmpty) return '';
    try {
      final result = await Process.run(
        'net.exe',
        ['user', username],
        runInShell: false,
      ).timeout(const Duration(seconds: 4));
      if (result.exitCode != 0) return '';

      for (final line in result.stdout.toString().split(RegExp(r'\r?\n'))) {
        final match = RegExp(
          r'^\s*Full Name\s+(.+?)\s*$',
          caseSensitive: false,
        ).firstMatch(line);
        if (match != null) {
          final value = match.group(1)?.trim() ?? '';
          if (value.isNotEmpty) return value;
        }
      }
    } catch (_) {}
    return '';
  }

  Future<String> _runText(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        runInShell: false,
      ).timeout(timeout);
      if (result.exitCode == 0) return result.stdout.toString().trim();
    } catch (_) {}
    return '';
  }

  bool _looksLikeWhoamiError(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.contains('error') ||
        normalized.contains('unable') ||
        normalized.contains('not available');
  }

  static bool _looksLikeEmail(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.contains(' ')) return false;
    final at = normalized.indexOf('@');
    if (at <= 0 || at >= normalized.length - 3) return false;
    return normalized.substring(at + 1).contains('.');
  }

  String _usernameFromQualifiedName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '';
    final slash = normalized.lastIndexOf('\\');
    if (slash >= 0 && slash < normalized.length - 1) {
      return normalized.substring(slash + 1);
    }
    final at = normalized.indexOf('@');
    if (at > 0) return normalized.substring(0, at);
    return normalized;
  }

  String _domainFromQualifiedName(String value) {
    final normalized = value.trim();
    final slash = normalized.indexOf('\\');
    if (slash > 0) return normalized.substring(0, slash);
    return '';
  }
}


class _ShellWindowsIdentity {
  final String displayName;
  final String email;

  const _ShellWindowsIdentity({
    required this.displayName,
    required this.email,
  });
}

class _FriendlyWindowsIdentity {
  final String displayName;
  final String profileDisplayName;
  final String email;
  final String source;

  const _FriendlyWindowsIdentity({
    required this.displayName,
    required this.profileDisplayName,
    required this.email,
    required this.source,
  });
}
