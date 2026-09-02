import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/fault_report.dart';
import '../models/lab_overview.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/theme_toggle_button.dart';
import 'staff_login_screen.dart';
import 'teacher_chat_screen.dart';

const _teacherProblemOptions = <_TeacherProblemOption>[
  _TeacherProblemOption(
    label: 'Keyboard problem',
    severity: 'minor',
    icon: Icons.keyboard_rounded,
  ),
  _TeacherProblemOption(
    label: 'Mouse problem',
    severity: 'minor',
    icon: Icons.mouse_rounded,
  ),
  _TeacherProblemOption(
    label: 'Monitor or display problem',
    severity: 'minor',
    icon: Icons.monitor_rounded,
  ),
  _TeacherProblemOption(
    label: 'Software or application problem',
    severity: 'medium',
    icon: Icons.apps_rounded,
  ),
  _TeacherProblemOption(
    label: 'Ethernet or LAN disconnected',
    severity: 'high',
    icon: Icons.lan_rounded,
  ),
  _TeacherProblemOption(
    label: 'Network port or LAN cable damage',
    severity: 'high',
    icon: Icons.cable_rounded,
  ),
  _TeacherProblemOption(
    label: 'Visible physical damage',
    severity: 'high',
    icon: Icons.build_circle_outlined,
  ),
  _TeacherProblemOption(
    label: 'PC power or startup problem',
    severity: 'critical',
    icon: Icons.power_settings_new_rounded,
  ),
  _TeacherProblemOption(
    label: 'CPU problem',
    severity: 'critical',
    icon: Icons.memory_rounded,
  ),
  _TeacherProblemOption(
    label: 'RAM or memory problem',
    severity: 'critical',
    icon: Icons.developer_board_rounded,
  ),
  _TeacherProblemOption(
    label: 'Disk not detected or disk failure',
    severity: 'critical',
    icon: Icons.storage_rounded,
  ),
  _TeacherProblemOption(
    label: 'Storage health problem',
    severity: 'critical',
    icon: Icons.health_and_safety_outlined,
  ),
  _TeacherProblemOption(
    label: 'Low storage capacity',
    severity: 'critical',
    icon: Icons.disc_full_rounded,
  ),
  _TeacherProblemOption(
    label: 'Smoke, sparks, burning smell, or electrical hazard',
    severity: 'emergency',
    icon: Icons.local_fire_department_rounded,
  ),
  _TeacherProblemOption(
    label: 'Other workstation problem',
    severity: 'medium',
    icon: Icons.report_problem_outlined,
  ),
];

class _TeacherProblemOption {
  final String label;
  final String severity;
  final IconData icon;

  const _TeacherProblemOption({
    required this.label,
    required this.severity,
    required this.icon,
  });
}

class TeacherDashboardScreen extends StatefulWidget {
  final AppUser user;

  const TeacherDashboardScreen({super.key, required this.user});

  @override
  State<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  Future<(LabOverview, List<FaultReport>)>? _future;
  Timer? _timer;
  bool _loggingOut = false;
  final _busyReports = <String>{};

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _background =>
      _dark ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _card => _dark ? const Color(0xFF13141A) : Colors.white;
  Color get _field =>
      _dark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _text => _dark ? Colors.white : const Color(0xFF1A1C1E);
  Color get _sub => _dark ? Colors.white54 : Colors.black54;
  Color get _border =>
      _dark ? Colors.white.withValues(alpha: 0.08) : Colors.black12;
  Color get _accentA => const Color(0xFFFFD700);
  Color get _accentB => const Color(0xFF003366);
  Color get _accentAForeground => _dark ? _accentA : _accentB;
  Color get _accentBForeground => _dark ? Colors.white : _accentB;
  Color get _errorColor => const Color(0xFFFF6B6B);
  Color get _accentColor => _dark ? _accentA : _accentB;

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
    if (!mounted || _loggingOut) return;

