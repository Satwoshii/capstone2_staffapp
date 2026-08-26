import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_user.dart';

class AppConfigService {
  AppConfigService._();

  static final AppConfigService instance = AppConfigService._();

  static const String defaultServerUrl = 'http://SYSWATCH-SERVER/syswatch_api';

  File? _file;
  Map<String, dynamic> _values = <String, dynamic>{};

  Future<void> init() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    _file = File('${directory.path}${Platform.pathSeparator}staff_config.json');

    if (await _file!.exists()) {
      final raw = await _file!.readAsString();
      if (raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _values = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      }
    }

    if ((_values['server_url'] ?? '').toString().trim().isEmpty) {
      _values['server_url'] = defaultServerUrl;
      await _save();
    }
  }

  String get serverUrl => normalizeServerUrl(
        (_values['server_url'] ?? defaultServerUrl).toString(),
      );

  String get apiToken => (_values['api_token'] ?? '').toString();

  DateTime? get tokenExpiresAt {
    final raw = (_values['token_expires_at'] ?? '').toString();
    return raw.isEmpty ? null : DateTime.tryParse(raw);
  }

  AppUser? get savedUser {
    final raw = _values['user'];
    if (raw is Map<String, dynamic>) return AppUser.fromJson(raw);
    if (raw is Map) {
      return AppUser.fromJson(
        raw.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return null;
  }

  bool get hasValidSession {
    if (apiToken.isEmpty || savedUser == null) return false;
    final expiry = tokenExpiresAt;
    return expiry == null || expiry.isAfter(DateTime.now().toUtc());
  }

  /// Saves an automatically discovered server address. This does not affect
  /// the current staff session; it only updates the intranet route.
  Future<void> saveDiscoveredServerUrl(String value) async {
    final normalized = normalizeServerUrl(value);
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return;
    }
    _values['server_url'] = normalized;
    await _save();
  }

  Future<void> saveServerUrl(String value) async {
    final normalized = normalizeServerUrl(value);
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const FormatException(
        'Enter a valid server address, such as '
        'http://192.168.1.10/syswatch_api.',
      );
    }
    _values['server_url'] = normalized;
    await _save();
  }

  Future<void> saveSession({
    required AppUser user,
    required String apiToken,
    required String? expiresAt,
  }) async {
    _values['user'] = user.toJson();
    _values['api_token'] = apiToken;
    _values['token_expires_at'] = expiresAt ?? '';
    await _save();
  }

  Future<void> clearSession() async {
    _values.remove('user');
    _values.remove('api_token');
    _values.remove('token_expires_at');
    await _save();
  }

  String normalizeServerUrl(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) {
      throw StateError('AppConfigService.init() must be called first.');
    }
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_values),
      flush: true,
    );
  }
}
