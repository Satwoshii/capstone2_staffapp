import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_config_service.dart';
import 'server_discovery_service.dart';

class ApiUnavailableException implements Exception {
  final String message;

  const ApiUnavailableException(this.message);

  @override
  String toString() => message;
}

class ApiRequestException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? response;

  const ApiRequestException({
    required this.statusCode,
    required this.message,
    this.code,
    this.response,
  });

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const Duration _connectTimeout = Duration(seconds: 5);
  static const Duration _requestTimeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> getJson(
    String endpoint, {
    Map<String, String>? query,
    bool authenticated = true,
  }) {
    return _request(
      method: 'GET',
      endpoint: endpoint,
      query: query,
      authenticated: authenticated,
    );
  }

  Future<Map<String, dynamic>> postJson(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) {
    return _request(
      method: 'POST',
      endpoint: endpoint,
      body: body ?? const <String, dynamic>{},
      authenticated: authenticated,
    );
  }

  Future<Map<String, dynamic>> postMultipartFile(
    String endpoint, {
    required String fileField,
    required File file,
    Map<String, String>? fields,
    bool authenticated = true,
  }) async {
    final uri = _buildUri(AppConfigService.instance.serverUrl, endpoint, null);
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final request = await client.postUrl(uri).timeout(_connectTimeout);
      final boundary = '----syswatch${DateTime.now().microsecondsSinceEpoch}';
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');
      request.headers.set('X-Syswatch-Client', 'staff-app');
      if (authenticated) {
        final token = AppConfigService.instance.apiToken;
        if (token.isEmpty) {
          throw const ApiRequestException(statusCode: 401, code: 'missing_local_session', message: 'Sign in again to continue.');
        }
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        request.headers.set('X-Syswatch-User-Token', token);
      }
      for (final entry in (fields ?? const <String, String>{}).entries) {
        request.write('--$boundary\r\n');
        request.write('Content-Disposition: form-data; name=\"${entry.key}\"\r\n\r\n');
        request.write('${entry.value}\r\n');
      }
      final name = file.uri.pathSegments.isEmpty ? 'image.jpg' : file.uri.pathSegments.last;
      final mime = name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      request.write('--$boundary\r\n');
      request.write('Content-Disposition: form-data; name=\"$fileField\"; filename=\"$name\"\r\n');
      request.write('Content-Type: $mime\r\n\r\n');
      await request.addStream(file.openRead());
      request.write('\r\n--$boundary--\r\n');
      final response = await request.close().timeout(_requestTimeout);
      final raw = await utf8.decoder.bind(response).join();
      final decoded = _decodeResponse(raw);
      if (response.statusCode < 200 || response.statusCode >= 300 || decoded['success'] == false) {
        throw ApiRequestException(
          statusCode: response.statusCode,
          message: _messageFromResponse(decoded, fallback: 'Upload failed (HTTP ${response.statusCode}).'),
          code: decoded['code']?.toString(), response: decoded,
        );
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<File> downloadToDownloads(
    String endpoint, {
    Map<String, String>? query,
    required String fallbackFileName,
  }) async {
    final uri = _buildUri(AppConfigService.instance.serverUrl, endpoint, query);
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final request = await client.getUrl(uri).timeout(_connectTimeout);
      final token = AppConfigService.instance.apiToken;
      if (token.isEmpty) throw const ApiRequestException(statusCode: 401, message: 'Sign in again to continue.');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set('X-Syswatch-User-Token', token);
      request.headers.set('X-Syswatch-Client', 'staff-app');
      final response = await request.close().timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final raw = await utf8.decoder.bind(response).join();
        Map<String, dynamic> decoded = <String, dynamic>{};
        try { decoded = _decodeResponse(raw); } catch (_) {}
        throw ApiRequestException(statusCode: response.statusCode, message: _messageFromResponse(decoded, fallback: 'Export failed (HTTP ${response.statusCode}).'));
      }
      var fileName = fallbackFileName;
      final disposition = response.headers.value('content-disposition') ?? '';
      final match = RegExp(r'filename=\"?([^\";]+)').firstMatch(disposition);
      if (match != null && match.group(1)!.trim().isNotEmpty) fileName = match.group(1)!.trim();
      final userProfile = Platform.environment['USERPROFILE'] ?? Directory.current.path;
      final downloads = Directory('$userProfile${Platform.pathSeparator}Downloads');
      await downloads.create(recursive: true);
      final file = File('${downloads.path}${Platform.pathSeparator}$fileName');
      final sink = file.openWrite();
      await response.pipe(sink);
      return file;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    required bool authenticated,
    bool allowRediscovery = true,
  }) async {
    final uri = _buildUri(
      AppConfigService.instance.serverUrl,
      endpoint,
      query,
    );
    final client = HttpClient()..connectionTimeout = _connectTimeout;

    try {
      final request = await client.openUrl(method, uri).timeout(_connectTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('X-Syswatch-Client', 'staff-app');

      if (authenticated) {
        final token = AppConfigService.instance.apiToken;
        if (token.isEmpty) {
          throw const ApiRequestException(
            statusCode: 401,
            code: 'missing_local_session',
            message: 'Sign in again to continue.',
          );
        }
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        // Apache/PHP on some XAMPP installations does not expose the
        // Authorization header to PHP. Send a dedicated intranet fallback too.
        request.headers.set('X-Syswatch-User-Token', token);
      }

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(_requestTimeout);
      final rawBody = await utf8.decoder.bind(response).join();
      Map<String, dynamic> decoded;
      try {
        decoded = _decodeResponse(rawBody);
      } on FormatException {
        if (_looksLikeHtml(rawBody)) {
          throw ApiRequestException(
            statusCode: response.statusCode,
            code: 'html_response',
            message: _htmlResponseMessage(
              endpoint: endpoint,
              statusCode: response.statusCode,
            ),
          );
        }
        rethrow;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiRequestException(
          statusCode: response.statusCode,
          message: _messageFromResponse(
            decoded,
            fallback: 'The Syswatch server returned HTTP '
                '${response.statusCode}.',
          ),
          code: decoded['code']?.toString(),
          response: decoded,
        );
      }

      if (decoded['success'] == false) {
        throw ApiRequestException(
          statusCode: response.statusCode,
          message: _messageFromResponse(
            decoded,
            fallback: 'The Syswatch server rejected the request.',
          ),
          code: decoded['code']?.toString(),
          response: decoded,
        );
      }

      return decoded;
    } on ApiRequestException {
      rethrow;
    } on TimeoutException {
      if (allowRediscovery) {
        final found = await ServerDiscoveryService.instance.discover(
          forceLanScan: true,
        );
        if (found != null) {
          return _request(
            method: method,
            endpoint: endpoint,
            body: body,
            query: query,
            authenticated: authenticated,
            allowRediscovery: false,
          );
        }
      }
      throw const ApiUnavailableException(
        'The Syswatch intranet server did not respond in time.',
      );
    } on SocketException {
      if (allowRediscovery) {
        final found = await ServerDiscoveryService.instance.discover(
          forceLanScan: true,
        );
        if (found != null) {
          return _request(
            method: method,
            endpoint: endpoint,
            body: body,
            query: query,
            authenticated: authenticated,
            allowRediscovery: false,
          );
        }
      }
      throw const ApiUnavailableException(
        'The Syswatch intranet server is unreachable. Automatic LAN discovery '
        'could not find the server. Check Apache and Windows Firewall.',
      );
    } on HandshakeException {
      throw const ApiUnavailableException(
        'A secure connection to the Syswatch server could not be established.',
      );
    } on FormatException catch (error) {
      throw ApiRequestException(
        statusCode: 500,
        message: 'The Syswatch server returned invalid JSON: $error',
      );
    } finally {
      client.close(force: true);
    }
  }

  Uri _buildUri(
    String serverUrl,
    String endpoint,
    Map<String, String>? query,
  ) {
    final base = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    final path = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    final uri = Uri.parse('$base/$path');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  Map<String, dynamic> _decodeResponse(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return <String, dynamic>{'success': true};
    }
    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{'success': true, 'data': decoded};
  }

  bool _looksLikeHtml(String rawBody) {
    final text = rawBody.trimLeft().toLowerCase();
    return text.startsWith('<!doctype html') ||
        text.startsWith('<html') ||
        text.startsWith('<head') ||
        text.startsWith('<body');
  }

  String _htmlResponseMessage({
    required String endpoint,
    required int statusCode,
  }) {
    if (statusCode == 404) {
      final teacherChatEndpoint = endpoint.startsWith('teacher/chat_') ||
          endpoint.startsWith('chat/teacher_');
      if (teacherChatEndpoint) {
        return 'The API file was not found: $endpoint. Merge the Teacher Chat '
            'server files into C:\\xampp\\htdocs\\syswatch_api without '
            'creating a nested syswatch_api\\syswatch_api folder.';
      }
      return 'The core API file was not found: $endpoint. Restore the complete '
          'syswatch_api folder to C:\\xampp\\htdocs\\syswatch_api and keep '
          'your existing config\\database.php file.';
    }
    if (statusCode >= 500) {
      return 'The Syswatch server failed while running $endpoint (HTTP '
          '$statusCode). Import upgrade_teacher_chat_v2_8_1.sql, restart '
          'Apache, and check C:\\xampp\\apache\\logs\\error.log.';
    }
    return 'The server returned an HTML page instead of JSON for $endpoint '
        '(HTTP $statusCode). Check the API folder and configured server URL.';
  }

  String _messageFromResponse(
    Map<String, dynamic> response, {
    required String fallback,
  }) {
    for (final key in const ['message', 'error', 'detail']) {
      final value = response[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }
}