    setState(() {
      _future = Future.wait<dynamic>([
        StaffService.instance.teacherOverview(),
        StaffService.instance.listTeacherReports(),
      ]).then((values) {
        return (values[0] as LabOverview, values[1] as List<FaultReport>);
      });
    });
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() => _loggingOut = true);

    // Stop periodic rebuilds before the Teacher dashboard route is removed.
    _timer?.cancel();
    _timer = null;

    try {
      await StaffService.instance.logout();
    } catch (_) {
      // Still return to the local login screen if the server is unavailable.
    }

    if (!mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StaffLoginScreen()),
      (_) => false,
    );
  }

  Color _conditionColor(String value) {
    switch (value) {
      case 'red':
        return const Color(0xFFE53935);
      case 'yellow':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF22A06B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          _ambientBackground(),
          Column(
            children: [
              _topBar(),
              Expanded(
                child: FutureBuilder<(LabOverview, List<FaultReport>)>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: _card,
                            shape: BoxShape.circle,
                            border: Border.all(color: _border),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            color: _accentAForeground,
                            strokeWidth: 2.4,
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _errorState(cleanError(snapshot.error!));
                    }
                    final data = snapshot.data;
                    if (data == null) return _errorState('No room data found.');
                    return _content(data.$1, data.$2);
                  },
                ),
              ),
            ],
          ),
          const Positioned(
            left: 20,
            bottom: 20,
            child: ThemeToggleButton(),
          ),
        ],
      ),
    );
  }

  Widget _ambientBackground() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -180,
            left: -120,
            child: Container(
              width: 520,
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentB.withValues(alpha: _dark ? 0.15 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -180,
            bottom: -220,
            child: Container(
              width: 620,
              height: 620,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentAForeground.withValues(alpha: _dark ? 0.12 : 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    final room = widget.user.assignedRoomName ?? 'Unassigned';
    final navBg = _dark ? _card.withValues(alpha: 0.96) : _accentB;
    final navFg = _dark ? _text : Colors.white;
    final navSub = _dark ? _sub : Colors.white70;
    final navBorder = _dark ? _border : Colors.white.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
      decoration: BoxDecoration(
        color: navBg,
        border: Border(bottom: BorderSide(color: navBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _dark ? 0.16 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _dark ? _accentColor.withValues(alpha: 0.14) : Colors.white.withOpacity(0.2),
                border: Border.all(
                  color: _dark ? _accentColor.withValues(alpha: 0.38) : Colors.white.withOpacity(0.3),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.school_rounded,
                color: _dark ? _accentAForeground : Colors.white,
                size: 24,
              ),
            ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SysWatch Teacher',
                style: TextStyle(
                  color: navFg,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Laboratory $room · Monitoring Dashboard',
                style: TextStyle(color: navSub, fontSize: 11.5),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _dark ? _field : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _dark ? navBorder : Colors.black.withOpacity(0.1), width: 1.2),
              boxShadow: [
                if (!_dark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _dark ? _accentAForeground.withValues(alpha: 0.12) : _accentB.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_rounded, color: _dark ? _accentAForeground : _accentB, size: 15),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.user.displayName,
                  style: TextStyle(
                    color: _dark ? navFg : Colors.black87,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _gradientButton(
            label: 'Chat with ITSO',
            icon: Icons.forum_rounded,
            onPressed: _openChat,
          ),
          const SizedBox(width: 8),
          _iconTile(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh dashboard',
            onPressed: _refresh,
          ),
          const SizedBox(width: 8),
          _iconTile(
            icon: _loggingOut
                ? Icons.hourglass_top_rounded
                : Icons.logout_rounded,
            tooltip: 'Sign out',
            onPressed: _loggingOut ? null : _logout,
          ),
        ],
      ),
    );
  }

  Widget _iconTile({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final navBorder = _dark ? _border : Colors.white.withOpacity(0.1);
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _dark ? _field : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: navBorder),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: Icon(icon, color: _dark ? _sub : Colors.white70, size: 19),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: disabled ? _field : _accentColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: disabled ? _sub : (_dark ? Colors.black : Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: disabled ? _sub : (_dark ? Colors.black : Colors.white),
                    fontWeight: FontWeight.w700,
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

  Future<void> _openChat() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherChatScreen(user: widget.user),
      ),
    );
  }

  Widget _content(LabOverview room, List<FaultReport> reports) {
    final openReports = reports.where((report) => !report.repaired).toList();
    final color = _conditionColor(room.maintenanceColor);

    return RefreshIndicator(
      color: _accentAForeground,
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 86),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _roomHeader(room, color),
                  const SizedBox(height: 18),
                  _sectionCard(
                    icon: Icons.grid_view_rounded,
                    title: 'Lab Map',
                    subtitle: 'Select a workstation to view its current condition.',
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1320
                            ? 7
                            : constraints.maxWidth >= 1050
                            ? 6
                            : constraints.maxWidth >= 780
                            ? 4
                            : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.28,
                          ),
                          itemCount: room.workstations.length,
                          itemBuilder: (context, index) =>
                              _pcTile(room.workstations[index]),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionCard(
                    icon: Icons.assignment_rounded,
                    title: 'Room Reports',
                    subtitle: openReports.isEmpty
                        ? 'No unresolved reports in Laboratory ${room.roomName}.'
                        : '${openReports.length} unresolved report${openReports.length == 1 ? '' : 's'} need attention.',
                    trailing: _gradientButton(
                      label: 'Report Damaged PC',
                      icon: Icons.report_problem_rounded,
                      onPressed: room.workstations.isEmpty
                          ? null
                          : () => _showCreateReport(room),
                    ),
                    child: openReports.isEmpty
                        ? _emptyReports()
                        : Column(
                      children: [
                        for (final report in openReports)
                          _reportCard(report),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: _dark ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _dark ? 0.12 : 0.035),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accentColor.withValues(alpha: 0.22)),
                ),
                child: Icon(icon, color: _accentAForeground, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _text,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: _sub, fontSize: 11.8),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _roomHeader(LabOverview room, Color color) {
    final healthy = room.maintenanceColor == 'green';
    final warning = room.maintenanceColor == 'yellow';
    final statusText = healthy
        ? 'All reported checks are clear.'
        : warning
        ? 'The room has 1–3 active minor problems.'
        : 'The room has many problems or a high/critical problem.';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _dark ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.48), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: _dark ? 0.10 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(Icons.meeting_room_rounded, color: color, size: 31),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Laboratory ${room.roomName}',
                      style: TextStyle(
                        color: _text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.24)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            healthy ? 'HEALTHY' : warning ? 'WARNING' : 'ATTENTION',
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  statusText,
                  style: TextStyle(color: _sub, fontSize: 12.7, height: 1.35),
                ),
              ],
            ),
          ),
          _metric('Online', room.onlinePcCount, const Color(0xFF22A06B)),
          _metric('Offline', room.offlinePcCount, Colors.blueGrey),
          _metric('Problems', room.activeProblemCount, color),
          _metric(
            'Approve',
            room.awaitingTeacherApprovalCount,
            _accentBForeground,
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, int value, Color color) {
    return Container(
      width: 88,
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: _field.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: _sub,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pcTile(LabWorkstation pc) {
    final color = _conditionColor(pc.maintenanceColor);
    final connectionColor = pc.isOnline ? const Color(0xFF22A06B) : Colors.blueGrey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPcDetails(pc),
        child: Ink(
          decoration: BoxDecoration(
            color: pc.isOnline 
                ? _accentColor.withValues(alpha: _dark ? 0.08 : 0.04)
                : _field.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.48), width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.computer_rounded, color: color, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  pc.pcId,
                  style: TextStyle(
                    color: _text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: connectionColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: connectionColor.withValues(alpha: 0.20)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: connectionColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        pc.isOnline ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          color: connectionColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reportCard(FaultReport report) {
    final busy = _busyReports.contains(report.id);
    final severityColor = _severityColor(report.severity);
    final workflow = _workflowLabel(report.workflowStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _field.withValues(alpha: _dark ? 0.74 : 0.84),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: severityColor.withValues(alpha: 0.20)),
            ),
            child: Icon(Icons.report_rounded, color: severityColor, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.pcId} · ${report.issue}',
                  style: TextStyle(
                    color: _text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.details,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _sub, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 7),
                Text(
                  'Reported: ${formatDateTime(report.createdAt)}'
                  '${report.repairedAt != null ? '\nITSO Fixed: ${formatDateTime(report.repairedAt)}' : ''}'
                  '${report.teacherApprovedAt != null ? '\nTeacher Verified: ${formatDateTime(report.teacherApprovedAt)}' : ''}',
                  style: TextStyle(
                    color: _sub,
                    fontSize: 11.2,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: [
                    _statusChip(report.severity.toUpperCase(), severityColor),
                    _statusChip(workflow, _accentBForeground),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          if (busy)
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: _accentAForeground,
              ),
            )
          else if (report.workflowStatus == 'reported' ||
              report.workflowStatus == 'reopened')
            _outlineAction(
              label: 'Send to ITSO',
              icon: Icons.send_rounded,
              onPressed: () => _showForwardDialog(report),
            )
          else if (report.workflowStatus == 'awaiting_teacher_approval')
              Wrap(
                spacing: 8,
                children: [
                  _outlineAction(
                    label: 'Still Damaged',
                    icon: Icons.close_rounded,
                    onPressed: () => _showVerifyDialog(report, false),
                  ),
                  _gradientButton(
                    label: 'PC is OK',
                    icon: Icons.check_rounded,
                    onPressed: () => _showVerifyDialog(report, true),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.7,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
        ),
      ),
    );
  }

  Widget _outlineAction({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _accentBForeground,
        side: BorderSide(color: _accentBForeground.withValues(alpha: 0.42)),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
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

  String? _severityForProblem(String? problemLabel) {
    if (problemLabel == null) return null;
    for (final problem in _teacherProblemOptions) {
      if (problem.label == problemLabel) return problem.severity;
    }
    return null;
  }

  String _severityLabel(String severity) {
    final value = severity.toLowerCase();
    return '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
  }

  String _workflowLabel(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  // ── Shared dialog styling helpers ──────────────────────────────────────────
  ShapeBorder get _dialogShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(22),
    side: BorderSide(color: _border),
  );

  Widget _dialogTitle(String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _accentAForeground.withValues(alpha: 0.24)),
          ),
          child: Icon(icon, color: _accentAForeground, size: 18),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _text,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _dialogFieldDecoration({
    required String label,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _sub, fontSize: 13),
      helperText: helperText,
      helperStyle: TextStyle(color: _sub, fontSize: 11.3),
      helperMaxLines: 3,
      filled: true,
      fillColor: _field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _border),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _border.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accentAForeground.withValues(alpha: 0.8), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _errorColor, width: 1.6),
      ),
      errorStyle: TextStyle(color: _errorColor, fontSize: 11.5),
    );
  }

  Widget _dialogCancelButton(VoidCallback? onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _sub,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _dialogPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    final disabled = onPressed == null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              color: disabled ? _field : _accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading) ...[
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        disabled ? _sub : (_dark ? Colors.black : Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: disabled ? _sub : (_dark ? Colors.black : Colors.white),
                    fontWeight: FontWeight.w700,
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

  Future<void> _showCreateReport(LabOverview room) async {
    String workstationId = room.workstations.first.workstationId;
    String? selectedProblem;
    String? severity;
    String details = '';
    final key = GlobalKey<FormState>();
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            if (saving || !(key.currentState?.validate() ?? false)) return;
            final selectedSeverity = _severityForProblem(selectedProblem);
            if (selectedProblem == null || selectedSeverity == null) return;
            setDialogState(() => saving = true);
            try {
              await StaffService.instance.createTeacherReport(
                workstationId: workstationId,
                issue: selectedProblem!.trim(),
                details: details.trim(),
                severity: selectedSeverity,
              );
              if (!dialogContext.mounted || !mounted) return;
              Navigator.pop(dialogContext);
              _message('Damaged PC reported to ITSO.');
              _refresh();
            } catch (error) {
              if (dialogContext.mounted) setDialogState(() => saving = false);
              if (mounted) _message(cleanError(error));
            }
          }

          return AlertDialog(
            backgroundColor: _card,
            shape: _dialogShape,
            titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
            contentPadding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            title: _dialogTitle('Report Damaged PC', Icons.report_problem_rounded),
            content: SizedBox(
              width: 520,
              child: Form(
                key: key,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: workstationId,
                        dropdownColor: _card,
                        iconEnabledColor: _accentAForeground,
                        style: TextStyle(color: _text, fontSize: 14),
                        decoration: _dialogFieldDecoration(label: 'PC'),
                        items: room.workstations
                            .map((pc) => DropdownMenuItem(
                          value: pc.workstationId,
                          child: Text(pc.pcId),
                        ))
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(
                              () => workstationId = value ?? workstationId,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedProblem,
                        isExpanded: true,
                        dropdownColor: _card,
                        iconEnabledColor: _accentAForeground,
                        style: TextStyle(color: _text, fontSize: 14),
                        decoration: _dialogFieldDecoration(
                          label: 'Problem',
                          helperText: 'Select the closest matching problem.',
                        ),
                        items: _teacherProblemOptions
                            .map(
                              (problem) => DropdownMenuItem<String>(
                            value: problem.label,
                            child: Row(
                              children: [
                                Icon(problem.icon, size: 18, color: _accentAForeground),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    problem.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                          setDialogState(() {
                            selectedProblem = value;
                            severity = _severityForProblem(value);
                          });
                        },
                        validator: (value) => value == null
                            ? 'Select the workstation problem.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        enabled: !saving,
                        maxLines: 4,
                        style: TextStyle(color: _text, fontSize: 14),
                        cursorColor: _accentAForeground,
                        decoration: _dialogFieldDecoration(label: 'Details'),
                        onChanged: (value) => details = value,
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter report details.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      InputDecorator(
                        decoration: _dialogFieldDecoration(
                          label: 'Severity',
                          helperText:
                          'Severity is assigned automatically from the problem.',
                        ),
                        child: Row(
                          children: [
                            Icon(
                              severity == null
                                  ? Icons.auto_awesome_outlined
                                  : Icons.shield_rounded,
                              size: 18,
                              color: severity == null
                                  ? _sub
                                  : _severityColor(severity!),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              severity == null
                                  ? 'Select a problem first'
                                  : _severityLabel(severity!),
                              style: TextStyle(
                                color: severity == null
                                    ? _sub
                                    : _severityColor(severity!),
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              _dialogCancelButton(saving ? null : () => Navigator.pop(dialogContext)),
              _dialogPrimaryButton(
                label: saving ? 'Sending...' : 'Send to ITSO',
                onPressed: saving ? null : save,
                loading: saving,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showForwardDialog(FaultReport report) async {
    await _notesActionDialog(
      title: 'Send ${report.pcId} Report to ITSO',
      icon: Icons.send_rounded,
      label: 'Teacher observations',
      actionLabel: 'Send to ITSO',
      onSave: (notes) => StaffService.instance.forwardTeacherReport(
        reportId: report.id,
        notes: notes,
      ),
      reportId: report.id,
    );
  }

  Future<void> _showVerifyDialog(FaultReport report, bool approved) async {
    await _notesActionDialog(
      title: approved ? 'Confirm ${report.pcId} is Fixed' : 'Reopen ${report.pcId}',
      icon: approved ? Icons.check_circle_rounded : Icons.replay_rounded,
      label: approved ? 'Teacher verification notes' : 'Describe the remaining problem',
      actionLabel: approved ? 'Approve PC' : 'Return to ITSO',
      onSave: (notes) => StaffService.instance.verifyTeacherRepair(
        reportId: report.id,
        approved: approved,
        notes: notes,
      ),
      reportId: report.id,
    );
  }

  Future<void> _notesActionDialog({
    required String title,
    required IconData icon,
    required String label,
    required String actionLabel,
    required Future<void> Function(String notes) onSave,
    required String reportId,
  }) async {
    final key = GlobalKey<FormState>();
    bool saving = false;
    String notes = '';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            if (saving || !(key.currentState?.validate() ?? false)) return;
            setDialogState(() => saving = true);
            setState(() => _busyReports.add(reportId));
            try {
              await onSave(notes.trim());
              if (!dialogContext.mounted || !mounted) return;
              Navigator.pop(dialogContext);
              _message('Report updated successfully.');
              _refresh();
            } catch (error) {
              if (dialogContext.mounted) setDialogState(() => saving = false);
              if (mounted) _message(cleanError(error));
            } finally {
              if (mounted) setState(() => _busyReports.remove(reportId));
            }
          }

          return AlertDialog(
            backgroundColor: _card,
            shape: _dialogShape,
            titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
            contentPadding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            title: _dialogTitle(title, icon),
            content: SizedBox(
              width: 460,
              child: Form(
                key: key,
                child: TextFormField(
                  enabled: !saving,
                  maxLines: 4,
                  style: TextStyle(color: _text, fontSize: 14),
                  cursorColor: _accentAForeground,
                  decoration: _dialogFieldDecoration(label: label),
                  onChanged: (value) => notes = value,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter notes before continuing.'
                      : null,
                ),
              ),
            ),
            actions: [
              _dialogCancelButton(saving ? null : () => Navigator.pop(dialogContext)),
              _dialogPrimaryButton(
                label: saving ? 'Saving...' : actionLabel,
                onPressed: saving ? null : save,
                loading: saving,
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPcDetails(LabWorkstation pc) {
    final color = _conditionColor(pc.maintenanceColor);
    final connectionColor = pc.isOnline ? const Color(0xFF22A06B) : Colors.blueGrey;

    Widget row(IconData icon, String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (valueColor ?? _accentAForeground).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: valueColor ?? _accentAForeground),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: _sub, fontSize: 12.5),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? _text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape: _dialogShape,
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 4),
        contentPadding: const EdgeInsets.fromLTRB(22, 6, 22, 6),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.24)),
              ),
              child: Icon(Icons.computer_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              pc.pcId,
              style: TextStyle(
                color: _text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row(
                Icons.wifi_rounded,
                'Connection',
                pc.connectionStatus.toUpperCase(),
                valueColor: connectionColor,
              ),
              Divider(color: _border, height: 4),
              row(Icons.info_outline_rounded, 'Device status', pc.deviceStatus),
              Divider(color: _border, height: 4),
              row(
                Icons.report_outlined,
                'Active problems',
                '${pc.activeProblemCount}',
                valueColor: pc.activeProblemCount > 0 ? color : null,
              ),
              Divider(color: _border, height: 4),
              row(
                Icons.priority_high_rounded,
                'Major problems',
                '${pc.majorProblemCount}',
                valueColor: pc.majorProblemCount > 0 ? const Color(0xFFE53935) : null,
              ),
            ],
          ),
        ),
        actions: [
          _dialogCancelButton(() => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _emptyReports() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: _field.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF22A06B).withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF22A06B),
              size: 26,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No open reports',
            style: TextStyle(
              color: _text,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This laboratory currently has no unresolved teacher reports.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _sub, fontSize: 11.8),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Container(
        width: 430,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _errorColor.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _dark ? 0.14 : 0.04),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _errorColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 30, color: _errorColor),
            ),
            const SizedBox(height: 14),
            Text(
              'Unable to load dashboard',
              style: TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: _sub, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 18),
            _gradientButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _refresh,
            ),
          ],
        ),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentColor,
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 17,
                  color: _dark ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: _text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: _card,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: _accentAForeground.withValues(alpha: 0.35)),
          ),
        ),
      );
  }
}