import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter/gestures.dart';

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
  String? _pcFilter;
  late final ScrollController _horizontalScrollController;

  // ── Palette (matches the rest of the app) ───────────────────────────────
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor =>
      _isDarkMode ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _accentA => const Color(0xFFFFD700);
  Color get _accentB => const Color(0xFF003366);
  Color get _accentAForeground =>
      _isDarkMode ? _accentA : _accentB;
  Color get _accentBForeground => _isDarkMode ? Colors.white : _accentB;
  Color get _textColor =>
      _isDarkMode ? Colors.white : const Color(0xFF1A1C1E);
  Color get _subTextColor => _isDarkMode ? Colors.white54 : Colors.black45;
  Color get _borderColor => _isDarkMode
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.09);
  Color get _errorColor => const Color(0xFFFF6B6B);
  Color get _warnColor => const Color(0xFFF9A825);
  Color get _okColor => const Color(0xFF22A06B);
  Color get _indigo => const Color(0xFF5C6BC0);

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _horizontalScrollController.dispose();
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
    if (value == 'red') return _errorColor;
    if (value == 'yellow') return _warnColor;
    return _okColor;
  }

  Color _severityColor(String value) {
    switch (value.trim().toLowerCase()) {
      case 'critical':
      case 'emergency':
      case 'high':
        return _errorColor;
      case 'medium':
        return _warnColor;
      default:
        return _accentB;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bgColor,
      child: FutureBuilder<_LabDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: _accentAForeground, strokeWidth: 2.5),
            );
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

          final filteredWorkstations = _pcFilter == null
              ? selected.workstations
              : selected.workstations.where((pc) {
                  switch (_pcFilter) {
                    case 'online':
                      return pc.isOnline;
                    case 'offline':
                      return !pc.isOnline;
                    case 'warning':
                      return pc.activeProblemCount > 0 &&
                          pc.activeProblemCount <= 3 &&
                          pc.majorProblemCount == 0;
                    case 'damaged':
                      return pc.activeProblemCount > 3 || pc.majorProblemCount > 0;
                    case 'problems':
                      return pc.activeProblemCount > 0;
                    default:
                      return true;
                  }
                }).toList();

          return _content(rooms, selected, reports, maintenanceHistory, filteredWorkstations);
        },
      ),
    );
  }

  Widget _content(
      List<LabOverview> rooms,
      LabOverview selected,
      List<FaultReport> reports,
      List<MaintenanceRecord> maintenanceHistory,
      List<LabWorkstation> filteredWorkstations,
      ) {
    return RefreshIndicator(
      color: _accentAForeground,
      backgroundColor: _cardColor,
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          _buildToolbarRow(),
          const SizedBox(height: 16),
          SizedBox(
            height: 180, // Increased slightly to accommodate scrollbar
            child: Listener(
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  GestureBinding.instance.pointerSignalResolver
                      .register(pointerSignal, (event) {
                    if (event is PointerScrollEvent) {
                      final newOffset = _horizontalScrollController.offset +
                          event.scrollDelta.dy;
                      if (newOffset < 0) {
                        _horizontalScrollController.jumpTo(0);
                      } else if (newOffset >
                          _horizontalScrollController.position
                              .maxScrollExtent) {
                        _horizontalScrollController.jumpTo(
                            _horizontalScrollController
                                .position.maxScrollExtent);
                      } else {
                        _horizontalScrollController.jumpTo(newOffset);
                      }
                    }
                  });
                }
              },
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: false, // Only show when scrolling
                  trackVisibility: false,
                  thickness: 5,
                  radius: const Radius.circular(10),
                  notificationPredicate: (notification) =>
                  notification.depth == 0,
                  child: ListView.separated(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 12),
                    // Space for the scrollbar
                    physics: const BouncingScrollPhysics(),
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return _roomCard(room, room.roomName == selected.roomName);
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _selectedRoomHeader(selected),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050 ? 8 : 6;
              if (filteredWorkstations.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.filter_list_off_rounded, color: _subTextColor, size: 32),
                      const SizedBox(height: 10),
                      Text(
                        'No PCs match this filter',
                        style: TextStyle(color: _subTextColor, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                ),
                itemCount: filteredWorkstations.length,
                itemBuilder: (context, index) =>
                    _pcTile(filteredWorkstations[index]),
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

  Widget _buildToolbarRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'Maintenance is summarized per laboratory. Select a room to '
                'view its PC map, online/offline counts, and active problems.',
            style: TextStyle(color: _subTextColor, fontSize: 12.5, height: 1.4),
          ),
        ),
        const SizedBox(width: 12),
        _outlinedButton(
          label: 'PC Checklist Records',
          icon: Icons.fact_check_rounded,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: _bgColor,
                appBar: AppBar(
                  title: const Text('PC Checklist Records'),
                  backgroundColor: _cardColor,
                  foregroundColor: _textColor,
                  surfaceTintColor: Colors.transparent,
                ),
                body: const SafeArea(child: PreventiveMaintenanceScreen()),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _iconTile(icon: Icons.refresh_rounded, tooltip: 'Refresh', onPressed: _refresh),
      ],
    );
  }

  Widget _outlinedButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentB.withValues(alpha: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: _accentBForeground),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: _accentBForeground,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconTile({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 46,
        height: 46,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _fieldColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: Icon(icon, color: _subTextColor, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roomCard(LabOverview room, bool selected) {
    final color = _conditionColor(room.maintenanceColor);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _selectedRoomName = room.roomName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: _isDarkMode ? 0.1 : 0.07) : _cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.7) : _borderColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.meeting_room_rounded, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lab ${room.roomName}',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${room.onlinePcCount} online · ${room.offlinePcCount} offline',
              style: TextStyle(color: _subTextColor, fontSize: 12.5),
            ),
            const SizedBox(height: 4),
            Text(
              '${room.activeProblemCount} active problem(s)',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              room.teacherDisplayName == null
                  ? 'No Teacher account assigned'
                  : 'Teacher: ${room.teacherDisplayName}',
              style: TextStyle(color: _subTextColor, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedRoomHeader(LabOverview room) {
    final color = _conditionColor(room.maintenanceColor);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LAB ${room.roomName} MAP',
                style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.2,
                ),
              ),
              if (_pcFilter != null) ...[
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => setState(() => _pcFilter = null),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Clear filter', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: _errorColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge('Online ${room.onlinePcCount}', _okColor, 'online'),
              _badge('Offline ${room.offlinePcCount}', Colors.blueGrey, 'offline'),
              _badge('All Damage ${room.activeProblemCount}', _indigo, 'damaged'),
              _badge('Minor ${room.warningPcCount}', _warnColor, 'minor'),
              _badge('Major ${room.damagedPcCount}', _errorColor, 'major'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, String value) {
    final active = _pcFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _pcFilter = active ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: _isDarkMode ? 0.25 : 0.18)
              : color.withValues(alpha: _isDarkMode ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : color.withValues(alpha: 0.3),
            width: active ? 1.8 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _pcTile(LabWorkstation pc) {
    // Determine the status color based on connectivity and problems
    Color statusColor;
    if (pc.activeProblemCount > 3 || pc.majorProblemCount > 0) {
      statusColor = _errorColor;
    } else if (pc.activeProblemCount > 0) {
      statusColor = _warnColor;
    } else if (!pc.isOnline) {
      statusColor = Colors.blueGrey;
    } else {
      statusColor = _okColor;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: _isDarkMode ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.6),
          width: 1.6,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.computer_rounded, color: statusColor, size: 26),
          const SizedBox(height: 5),
          Text(
            pc.pcId,
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            pc.isOnline ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          if (pc.activeProblemCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${pc.activeProblemCount} ERR',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
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
          color: report.repaired ? _okColor : color,
          title: '${report.pcId} · ${report.issue}',
          subtitle:
          '${report.severity.toUpperCase()} · '
              '${report.workflowStatus.replaceAll('_', ' ').toUpperCase()}'
              '${report.acceptedByName != null ? '\nAccepted: ${report.acceptedByName} · ${formatDateTime(report.acceptedAt)}' : ''}'
              '${report.handledByName != null ? '\nHandled: ${report.handledByName} · ${formatDateTime(report.handledAt)}' : ''}'
              '${report.completedByName != null ? '\nCompleted: ${report.completedByName} · ${formatDateTime(report.completedAt)}' : ''}',
        );
      }).toList(),
    );
  }

  Widget _maintenanceHistoryPanel(List<MaintenanceRecord> records) {
    final ordered = records.toList()
      ..sort((a, b) {
        final aTime = a.maintenanceDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.maintenanceDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    return _detailPanel(
      title: 'Maintenance History',
      icon: Icons.history_rounded,
      emptyMessage: 'No maintenance records exist for this laboratory.',
      children: ordered.take(8).map((record) {
        final color = record.overallCondition == 'critical'
            ? _errorColor
            : record.overallCondition == 'needs_attention'
            ? _warnColor
            : _okColor;
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.4 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isDarkMode ? _accentA : _accentB,
                  border: Border.all(color: _accentA.withValues(alpha: 0.35), width: 1.1),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: _isDarkMode ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(color: _textColor, fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (children.isEmpty)
            Text(emptyMessage, style: TextStyle(color: _subTextColor, fontSize: 13))
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: _textColor, fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: _subTextColor, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
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