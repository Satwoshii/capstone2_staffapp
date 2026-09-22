class LabWorkstation {
  final String workstationId;
  final String pcId;
  final String connectionStatus;
  final String deviceStatus;
  final String maintenanceColor;
  final int activeProblemCount;
  final int majorProblemCount;
  final DateTime? lastSeenAt;
  final bool isRegistered;

  const LabWorkstation({
    required this.workstationId,
    required this.pcId,
    required this.connectionStatus,
    required this.deviceStatus,
    required this.maintenanceColor,
    required this.activeProblemCount,
    required this.majorProblemCount,
    this.lastSeenAt,
    this.isRegistered = true,
  });

  bool get isOnline => isRegistered && connectionStatus == 'online';
  bool get canReport {
    final id = pcId.trim().toLowerCase();
    return id.isNotEmpty && id != 'general';
  }
  bool get isPlaceholder => !isRegistered;

  factory LabWorkstation.fromJson(Map<String, dynamic> json) {
    return LabWorkstation(
      workstationId: (json['workstation_id'] ?? '').toString(),
      pcId: (json['pc_id'] ?? '').toString(),
      connectionStatus: (json['connection_status'] ?? 'offline').toString(),
      deviceStatus: (json['device_status'] ?? 'unknown').toString(),
      maintenanceColor: (json['maintenance_color'] ?? 'green').toString(),
      activeProblemCount: _int(json['active_problem_count']),
      majorProblemCount: _int(json['major_problem_count']),
      lastSeenAt: DateTime.tryParse((json['last_seen_at'] ?? '').toString()),
      isRegistered: _bool(json['is_registered'], fallback: true),
    );
  }
}

class LabOverview {
  final String roomName;
  final int expectedPcCount;
  final int registeredPcCount;
  final int onlinePcCount;
  final int offlinePcCount;
  final int unregisteredPcCount;
  final int activeProblemCount;
  final int majorProblemCount;
  final int awaitingTeacherApprovalCount;
  final String maintenanceColor;
  final String? teacherDisplayName;
  final String? teacherEmail;
  final List<LabWorkstation> workstations;

  const LabOverview({
    required this.roomName,
    required this.expectedPcCount,
    required this.registeredPcCount,
    required this.onlinePcCount,
    required this.offlinePcCount,
    required this.unregisteredPcCount,
    required this.activeProblemCount,
    required this.majorProblemCount,
    required this.awaitingTeacherApprovalCount,
    required this.maintenanceColor,
    this.teacherDisplayName,
    this.teacherEmail,
    required this.workstations,
  });

  List<LabWorkstation> get registeredWorkstations =>
      workstations.where((pc) => pc.isRegistered).toList();

  int get healthyPcCount => workstations
      .where((pc) => pc.isRegistered && pc.activeProblemCount == 0)
      .length;

  int get warningPcCount => workstations
      .where(
        (pc) =>
            pc.isRegistered &&
            pc.activeProblemCount > 0 &&
            pc.activeProblemCount <= 3 &&
            pc.majorProblemCount == 0,
      )
      .length;

  int get damagedPcCount => workstations
      .where(
        (pc) =>
            pc.isRegistered &&
            (pc.activeProblemCount > 3 || pc.majorProblemCount > 0),
      )
      .length;

  factory LabOverview.fromJson(Map<String, dynamic> json) {
    final rawWorkstations = json['workstations'];
    final workstations = rawWorkstations is List
        ? rawWorkstations.whereType<Map>().map((item) {
            return LabWorkstation.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            );
          }).toList()
        : <LabWorkstation>[];
    return LabOverview(
      roomName: (json['room_name'] ?? '').toString(),
      expectedPcCount: _int(json['expected_pc_count']),
      registeredPcCount: _int(json['registered_pc_count']),
      onlinePcCount: _int(json['online_pc_count']),
      offlinePcCount: _int(json['offline_pc_count']),
      unregisteredPcCount: _int(json['unregistered_pc_count']),
      activeProblemCount: _int(json['active_problem_count']),
      majorProblemCount: _int(json['major_problem_count']),
      awaitingTeacherApprovalCount:
          _int(json['awaiting_teacher_approval_count']),
      maintenanceColor: (json['maintenance_color'] ?? 'green').toString(),
      teacherDisplayName: _nullable(json['teacher_display_name']),
      teacherEmail: _nullable(json['teacher_email']),
      workstations: workstations,
    );
  }
}

int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

bool _bool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  if (text == '1' || text == 'true' || text == 'yes') return true;
  if (text == '0' || text == 'false' || text == 'no') return false;
  return fallback;
}

String? _nullable(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
