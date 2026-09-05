import 'dart:async';

import 'package:flutter/material.dart';

import '../models/dashboard_summary.dart';
import '../models/fault_report.dart';
import '../models/pc_health_record.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/message_state.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Future<_ReportData>? _future;
  Timer? _timer;
  String _severityFilter = 'All';
  String _quickFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _busyIds = {};

  // ── Palette (matches the rest of the app) ───────────────────────────────
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _cardColor => _isDarkMode ? const Color(0xFF13141A) : Colors.white;
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

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _future = Future.wait<dynamic>([
        StaffService.instance.dashboard(),
        StaffService.instance.listFaultReports(),
        StaffService.instance.listPcHealth(),
      ]).then(
            (values) => _ReportData(
          summary: values[0] as DashboardSummary,
          faults: values[1] as List<FaultReport>,
          health: values[2] as List<PcHealthRecord>,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReportData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_accentAForeground),
            ),
          );
        }
        if (snapshot.hasError) {
          return MessageState(
            icon: Icons.wifi_off,
            title: 'Could not load reports',
            message: cleanError(snapshot.error!),
            onRetry: _refresh,
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const MessageState(
            icon: Icons.analytics_outlined,
            title: 'No report data',
            message: 'The server did not return report information.',
          );
        }

        final recentFaults = data.faults.toList()
          ..sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

        final filteredFaults = recentFaults.where((f) {
          // 1. Severity filter
          bool matchesSeverity = true;
          if (_severityFilter != 'All') {
            final major = _isMajor(f.severity);
            matchesSeverity = (_severityFilter == 'Major' ? major : !major);
          }

          // 2. Search filter
          final query = _searchController.text.toLowerCase().trim();
          bool matchesSearch = true;
          if (query.isNotEmpty) {
            matchesSearch = f.issue.toLowerCase().contains(query) ||
                f.details.toLowerCase().contains(query) ||
                f.roomName.toLowerCase().contains(query) ||
                f.pcId.toLowerCase().contains(query);
          }

          // 3. Quick filter (Stat Cards)
          bool matchesQuick = true;
          if (_quickFilter == 'Open') {
            matchesQuick = !f.repaired;
          } else if (_quickFilter == 'Repaired') {
            matchesQuick = f.repaired;
          } else if (_quickFilter == 'Students') {
            matchesQuick = f.studentEmail != null;
          } else if (_quickFilter == 'Login') {
            matchesQuick = f.issue.toLowerCase().contains('login') ||
                f.details.toLowerCase().contains('login');
          } else if (_quickFilter == 'Online') {
            // Find if this workstation is currently online
            final health = data.health.firstWhere(
              (h) => h.workstationId == f.workstationId,
              orElse: () => const PcHealthRecord(
                id: '',
                workstationId: '',
                roomName: '',
                pcId: '',
                status: 'offline',
              ),
            );
            matchesQuick = health.status.toLowerCase() == 'online';
          }

          return matchesSeverity && matchesSearch && matchesQuick;
        }).toList();

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          color: _accentAForeground,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Live totals from the central MariaDB database.',
                      style: TextStyle(color: _subTextColor, fontSize: 13),
                    ),
                  ),
                  _buildRefreshButton(),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _statCard(
                    title: 'Workstations',
                    value: data.summary.workstations.toString(),
                    icon: Icons.computer_rounded,
                    color: _accentBForeground,
                    isSelected: _quickFilter == 'All',
                    onTap: () => setState(() => _quickFilter = 'All'),
                  ),
                  _statCard(
                    title: 'Online',
                    value: data.summary.onlineWorkstations.toString(),
                    icon: Icons.lan_rounded,
                    color: _accentAForeground,
                    isSelected: _quickFilter == 'Online',
                    onTap: () => setState(() => _quickFilter = 'Online'),
                  ),
                  _statCard(
                    title: 'Open Faults',
                    value: data.summary.openFaults.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFF7B84F),
                    isSelected: _quickFilter == 'Open',
                    onTap: () => setState(() => _quickFilter = 'Open'),
                  ),
                  _statCard(
                    title: 'Repaired',
                    value: data.summary.repairedFaults.toString(),
                    icon: Icons.build_circle_rounded,
                    color: _accentAForeground,
                    isSelected: _quickFilter == 'Repaired',
                    onTap: () => setState(() => _quickFilter = 'Repaired'),
                  ),
                  _statCard(
                    title: 'Students',
                    value: data.summary.students.toString(),
                    icon: Icons.school_rounded,
                    color: _accentBForeground,
                    isSelected: _quickFilter == 'Students',
                    onTap: () => setState(() => _quickFilter = 'Students'),
                  ),
                  _statCard(
                    title: 'Login Logs',
                    value: data.summary.loginLogs.toString(),
                    icon: Icons.login_rounded,
                    color: const Color(0xFFB98CF7),
                    isSelected: _quickFilter == 'Login',
                    onTap: () => setState(() => _quickFilter = 'Login'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSearchBar(),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Fault Reports',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _buildFilterChips(),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredFaults.isEmpty)
                _buildEmptyFaultsCard()
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredFaults.length > 12 ? 12 : filteredFaults.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    mainAxisExtent: 280,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemBuilder: (context, index) {
                    return _buildFaultCard(filteredFaults[index]);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: IconButton(
        tooltip: 'Refresh',
        onPressed: _refresh,
        icon: Icon(Icons.refresh_rounded, color: _accentBForeground, size: 20),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() {}),
        style: TextStyle(color: _textColor, fontSize: 14.5),
        decoration: InputDecoration(
          hintText: 'Search issue, room, or PC ID...',
          hintStyle: TextStyle(color: _subTextColor, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: _subTextColor, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: _subTextColor, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ['All', 'Major', 'Minor'].map((label) {
        final isSelected = _severityFilter == label;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: InkWell(
            onTap: () => setState(() => _severityFilter = label),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? _accentAForeground : _fieldColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.transparent : _borderColor,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? (_isDarkMode ? _accentB : Colors.white)
                      : _subTextColor,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _isMajor(String severity) {
    final s = severity.toLowerCase();
    return s == 'high' || s == 'critical' || s == 'emergency';
  }

  Color _severityColor(String severity, bool repaired) {
    if (repaired) return _accentAForeground;
    if (_isMajor(severity)) return const Color(0xFFFF6B6B);
    return const Color(0xFFF7B84F);
  }

  Future<void> _updateStatus(FaultReport report, bool repaired, String notes) async {
    if (_busyIds.contains(report.id)) return;
    setState(() => _busyIds.add(report.id));

    try {
      if (repaired) {
        await StaffService.instance.markRepaired(
          reportId: report.id,
          notes: notes,
        );
      } else {
        // Reopening a repaired PC
        await StaffService.instance.verifyTeacherRepair(
          reportId: report.id,
          approved: false,
          notes: notes,
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(report.id));
      }
    }
  }

  void _showActionDialog(FaultReport report, bool markRepaired) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          markRepaired ? 'Mark as Repaired' : 'Report Still Damaged',
          style: TextStyle(color: _textColor, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              markRepaired
                  ? 'Please provide notes about the repair.'
                  : 'Describe what is still broken on this PC.',
              style: TextStyle(color: _subTextColor, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              style: TextStyle(color: _textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: _fieldColor,
                hintText: 'Enter notes here...',
                hintStyle: TextStyle(color: _subTextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _borderColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _subTextColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(report, markRepaired, controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: markRepaired ? _accentAForeground : const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(markRepaired ? 'Confirm Repair' : 'Reopen Case'),
          ),
        ],
      ),
    );
  }

  // ── Stat card ────────────────────────────────────────────────────────────
  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : _borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.14),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(color: _subTextColor, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFaultsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Center(
        child: Text(
          'No fault reports have been received.',
          style: TextStyle(color: _subTextColor, fontSize: 13.5),
        ),
      ),
    );
  }

  // ── Fault report card ────────────────────────────────────────────────────
  Widget _buildFaultCard(FaultReport report) {
    final color = _severityColor(report.severity, report.repaired);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.14),
                ),
                child: Icon(
                  report.repaired ? Icons.check_rounded : Icons.warning_amber_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room ${report.roomName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'PC ID: ${report.pcId}',
                      style: TextStyle(
                        color: _subTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(report),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            report.issue,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (report.details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                report.details,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _subTextColor, fontSize: 12.5),
              ),
            ),
          const Spacer(),
          Text(
            'Reported: ${formatDateTime(report.createdAt)}'
            '${report.queuePosition != null ? '\nFIFO Queue: #${report.queuePosition}${report.queueTotal != null ? ' of ${report.queueTotal}' : ''}' : ''}'
            '${report.acceptedByName != null ? '\nAccepted by: ${report.acceptedByName} · ${formatDateTime(report.acceptedAt)}' : ''}'
            '${report.handledByName != null ? '\nHandled by: ${report.handledByName} · ${formatDateTime(report.handledAt)}' : ''}'
            '${report.completedByName != null ? '\nCompleted by: ${report.completedByName} · ${formatDateTime(report.completedAt)}' : ''}',
            style: TextStyle(color: _subTextColor, fontSize: 11),
          ),
          const SizedBox(height: 12),
          _buildActionButtons(report),
        ],
      ),
    );
  }

  Widget _buildActionButtons(FaultReport report) {
    if (_busyIds.contains(report.id)) {
      return SizedBox(
        height: 32,
        width: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(_accentAForeground),
        ),
      );
    }

    if (!report.repaired) {
      if (report.workflowStatus == 'sent_to_itso' ||
          report.workflowStatus == 'reopened') {
        final position = report.queuePosition;
        return _queueStatusChip(
          position == 1
              ? 'Queue #1 · Ready in Repair Queue'
              : position != null
                  ? 'Queue #$position · Waiting'
                  : 'Waiting in FIFO Queue',
          position == 1 ? Icons.looks_one_rounded : Icons.hourglass_top_rounded,
        );
      }

      if (report.workflowStatus == 'reported') {
        return _queueStatusChip('Teacher Review', Icons.rate_review_rounded);
      }

      if (report.workflowStatus == 'awaiting_teacher_approval') {
        return _queueStatusChip('Awaiting Teacher', Icons.school_rounded);
      }

      if (report.workflowStatus == 'in_repair') {
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _actionButton(
              label: 'Mark Repaired',
              icon: Icons.check_circle_rounded,
              color: _accentAForeground,
              onTap: () => _showActionDialog(report, true),
            ),
          ],
        );
      }

      return _queueStatusChip('Open Report', Icons.pending_actions_rounded);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _actionButton(
          label: 'Still Damaged',
          icon: Icons.report_problem_rounded,
          color: const Color(0xFFFF6B6B),
          onTap: () => _showActionDialog(report, false),
        ),
      ],
    );
  }

  Widget _queueStatusChip(String label, IconData icon) {
    final color = _accentAForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(FaultReport report) {
    final color = _severityColor(report.severity, report.repaired);
    final label = report.repaired
        ? 'REPAIRED'
        : report.severity.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ReportData {
  final DashboardSummary summary;
  final List<FaultReport> faults;
  final List<PcHealthRecord> health;

  const _ReportData({
    required this.summary,
    required this.faults,
    required this.health,
  });
}
