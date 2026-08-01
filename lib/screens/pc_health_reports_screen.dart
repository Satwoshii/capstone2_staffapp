import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pc_health_record.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/message_state.dart';

class PcHealthReportsScreen extends StatefulWidget {
  const PcHealthReportsScreen({super.key});

  @override
  State<PcHealthReportsScreen> createState() => _PcHealthReportsScreenState();
}

class _PcHealthReportsScreenState extends State<PcHealthReportsScreen> {
  final _searchController = TextEditingController();
  Future<List<PcHealthRecord>>? _future;
  Timer? _timer;
  bool _issuesOnly = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
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
      _future = StaffService.instance.listPcHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search room, PC, status, or student',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    selected: _issuesOnly,
                    avatar: const Icon(Icons.warning_amber, size: 18),
                    label: const Text('Issues only'),
                    onSelected: (value) => setState(() => _issuesOnly = value),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<PcHealthRecord>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return MessageState(
                  icon: Icons.wifi_off,
                  title: 'Could not load PC health',
                  message: cleanError(snapshot.error!),
                  onRetry: _refresh,
                );
              }
              final search = _searchController.text.trim().toLowerCase();
              final records = (snapshot.data ?? const <PcHealthRecord>[])
                  .where((record) {
                final style = _styleForStatus(record.status);
                if (_issuesOnly && style.isHealthy) return false;
                if (search.isEmpty) return true;
                return [
                  record.roomName,
                  record.pcId,
                  record.status,
                  record.lastStudentEmail ?? '',
                  readableValue(record.details),
                ].join(' ').toLowerCase().contains(search);
              }).toList()
                ..sort((a, b) {
                  final aTime = a.lastCheck ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime = b.lastCheck ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });

              if (records.isEmpty) {
                return MessageState(
                  icon: Icons.monitor_heart_outlined,
                  title: _issuesOnly ? 'No matching issues' : 'No PC health records',
                  message: _issuesOnly
                      ? 'No unhealthy PCs match the filter.'
                      : 'Student PCs will appear after their first status sync.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final style = _styleForStatus(record.status);
                    final details = readableValue(record.details);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: style.color.withOpacity(0.14),
                          child: Icon(style.icon, color: style.color),
                        ),
                        title: Text('${record.roomName} - ${record.pcId}'),
                        subtitle: Text(
                          [
                            'Last check: ${formatDateTime(record.lastCheck)}',
                            if ((record.lastStudentEmail ?? '').isNotEmpty)
                              'Last student: ${record.lastStudentEmail}',
                            if (details.isNotEmpty) details,
                          ].join('\n'),
                        ),
                        trailing: Chip(
                          avatar: Icon(style.icon, size: 18, color: style.color),
                          label: Text(record.status.toUpperCase()),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HealthStyle {
  final IconData icon;
  final Color color;
  final bool isHealthy;

  const _HealthStyle(this.icon, this.color, this.isHealthy);
}

_HealthStyle _styleForStatus(String value) {
  final status = value.trim().toLowerCase();
  if (['healthy', 'ok', 'online', 'normal', 'working'].contains(status)) {
    return const _HealthStyle(Icons.check_circle, Colors.green, true);
  }
  if (status.contains('critical') ||
      status.contains('broken') ||
      status.contains('offline') ||
      status.contains('failed')) {
    return const _HealthStyle(Icons.error, Colors.red, false);
  }
  if (status.contains('minor') ||
      status.contains('warning') ||
      status.contains('degraded')) {
    return const _HealthStyle(Icons.warning_amber, Colors.orange, false);
  }
  return const _HealthStyle(Icons.help_outline, Colors.blueGrey, false);
}
