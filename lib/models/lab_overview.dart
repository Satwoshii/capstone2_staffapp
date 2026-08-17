class LabWorkstation {
  final String workstationId;
  final String pcId;
  final String connectionStatus;
  final String deviceStatus;
  final String maintenanceColor;
  final int activeProblemCount;
  final int majorProblemCount;
  final DateTime? lastSeenAt;

  const LabWorkstation({
    required this.workstationId,
    required this.pcId,
    required this.connectionStatus,
    required this.deviceStatus,
    required this.maintenanceColor,
    required this.activeProblemCount,
    required this.majorProblemCount,
    this.lastSeenAt,
  });

  bool get isOnline => connectionStatus == 'online';

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
    );
  }
}

class LabOverview {
  final String roomName;
  final int expectedPcCount;
  final int registeredPcCount;
  final int onlinePcCount;
  final int offlinePcCount;
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
    required this.activeProblemCount,
    required this.majorProblemCount,
    required this.awaitingTeacherApprovalCount,
    required this.maintenanceColor,
    this.teacherDisplayName,
    this.teacherEmail,
    required this.workstations,
  });

  int get healthyPcCount => workstations
      .where((pc) => pc.activeProblemCount == 0)
      .length;

  int get warningPcCount => workstations
      .where(
        (pc) =>
            pc.activeProblemCount > 0 &&
            pc.activeProblemCount <= 3 &&
            pc.majorProblemCount == 0,
      )
      .length;

  int get damagedPcCount => workstations
      .where((pc) => pc.activeProblemCount > 3 || pc.majorProblemCount > 0)
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

String? _nullable(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
