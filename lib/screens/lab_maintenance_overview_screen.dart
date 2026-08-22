import 'dart:async';

import 'package:flutter/material.dart';

import '../models/fault_report.dart';
import '../models/lab_overview.dart';
import '../models/maintenance_record.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/message_state.dart';
import 'preventive_maintenance_screen.dart';

class LabMaintenanceOverviewScreen extends StatefulWidget {
  const LabMaintenanceOverviewScreen({super.key});

  @override
  State<LabMaintenanceOverviewScreen> createState() =>
      _LabMaintenanceOverviewScreenState();
}

class _LabMaintenanceOverviewScreenState
    extends State<LabMaintenanceOverviewScreen> {
  Future<_LabDashboardData>? _future;
  Timer? _timer;
  String? _selectedRoomName;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _card => _dark ? const Color(0xFF13141A) : Colors.white;
  Color get _field =>
      _dark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _text => _dark ? Colors.white : const Color(0xFF1A1C1E);
  Color get _sub => _dark ? Colors.white54 : Colors.black54;
  Color get _border =>
      _dark ? Colors.white.withValues(alpha: 0.08) : Colors.black12;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _future = Future.wait<dynamic>([
        StaffService.instance.listLabOverview(),
        StaffService.instance.listFaultReports(),
        StaffService.instance.listMaintenanceHistory(),
      ]).then(
        (values) => _LabDashboardData(
          rooms: values[0] as List<LabOverview>,
          reports: values[1] as List<FaultReport>,
          maintenanceHistory: values[2] as List<MaintenanceRecord>,
        ),
      );
    });
  }

  Color _conditionColor(String value) {
    if (value == 'red') return const Color(0xFFE53935);
    if (value == 'yellow') return const Color(0xFFF9A825);
    return const Color(0xFF22A06B);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LabDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return MessageState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load laboratory maintenance',
            message: cleanError(snapshot.error!),
            onRetry: _refresh,
          );
        }
        final data = snapshot.data;
        final rooms = data?.rooms ?? const <LabOverview>[];
        if (rooms.isEmpty) {
          return MessageState(
            icon: Icons.meeting_room_outlined,
            title: 'No active laboratory rooms',
            message: 'Create and activate a room before viewing maintenance.',
            onRetry: _refresh,
          );
        }
        final selectedName = _selectedRoomName ?? rooms.first.roomName;
        final selected = rooms.firstWhere(
          (room) => room.roomName == selectedName,
          orElse: () => rooms.first,
        );
        final reports = (data?.reports ?? const <FaultReport>[])
            .where((report) => report.roomName == selected.roomName)
            .toList();
        final maintenanceHistory =
            (data?.maintenanceHistory ?? const <MaintenanceRecord>[])
                .where((record) => record.roomName == selected.roomName)
                .toList();
        return _content(rooms, selected, reports, maintenanceHistory);
      },
    );
  }

  Widget _content(
    List<LabOverview> rooms,
    LabOverview selected,
    List<FaultReport> reports,
    List<MaintenanceRecord> maintenanceHistory,
  ) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Maintenance is summarized per laboratory. Select a room to '
                  'view its PC map, online/offline counts, and active problems.',
                  style: TextStyle(color: _sub),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text('PC Checklist Records')),
                      body: const SafeArea(child: PreventiveMaintenanceScreen()),
                    ),
                  ),
                ),
                icon: const Icon(Icons.fact_check_rounded),
                label: const Text('PC Checklist Records'),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 164,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final room = rooms[index];
                return _roomCard(room, room.roomName == selected.roomName);
              },
            ),
          ),
          const SizedBox(height: 18),
          _selectedRoomHeader(selected),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050 ? 8 : 6;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                ),
                itemCount: selected.workstations.length,
                itemBuilder: (context, index) =>
                    _pcTile(selected.workstations[index]),
              );
            },
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final reportsPanel = _reportsPanel(reports);
              final historyPanel = _maintenanceHistoryPanel(maintenanceHistory);
              if (constraints.maxWidth >= 980) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: reportsPanel),
                    const SizedBox(width: 14),
                    Expanded(child: historyPanel),
                  ],
                );
              }
              return Column(
                children: [
                  reportsPanel,
                  const SizedBox(height: 14),
                  historyPanel,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _roomCard(LabOverview room, bool selected) {
    final color = _conditionColor(room.maintenanceColor);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _selectedRoomName = room.roomName),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.5),
            width: selected ? 3 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.meeting_room_rounded, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lab ${room.roomName}',
                    style: TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${room.onlinePcCount} online · ${room.offlinePcCount} offline',
              style: TextStyle(color: _sub),
            ),
            const SizedBox(height: 4),
            Text(
              '${room.activeProblemCount} active problem(s)',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              room.teacherDisplayName == null
                  ? 'No Teacher account assigned'
                  : 'Teacher: ${room.teacherDisplayName}',
              style: TextStyle(color: _sub, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedRoomHeader(LabOverview room) {
    final color = _conditionColor(room.maintenanceColor);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LAB ${room.roomName} MAP',
                  style: TextStyle(color: _text, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  room.maintenanceColor.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge('Online ${room.onlinePcCount}', const Color(0xFF22A06B)),
              _badge('Offline ${room.offlinePcCount}', Colors.blueGrey),
              _badge('Healthy ${room.healthyPcCount}', const Color(0xFF22A06B)),
              _badge('Warning ${room.warningPcCount}', const Color(0xFFF9A825)),
              _badge('Damaged ${room.damagedPcCount}', const Color(0xFFE53935)),
              _badge('Problems ${room.activeProblemCount}', color),
              _badge(
                'Awaiting Teacher ${room.awaitingTeacherApprovalCount}',
                const Color(0xFF4F8EF7),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _pcTile(LabWorkstation pc) {
    final color = _conditionColor(pc.maintenanceColor);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.75), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.computer_rounded, color: color, size: 27),
          const SizedBox(height: 5),
          Text(pc.pcId, style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            pc.isOnline ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              color: pc.isOnline ? const Color(0xFF22A06B) : Colors.blueGrey,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (pc.activeProblemCount > 0)
            Text(
              '${pc.activeProblemCount} problem(s)',
              style: TextStyle(color: color, fontSize: 10),
            ),
        ],
      ),
    );
  }

  Widget _reportsPanel(List<FaultReport> reports) {
    final ordered = reports.toList()
      ..sort((a, b) {
        if (a.repaired != b.repaired) return a.repaired ? 1 : -1;
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    return _detailPanel(
      title: 'Laboratory Reports',
      icon: Icons.report_problem_outlined,
      emptyMessage: 'No reports have been recorded for this laboratory.',
      children: ordered.take(8).map((report) {
        final color = _severityColor(report.severity);
        return _detailRow(
          icon: report.repaired
              ? Icons.check_circle_outline_rounded
              : Icons.warning_amber_rounded,
          color: report.repaired ? const Color(0xFF22A06B) : color,
          title: '${report.pcId} · ${report.issue}',
          subtitle:
              '${report.severity.toUpperCase()} · '
              '${report.workflowStatus.replaceAll('_', ' ').toUpperCase()}',
        );
      }).toList(),
    );
  }

  Widget _maintenanceHistoryPanel(List<MaintenanceRecord> records) {
    final ordered = records.toList()
      ..sort((a, b) {
        final aTime =
            a.maintenanceDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.maintenanceDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    return _detailPanel(
      title: 'Maintenance History',
      icon: Icons.history_rounded,
      emptyMessage: 'No maintenance records exist for this laboratory.',
      children: ordered.take(8).map((record) {
        final color = record.overallCondition == 'critical'
            ? const Color(0xFFE53935)
            : record.overallCondition == 'needs_attention'
                ? const Color(0xFFF9A825)
                : const Color(0xFF22A06B);
        return _detailRow(
          icon: Icons.home_repair_service_outlined,
          color: color,
          title: '${record.pcId} · ${record.technicianName}',
          subtitle:
              '${record.overallCondition.replaceAll('_', ' ').toUpperCase()} · '
              '${formatDateTime(record.maintenanceDate)}',
        );
      }).toList(),
    );
  }

  Widget _detailPanel({
    required String title,
    required IconData icon,
    required String emptyMessage,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF4F8EF7)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: _text, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            Text(emptyMessage, style: TextStyle(color: _sub))
          else
            ...children,
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: _text, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: _sub, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String value) {
    switch (value.trim().toLowerCase()) {
      case 'critical':
      case 'emergency':
      case 'high':
        return const Color(0xFFE53935);
      case 'medium':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF4F8EF7);
    }
  }
}

class _LabDashboardData {
  final List<LabOverview> rooms;
  final List<FaultReport> reports;
  final List<MaintenanceRecord> maintenanceHistory;

  const _LabDashboardData({
    required this.rooms,
    required this.reports,
    required this.maintenanceHistory,
  });
}
