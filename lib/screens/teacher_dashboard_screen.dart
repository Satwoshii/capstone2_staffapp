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
    await StaffService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
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
          Column(
            children: [
              _topBar(),
              Expanded(
                child: FutureBuilder<(LabOverview, List<FaultReport>)>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
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

  Widget _topBar() {
    final room = widget.user.assignedRoomName ?? 'Unassigned';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: Color(0xFF4F8EF7), size: 30),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Syswatch Teacher',
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('Room $room', style: TextStyle(color: _sub, fontSize: 12)),
            ],
          ),
          const Spacer(),
          Text(widget.user.displayName, style: TextStyle(color: _text)),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: _openChat,
            icon: const Icon(Icons.forum_rounded),
            label: const Text('Chat with ITSO'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
          ),
        ],
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
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 80),
        children: [
          _roomHeader(room, color),
          const SizedBox(height: 18),
          Text(
            'LAB MAP',
            style: TextStyle(
              color: _sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 8
                  : constraints.maxWidth >= 760
                      ? 6
                      : 4;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                ),
                itemCount: room.workstations.length,
                itemBuilder: (context, index) =>
                    _pcTile(room.workstations[index]),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ROOM REPORTS (${openReports.length} OPEN)',
                  style: TextStyle(
                    color: _sub,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: room.workstations.isEmpty
                    ? null
                    : () => _showCreateReport(room),
                icon: const Icon(Icons.report_problem_rounded),
                label: const Text('Report Damaged PC'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (openReports.isEmpty)
            _emptyReports()
          else
            for (final report in openReports) _reportCard(report),
        ],
      ),
    );
  }

  Widget _roomHeader(LabOverview room, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.meeting_room_rounded, color: color, size: 34),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laboratory ${room.roomName}',
                  style: TextStyle(
                    color: _text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  room.maintenanceColor == 'green'
                      ? 'All reported checks are clear.'
                      : room.maintenanceColor == 'yellow'
                          ? 'The room has 1–3 active minor problems.'
                          : 'The room has many problems or a high/critical problem.',
                  style: TextStyle(color: _sub),
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
            const Color(0xFF4F8EF7),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, int value, Color color) {
    return Container(
      width: 88,
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(color: color, fontSize: 21, fontWeight: FontWeight.w800),
          ),
          Text(label, style: TextStyle(color: _sub, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _pcTile(LabWorkstation pc) {
    final color = _conditionColor(pc.maintenanceColor);
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => _showPcDetails(pc),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.75), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.computer_rounded, color: color, size: 27),
            const SizedBox(height: 5),
            Text(
              pc.pcId,
              style: TextStyle(color: _text, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              pc.isOnline ? 'ONLINE' : 'OFFLINE',
              style: TextStyle(
                color: pc.isOnline ? const Color(0xFF22A06B) : Colors.blueGrey,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(FaultReport report) {
    final busy = _busyReports.contains(report.id);
    final severityColor = _severityColor(report.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.report_rounded, color: severityColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.pcId} · ${report.issue}',
                  style: TextStyle(color: _text, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(report.details, style: TextStyle(color: _sub)),
                const SizedBox(height: 6),
                Text(
                  '${report.severity.toUpperCase()} · ${_workflowLabel(report.workflowStatus)}',
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (report.workflowStatus == 'reported' ||
              report.workflowStatus == 'reopened')
            OutlinedButton.icon(
              onPressed: () => _showForwardDialog(report),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send to ITSO'),
            )
          else if (report.workflowStatus == 'awaiting_teacher_approval')
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _showVerifyDialog(report, false),
                  child: const Text('Still Damaged'),
                ),
                FilledButton(
                  onPressed: () => _showVerifyDialog(report, true),
                  child: const Text('PC is OK'),
                ),
              ],
            ),
        ],
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

  String _workflowLabel(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  Future<void> _showCreateReport(LabOverview room) async {
    String workstationId = room.workstations.first.workstationId;
    String severity = 'medium';
    String issue = '';
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
            setDialogState(() => saving = true);
            try {
              await StaffService.instance.createTeacherReport(
                workstationId: workstationId,
                issue: issue.trim(),
                details: details.trim(),
                severity: severity,
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
            title: const Text('Report Damaged PC'),
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
                        decoration: const InputDecoration(labelText: 'PC'),
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
                      const SizedBox(height: 12),
                      TextFormField(
                        enabled: !saving,
                        decoration: const InputDecoration(labelText: 'Problem'),
                        onChanged: (value) => issue = value,
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Describe the problem.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        enabled: !saving,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Details'),
                        onChanged: (value) => details = value,
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter report details.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: severity,
                        decoration: const InputDecoration(labelText: 'Severity'),
                        items: const [
                          DropdownMenuItem(value: 'minor', child: Text('Minor')),
                          DropdownMenuItem(value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(value: 'critical', child: Text('Critical')),
                          DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
                        ],
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(
                                  () => severity = value ?? severity,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Sending...' : 'Send to ITSO'),
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
            title: Text(title),
            content: SizedBox(
              width: 460,
              child: Form(
                key: key,
                child: TextFormField(
                  enabled: !saving,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: label),
                  onChanged: (value) => notes = value,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter notes before continuing.'
                      : null,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving...' : actionLabel),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPcDetails(LabWorkstation pc) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: Text(pc.pcId),
        content: Text(
          'Connection: ${pc.connectionStatus.toUpperCase()}\n'
          'Device status: ${pc.deviceStatus}\n'
          'Active problems: ${pc.activeProblemCount}\n'
          'Major problems: ${pc.majorProblemCount}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _emptyReports() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Center(
        child: Text('No open reports in this room.', style: TextStyle(color: _sub)),
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 52),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
