import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_config_service.dart';

/// Automatically locates the Syswatch XAMPP server on the local network.
///
/// Order:
/// 1. Last successful server URL.
/// 2. SYSWATCH-SERVER host name aliases.
/// 3. Local private IPv4 /24 subnet scan.
///
/// The detected URL is saved so normal API requests do not need a manual IP.
class ServerDiscoveryService {
  ServerDiscoveryService._();

  static final ServerDiscoveryService instance = ServerDiscoveryService._();

  static const Duration _knownHostTimeout = Duration(milliseconds: 900);
  static const Duration _scanTimeout = Duration(milliseconds: 420);
  static const int _batchSize = 36;
  static const Duration _lanScanCooldown = Duration(seconds: 45);

  DateTime? _lastLanScanAt;

  Future<String?> discover({
    bool scanLan = true,
    bool forceLanScan = false,
  }) async {
    final saved = AppConfigService.instance.serverUrl;

    final knownCandidates = <String>[
      saved,
      'http://SYSWATCH-SERVER/syswatch_api',
      'http://syswatch-server/syswatch_api',
      'http://SYSWATCHSERVER/syswatch_api',
      'http://syswatchserver/syswatch_api',
      'http://127.0.0.1/syswatch_api',
    ];

    final checked = <String>{};
    for (final candidate in knownCandidates) {
      final normalized = _normalizeCandidate(candidate);
      if (normalized.isEmpty || !checked.add(normalized)) continue;
      if (await _isSyswatchServer(normalized, timeout: _knownHostTimeout)) {
        await AppConfigService.instance.saveDiscoveredServerUrl(normalized);
        return normalized;
      }
    }

    if (!scanLan) return null;

    final now = DateTime.now();
    if (!forceLanScan &&
        _lastLanScanAt != null &&
        now.difference(_lastLanScanAt!) < _lanScanCooldown) {
      return null;
    }
    _lastLanScanAt = now;

    final subnets = await _localPrivateSubnets();
    for (final subnet in subnets) {
      final found = await _scanSubnet(subnet, checked);
      if (found != null) {
        await AppConfigService.instance.saveDiscoveredServerUrl(found);
        return found;
      }
    }

    return null;
  }

  Future<String?> _scanSubnet(String subnet, Set<String> checked) async {
    final candidates = <String>[];
    for (var host = 1; host <= 254; host++) {
      final candidate = 'http://$subnet.$host/syswatch_api';
      if (checked.add(candidate)) candidates.add(candidate);
    }

    for (var start = 0; start < candidates.length; start += _batchSize) {
      final end = (start + _batchSize < candidates.length)
          ? start + _batchSize
          : candidates.length;
      final batch = candidates.sublist(start, end);

      final results = await Future.wait(
        batch.map((candidate) async {
          final ok = await _isSyswatchServer(candidate, timeout: _scanTimeout);
          return ok ? candidate : null;
        }),
      );

      for (final result in results) {
        if (result != null) return result;
      }
    }
    return null;
  }

  Future<List<String>> _localPrivateSubnets() async {
    final result = <String>[];
    final seen = <String>{};

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final value = address.address;
          if (!_isPrivateIpv4(value)) continue;
          final parts = value.split('.');
          if (parts.length != 4) continue;
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          if (seen.add(subnet)) result.add(subnet);
        }
      }
    } catch (_) {}

    return result;
  }

  bool _isPrivateIpv4(String value) {
    final parts = value.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) return false;
    final a = parts[0]!;
    final b = parts[1]!;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }

  Future<bool> _isSyswatchServer(
    String baseUrl, {
    required Duration timeout,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client
          .getUrl(Uri.parse('$baseUrl/health.php'))
          .timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) return false;

      final body = await utf8.decoder.bind(response).join().timeout(timeout);
      final decoded = jsonDecode(body.replaceFirst('\uFEFF', '').trim());
      if (decoded is! Map) return false;

      final success = decoded['success'] == true;
      final service = (decoded['service'] ?? '').toString().toLowerCase();
      final status = (decoded['status'] ?? '').toString().toLowerCase();
      return success &&
          (service.contains('syswatch') ||
              status == 'online' ||
              decoded['database'] == 'online');
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  String _normalizeCandidate(String value) {
    var result = value.trim();
    if (result.isEmpty) return '';
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    if (!result.toLowerCase().endsWith('/syswatch_api')) {
      result = '$result/syswatch_api';
    }
    return result;
  }
}
