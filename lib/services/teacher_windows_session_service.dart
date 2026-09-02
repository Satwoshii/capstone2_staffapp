import 'dart:async';
import 'dart:io';

import '../models/app_user.dart';
import '../models/windows_account_info.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'app_config_service.dart';
import 'server_discovery_service.dart';
import 'windows_account_service.dart';

/// Records the Windows session of a Teacher automatically.
///
/// Important: this service never reads a Windows password, PIN, Windows Hello
/// secret, or authentication token. It only reads non-secret identity details
/// exposed by the already signed-in Windows session.
///
/// Automatic session recording itself never trusts the Windows username as an
/// authentication factor. Automatic Teacher dashboard access is allowed only
/// after a prior successful Teacher Syswatch password login created a random
/// per-Windows-profile proof secret. Admin/Super Admin never use this path.
class TeacherWindowsSessionService {
  TeacherWindowsSessionService._();

  static final TeacherWindowsSessionService instance =
      TeacherWindowsSessionService._();

  Timer? _heartbeatTimer;
  Timer? _retryTimer;
  WindowsAccountInfo? _account;
  String _sessionId = '';
  String _sessionKey = '';
  bool _started = false;
  bool _recording = false;

  WindowsAccountInfo? get cachedAccount => _account;
  bool get hasRecordedTeacherSession =>
      _sessionId.isNotEmpty && _sessionKey.isNotEmpty;

