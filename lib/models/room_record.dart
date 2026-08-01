class RoomRecord {
  final String roomName;
  final int pcCount;
  final int registeredPcCount;
  final bool active;
  final DateTime? createdAt;

  const RoomRecord({
    required this.roomName,
    required this.pcCount,
    required this.registeredPcCount,
    required this.active,
    this.createdAt,
  });

  factory RoomRecord.fromJson(Map<String, dynamic> json) {
    return RoomRecord(
      roomName: (json['room_name'] ?? json['roomName'] ?? '').toString(),
      pcCount: int.tryParse((json['pc_count'] ?? json['pcCount'] ?? 0).toString()) ?? 0,
      registeredPcCount: int.tryParse(
            (json['registered_pc_count'] ?? json['registeredPcCount'] ?? 0)
                .toString(),
          ) ??
          0,
      active: _toBool(json['active']),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString() == '1' || value.toString().toLowerCase() == 'true';
  }
}
