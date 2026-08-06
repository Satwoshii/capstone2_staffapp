import 'dart:async';

import 'package:flutter/material.dart';

import '../models/dashboard_summary.dart';
import '../models/fault_report.dart';
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

  // ── Palette (matches the rest of the app) ───────────────────────────────
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _cardColor => _isDarkMode ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor =>
      _isDarkMode ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _accentA => const Color(0xFF2EE6C5);
  Color get _accentB => const Color(0xFF4F8EF7);
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
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _future = Future.wait<dynamic>([
        StaffService.instance.dashboard(),
        StaffService.instance.listFaultReports(),
      ]).then(
            (values) => _ReportData(
          summary: values[0] as DashboardSummary,
          faults: values[1] as List<FaultReport>,
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
              valueColor: AlwaysStoppedAnimation<Color>(_accentA),
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

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          color: _accentA,
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
                    color: _accentB,
                  ),
                  _statCard(
                    title: 'Online',
                    value: data.summary.onlineWorkstations.toString(),
                    icon: Icons.lan_rounded,
                    color: _accentA,
                  ),
                  _statCard(
                    title: 'Open Faults',
                    value: data.summary.openFaults.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFF7B84F),
                  ),
                  _statCard(
                    title: 'Repaired',
                    value: data.summary.repairedFaults.toString(),
                    icon: Icons.build_circle_rounded,
                    color: _accentA,
                  ),
                  _statCard(
                    title: 'Students',
                    value: data.summary.students.toString(),
                    icon: Icons.school_rounded,
                    color: _accentB,
                  ),
                  _statCard(
                    title: 'Login Logs',
                    value: data.summary.loginLogs.toString(),
                    icon: Icons.login_rounded,
                    color: const Color(0xFFB98CF7),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Recent Fault Reports',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (recentFaults.isEmpty)
                _buildEmptyFaultsCard()
              else
                for (final report in recentFaults.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildFaultCard(report),
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
        icon: Icon(Icons.refresh_rounded, color: _accentB, size: 20),
      ),
    );
  }

  // ── Stat card ────────────────────────────────────────────────────────────
  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
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
    final color = report.repaired ? _accentA : const Color(0xFFF7B84F);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${report.roomName} · ${report.pcId}',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _buildStatusBadge(report.repaired, color),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  report.issue,
                  style: TextStyle(color: _textColor.withValues(alpha: 0.85), fontSize: 13),
                ),
                if (report.details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      report.details,
                      style: TextStyle(color: _subTextColor, fontSize: 12.5),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  formatDateTime(report.createdAt),
                  style: TextStyle(color: _subTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool repaired, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        repaired ? 'REPAIRED' : 'OPEN',
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

  const _ReportData({required this.summary, required this.faults});
}