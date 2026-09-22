class MaintenanceSchedule {
  final String workstationId;
  final String roomName;
  final String pcId;
  final String workstationStatus;
  final DateTime? registeredAt;
  final DateTime? lastSeenAt;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextDueDate;
  final String scheduleStatus;
  final int daysUntilDue;
  final String? lastOverallCondition;
  final String? lastTechnicianName;
  final int softwareIssueCount;

  const MaintenanceSchedule({
    required this.workstationId,
    required this.roomName,
    required this.pcId,
    required this.workstationStatus,
    this.registeredAt,
    this.lastSeenAt,
    this.lastMaintenanceDate,
    this.nextDueDate,
    required this.scheduleStatus,
    required this.daysUntilDue,
    this.lastOverallCondition,
    this.lastTechnicianName,
    this.softwareIssueCount = 0,
  });

  bool get isOverdue => scheduleStatus == 'overdue';
  bool get isDueSoon => scheduleStatus == 'due_soon';
  bool get isUpToDate => scheduleStatus == 'up_to_date' || scheduleStatus == 'scheduled';

  factory MaintenanceSchedule.fromJson(Map<String, dynamic> json) {
    return MaintenanceSchedule(
      workstationId: (json['workstation_id'] ?? '').toString(),
      roomName: (json['room_name'] ?? '').toString(),
      pcId: (json['pc_id'] ?? '').toString(),
      workstationStatus: (json['workstation_status'] ?? 'offline').toString(),
      registeredAt: _date(json['registered_at']),
      lastSeenAt: _date(json['last_seen_at']),
      lastMaintenanceDate: _date(json['last_maintenance_date']),
      nextDueDate: _date(json['next_due_date']),
      scheduleStatus: (json['schedule_status'] ?? 'up_to_date').toString(),
      daysUntilDue: int.tryParse((json['days_until_due'] ?? '0').toString()) ?? 0,
      lastOverallCondition: _nullable(json['last_overall_condition']),
      lastTechnicianName: _nullable(json['last_technician_name']),
      softwareIssueCount: int.tryParse((json['software_issue_count'] ?? '0').toString()) ?? 0,
    );
  }
}

class MaintenanceRecord {
  final String id;
  final String workstationId;
  final String roomName;
  final String pcId;
  final String technicianName;
  final DateTime? maintenanceDate;
  final DateTime? nextDueDate;
  final String overallCondition;
  final Map<String, bool> checklist;
  final String findings;
  final String actionsTaken;
  final String recommendations;

  const MaintenanceRecord({
    required this.id,
    required this.workstationId,
    required this.roomName,
    required this.pcId,
    required this.technicianName,
    this.maintenanceDate,
    this.nextDueDate,
    required this.overallCondition,
    required this.checklist,
    required this.findings,
    required this.actionsTaken,
    required this.recommendations,
  });

  int get completedChecklistItems => checklist.values.where((value) => value).length;

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    final rawChecklist = json['checklist'];
    final checklist = <String, bool>{};
    if (rawChecklist is Map) {
      for (final entry in rawChecklist.entries) {
        checklist[entry.key.toString()] = _bool(entry.value);
      }
    }

    return MaintenanceRecord(
      id: (json['id'] ?? '').toString(),
      workstationId: (json['workstation_id'] ?? '').toString(),
      roomName: (json['room_name'] ?? '').toString(),
      pcId: (json['pc_id'] ?? '').toString(),
      technicianName: (json['technician_name'] ?? '').toString(),
      maintenanceDate: _date(json['maintenance_date']),
      nextDueDate: _date(json['next_due_date']),
      overallCondition: (json['overall_condition'] ?? 'good').toString(),
      checklist: checklist,
      findings: (json['findings'] ?? '').toString(),
      actionsTaken: (json['actions_taken'] ?? '').toString(),
      recommendations: (json['recommendations'] ?? '').toString(),
    );
  }
}

DateTime? _date(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
}

String? _nullable(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const ['1', 'true', 'yes', 'on'].contains(value.toString().toLowerCase());
}
