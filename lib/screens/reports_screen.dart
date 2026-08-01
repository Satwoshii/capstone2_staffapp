import 'dart:async';

import 'package:flutter/material.dart';

import '../models/dashboard_summary.dart';
import '../models/fault_report.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/message_state.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Future<_ReportData>? _future;
  Timer? _timer;

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
          return const Center(child: CircularProgressIndicator());
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Live totals from the central MariaDB database.',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  DashboardCard(
                    title: 'Workstations',
                    value: data.summary.workstations.toString(),
                    icon: Icons.computer,
                    color: Colors.blue,
                  ),
                  DashboardCard(
                    title: 'Online',
                    value: data.summary.onlineWorkstations.toString(),
                    icon: Icons.lan,
                    color: Colors.green,
                  ),
                  DashboardCard(
                    title: 'Open Faults',
                    value: data.summary.openFaults.toString(),
                    icon: Icons.warning_amber,
                    color: Colors.orange,
                  ),
                  DashboardCard(
                    title: 'Repaired',
                    value: data.summary.repairedFaults.toString(),
                    icon: Icons.build_circle,
                    color: Colors.teal,
                  ),
                  DashboardCard(
                    title: 'Students',
                    value: data.summary.students.toString(),
                    icon: Icons.school,
                    color: Colors.indigo,
                  ),
                  DashboardCard(
                    title: 'Login Logs',
                    value: data.summary.loginLogs.toString(),
                    icon: Icons.login,
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Recent Fault Reports',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (recentFaults.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No fault reports have been received.'),
                  ),
                )
              else
                for (final report in recentFaults.take(10))
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: report.repaired
                            ? Colors.green.withOpacity(0.14)
                            : Colors.orange.withOpacity(0.14),
                        child: Icon(
                          report.repaired ? Icons.check : Icons.warning_amber,
                          color: report.repaired ? Colors.green : Colors.orange,
                        ),
                      ),
                      title: Text('${report.roomName} - ${report.pcId}'),
                      subtitle: Text(
                        [
                          report.issue,
                          if (report.details.isNotEmpty) report.details,
                          formatDateTime(report.createdAt),
                        ].join('\n'),
                      ),
                      trailing: Chip(
                        label: Text(report.repaired ? 'REPAIRED' : 'OPEN'),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportData {
  final DashboardSummary summary;
  final List<FaultReport> faults;

  const _ReportData({required this.summary, required this.faults});
}
