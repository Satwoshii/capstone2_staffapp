String cleanError(Object error) {
  return error.toString().replaceFirst('Exception:', '').trim();
}

String formatDateTime(DateTime? value) {
  if (value == null) return 'Not available';
  final date = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}

String readableValue(dynamic value) {
  if (value == null) return '';
  if (value is Iterable) {
    return value.map(readableValue).where((item) => item.isNotEmpty).join(', ');
  }
  if (value is Map) {
    return value.entries
        .map((entry) => '${_title(entry.key.toString())}: '
            '${readableValue(entry.value)}')
        .join(' • ');
  }
  return value.toString().trim();
}

/// Converts a Student PC hardware payload into a report that staff can read.
///
/// The API and database intentionally keep machine-friendly fields such as
/// `cpuOk: true`. This formatter changes only their presentation in the Staff
/// App; it does not alter the data sent by the Student PC or stored in MariaDB.
String readableHealthDetails(dynamic value) {
  if (value is! Map) return readableValue(value);

  final fields = <String, dynamic>{
    for (final entry in value.entries)
      _normalizedKey(entry.key.toString()): entry.value,
  };

  final system = <String>[];
  final peripherals = <String>[];

  _addHealthStatus(
    system,
    fields,
    key: 'cpuok',
    label: 'CPU',
    healthy: 'Healthy',
    unhealthy: 'Issue detected',
  );
  _addHealthStatus(
    system,
    fields,
    key: 'ramok',
    label: 'RAM',
    healthy: 'Healthy',
    unhealthy: 'Issue detected',
  );
  _addHealthStatus(
    system,
    fields,
    key: 'diskok',
    label: 'Disk',
    healthy: 'Healthy',
    unhealthy: 'Issue detected',
  );
  _addHealthStatus(
    system,
    fields,
    key: 'storagehealthok',
    label: 'Storage health',
    healthy: 'Healthy',
    unhealthy: 'Issue detected',
  );
  _addHealthStatus(
    system,
    fields,
    key: 'storagecapacityok',
    label: 'Storage space',
    healthy: 'Sufficient',
    unhealthy: 'Low',
  );

  _addHealthStatus(
    peripherals,
    fields,
    key: 'networkok',
    label: 'Ethernet/LAN',
    healthy: 'Connected',
    unhealthy: 'Disconnected',
  );
  _addHealthStatus(
    peripherals,
    fields,
    key: 'keyboardok',
    label: 'Keyboard',
    healthy: 'Connected',
    unhealthy: 'Disconnected',
  );
  _addHealthStatus(
    peripherals,
    fields,
    key: 'mouseok',
    label: 'Mouse',
    healthy: 'Connected',
    unhealthy: 'Disconnected',
  );
  _addHealthStatus(
    peripherals,
    fields,
    key: 'monitorok',
    label: 'Monitor',
    healthy: 'Connected',
    unhealthy: 'Disconnected',
  );
  _addHealthStatus(
    peripherals,
    fields,
    key: 'webcamok',
    label: 'Webcam',
    healthy: 'Connected',
    unhealthy: 'Disconnected',
  );
  _addHealthStatus(
    peripherals,
    fields,
    key: 'printerok',
    label: 'Printer',
    healthy: 'Connected',
    unhealthy: 'Disconnected',
  );
  _addHealthStatus(
    peripherals,
    fields,
    key: 'headsetok',
    label: 'Headset',
    healthy: 'Connected',
    unhealthy: 'Disconnected',
  );

  final lines = <String>[
    if (system.isNotEmpty) system.join('  •  '),
    if (peripherals.isNotEmpty) peripherals.join('  •  '),
  ];

  final issues = _healthIssues(fields);
  lines.add(
    issues.isEmpty
        ? 'Issues: None detected'
        : 'Issues: ${issues.join('; ')}',
  );

  final severity = _cleanScalar(fields['severity']);
  if (severity.isNotEmpty) {
    lines.add('Severity: ${_title(severity)}');
  }

  // If this was a map but not a recognized hardware payload, preserve the
  // generic display instead of returning only "Issues: None detected".
  final hasHardwareStatus = system.isNotEmpty || peripherals.isNotEmpty;
  if (!hasHardwareStatus && issues.isEmpty && severity.isEmpty) {
    return readableValue(value);
  }

  return lines.join('\n');
}