  /// Starts automatic Teacher Windows-account recording in the background.
  ///
  /// If the Windows identity has not been linked to a Syswatch Teacher yet,
  /// this quietly retries. The first successful Teacher Syswatch login links
  /// the Windows identity so future Windows sign-ins can be recorded without
  /// waiting for the Teacher to type Syswatch credentials.
  Future<void> start() async {
    if (_started || !Platform.isWindows) return;
    _started = true;

    await _readAccountSafely();
    await _tryRecord();

    _retryTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_periodicWork()),
    );
  }

  Future<WindowsAccountInfo?> currentAccount() async {
    if (_account != null) return _account;
    await _readAccountSafely();
    return _account;
  }

  /// Attempts a secure automatic Teacher dashboard login for the current
  /// Windows profile. This requires BOTH the current Windows identity and the
  /// random auto-login secret created by a previous successful Teacher
  /// Syswatch password login on this Windows profile.
  ///
  /// Admin/Super Admin accounts never use this path. If there is no verified
  /// Teacher link, the method returns null and the normal Staff login screen is
  /// shown.
  Future<AppUser?> tryAutomaticTeacherLogin() async {
    if (!Platform.isWindows) return null;

    final secret = AppConfigService.instance.teacherAutoLoginSecret.trim();
    if (secret.isEmpty) return null;

    try {
      await _readAccountSafely(force: true);
      final body = windowsIdentityPayload();
      if (body == null) return null;

      await ServerDiscoveryService.instance.discover();

      final response = await ApiClient.instance.postJson(
        ApiEndpoints.teacherWindowsAutoLogin,
        authenticated: false,
        body: {
          ...body,
          'auto_login_secret': secret,
        },
      );

      if (response['matched'] != true) return null;
      final rawUser = response['user'];
      if (rawUser is! Map) return null;

      final user = AppUser.fromJson(
        rawUser.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (!user.active || !user.isTeacher) return null;

      final token = (response['api_token'] ?? '').toString().trim();
      if (token.isEmpty) return null;

      await AppConfigService.instance.saveSession(
        user: user,
        apiToken: token,
        expiresAt: response['token_expires_at']?.toString(),
      );

      final id = (response['session_id'] ?? '').toString().trim();
      final key = (response['session_key'] ?? '').toString().trim();
      if (id.isNotEmpty && key.isNotEmpty) {
        _sessionId = id;
        _sessionKey = key;
        _heartbeatTimer?.cancel();
        _heartbeatTimer = Timer.periodic(
          const Duration(seconds: 30),
          (_) => unawaited(_heartbeat()),
        );
      }

      if (!_started) {
        _started = true;
        _retryTimer = Timer.periodic(
          const Duration(minutes: 1),
          (_) => unawaited(_periodicWork()),
        );
      }

      return user;
    } on ApiRequestException catch (error) {
      // A revoked/rotated link should not lock the shared Staff application.
      // Remove the local proof and fall back to the normal Admin/Teacher login.
      if (error.statusCode == 401 ||
          error.code == 'teacher_auto_login_invalid' ||
          error.code == 'teacher_windows_not_linked') {
        await AppConfigService.instance.clearTeacherAutoLoginSecret();
      }
      return null;
    } catch (_) {
      // Offline or discovery failure: Staff/Admin login remains available.
      return null;
    }
  }

  /// Called after a successful Teacher Syswatch login. The server has now had
  /// a trusted opportunity to link this Windows identity to that Teacher, so
  /// retry the automatic Windows-session record immediately.
  Future<void> ensureRecordedAfterTeacherLogin() async {
    if (!Platform.isWindows) return;
    if (!_started) {
      _started = true;
      _retryTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(_periodicWork()),
      );
    }
    await _readAccountSafely(force: _account == null);
    await _tryRecord(force: true);
  }

  Future<void> _periodicWork() async {
    if (hasRecordedTeacherSession) {
      await _heartbeat();
    } else {
      await _tryRecord();
    }
  }

  Future<void> _readAccountSafely({bool force = false}) async {
    if (!force && _account != null) return;
    try {
      _account = await WindowsAccountService.instance.getCurrentAccount();
    } catch (_) {
      // Do not prevent the Admin/Teacher application from opening just because
      // Windows identity metadata could not be read on one attempt.
    }
  }

  Map<String, dynamic>? windowsIdentityPayload() {
    final account = _account;
    if (account == null) return null;
    return {
      'windows_username': account.username,
      'windows_domain': account.domain,
      'windows_upn': account.upn,
      'windows_sid': account.sid,
      'account_identifier': account.accountIdentifier,
      'windows_display_name': account.displayName,
      'computer_name': account.computerName,
    };
  }

  Future<void> _tryRecord({bool force = false}) async {
    if (_recording || (!force && hasRecordedTeacherSession)) return;
    _recording = true;
    try {
      await _readAccountSafely();
      final body = windowsIdentityPayload();
      if (body == null) return;

      // Use the same LAN auto-discovery as the rest of Syswatch. No server IP
      // is exposed to the Teacher UI.
      await ServerDiscoveryService.instance.discover();

      final response = await ApiClient.instance.postJson(
        ApiEndpoints.teacherWindowsRecord,
        authenticated: false,
        body: body,
      );

      if (response['matched'] != true) return;
      final id = (response['session_id'] ?? '').toString().trim();
      final key = (response['session_key'] ?? '').toString().trim();
      if (id.isEmpty || key.isEmpty) return;

      _sessionId = id;
      _sessionKey = key;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(_heartbeat()),
      );
    } on ApiRequestException catch (error) {
      // teacher_windows_not_linked is expected before the first trusted
      // Teacher login. All failures remain background-only and are retried.
      if (error.code == 'teacher_windows_not_linked' ||
          error.code == 'teacher_not_found') {
        return;
      }
    } catch (_) {
      // Offline LAN/server: retry automatically later.
    } finally {
      _recording = false;
    }
  }

  Future<void> _heartbeat() async {
    if (!hasRecordedTeacherSession) return;
    try {
      await ApiClient.instance.postJson(
        ApiEndpoints.teacherWindowsHeartbeat,
        authenticated: false,
        body: {
          'session_id': _sessionId,
          'session_key': _sessionKey,
        },
      );
    } on ApiRequestException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 404) {
        _sessionId = '';
        _sessionKey = '';
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;
      }
    } catch (_) {
      // A temporary LAN outage must not terminate the local application.
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _retryTimer?.cancel();
    _heartbeatTimer = null;
    _retryTimer = null;
  }
}