/// Returns the short text used while a PC health card is collapsed.
///
/// Only the detected problems and their severity are shown. Staff can expand
/// the card to see [readableHealthDetails], which includes every reported
/// component state.
String readableHealthIssueSummary(dynamic value) {
  if (value is! Map) {
    final fallback = readableValue(value);
    return fallback.isEmpty ? 'Issues: Status details unavailable' : fallback;
  }

  final fields = <String, dynamic>{
    for (final entry in value.entries)
      _normalizedKey(entry.key.toString()): entry.value,
  };

  final issues = _healthIssues(fields);
  String issuesText;
  if (issues.isEmpty) {
    issuesText = 'Issues: None detected';
  } else if (issues.length >= 3) {
    final count = issues.length - 2;
    issuesText =
        'Issues: ${issues.take(2).join('; ')}... ($count more ${count == 1 ? 'issue' : 'issues'})';
  } else {
    issuesText = 'Issues: ${issues.join('; ')}';
  }

  final lines = <String>[issuesText];

  final severity = _cleanScalar(fields['severity']);
  if (severity.isNotEmpty) {
    lines.add('Severity: ${_title(severity)}');
  }

  return lines.join('\n');
}

void _addHealthStatus(
  List<String> output,
  Map<String, dynamic> fields, {
  required String key,
  required String label,
  required String healthy,
  required String unhealthy,
}) {
  if (!fields.containsKey(key)) return;
  final isHealthy = _boolValue(fields[key]);
  if (isHealthy == null) return;
  output.add('$label: ${isHealthy ? healthy : unhealthy}');
}

List<String> _healthIssues(Map<String, dynamic> fields) {
  final issues = <String>[];

  // Prefer the monitor's human-readable issue descriptions. Category lists
  // usually repeat the same faults using short component names.
  _appendIssueValues(issues, fields['issues']);
  if (issues.isNotEmpty) return _deduplicate(issues);

  const categoryKeys = [
    'peripheralissues',
    'pchealthissues',
    'minorissues',
    'highissues',
    'criticalissues',
  ];

  for (final key in categoryKeys) {
    _appendIssueValues(issues, fields[key]);
  }

  // Failed components are useful only when the payload has no descriptive
  // issue text. This avoids showing the same fault twice.
  if (issues.isEmpty) {
    _appendFailedComponents(issues, fields['failedcomponents']);
  }

  return _deduplicate(issues);
}

List<String> _deduplicate(List<String> values) {
  final seen = <String>{};
  return values.where((value) => seen.add(value.toLowerCase())).toList();
}

void _appendFailedComponents(List<String> output, dynamic value) {
  if (value == null) return;
  if (value is Iterable) {
    for (final item in value) {
      _appendFailedComponents(output, item);
    }
    return;
  }

  final key = _normalizedKey(value.toString());
  const labels = <String, String>{
    'cpu': 'CPU',
    'ram': 'RAM',
    'disk': 'Disk',
    'storage': 'Storage',
    'storagehealth': 'Storage health',
    'storagecapacity': 'Storage space',
    'network': 'Ethernet/LAN',
    'ethernet': 'Ethernet/LAN',
    'keyboard': 'Keyboard',
    'mouse': 'Mouse',
    'monitor': 'Monitor',
    'webcam': 'Webcam',
    'printer': 'Printer',
    'headset': 'Headset',
  };

  final label = labels[key];
  if (label != null) {
    output.add(label);
  } else {
    final text = value.toString().trim();
    if (text.isNotEmpty) output.add(_title(text));
  }
}

void _appendIssueValues(List<String> output, dynamic value) {
  if (value == null) return;
  if (value is Iterable) {
    for (final item in value) {
      _appendIssueValues(output, item);
    }
    return;
  }
  if (value is Map) {
    for (final item in value.values) {
      _appendIssueValues(output, item);
    }
    return;
  }

  final text = value.toString().trim();
  if (text.isEmpty ||
      const {
        'none',
        'null',
        '[]',
        '{}',
        'no issues',
      }.contains(text.toLowerCase())) {
    return;
  }
  output.add(text);
}

bool? _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  switch (value?.toString().trim().toLowerCase()) {
    case 'true':
    case '1':
    case 'yes':
    case 'ok':
    case 'healthy':
    case 'connected':
      return true;
    case 'false':
    case '0':
    case 'no':
    case 'failed':
    case 'unhealthy':
    case 'disconnected':
      return false;
  }
  return null;
}

String _cleanScalar(dynamic value) {
  if (value == null || value is Iterable || value is Map) return '';
  return value.toString().trim();
}

String _normalizedKey(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
}

String _title(String value) {
  return value
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
