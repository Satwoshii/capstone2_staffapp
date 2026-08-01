import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/fault_report.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/message_state.dart';

class RepairManagementScreen extends StatefulWidget {
  final AppUser user;

  const RepairManagementScreen({super.key, required this.user});

  @override
  State<RepairManagementScreen> createState() => _RepairManagementScreenState();
}

class _RepairManagementScreenState extends State<RepairManagementScreen> {
  final _searchController = TextEditingController();
  final _updating = <String>{};
  Future<List<FaultReport>>? _future;
  Timer? _timer;
  bool _showRepaired = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
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
      _future = StaffService.instance.listFaultReports();
    });
  }

  Future<void> _markRepaired(FaultReport report) async {
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (saving || !(formKey.currentState?.validate() ?? false)) return;
              setDialogState(() => saving = true);
              setState(() => _updating.add(report.id));
              try {
                await StaffService.instance.markRepaired(
                  reportId: report.id,
                  notes: notesController.text,
                );
                if (!dialogContext.mounted || !mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Report marked as repaired.')),
                );
                _refresh();
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() => saving = false);
                }
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(cleanError(error))),
                  );
                }
              } finally {
                if (mounted) setState(() => _updating.remove(report.id));
              }
            }

            return AlertDialog(
              title: const Text('Mark Report Repaired'),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${report.roomName} - ${report.pcId}'),
                      const SizedBox(height: 4),
                      Text(report.issue),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: notesController,
                        enabled: !saving,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Technician Notes / Action Taken',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter the repair action or notes.'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(saving ? 'Saving...' : 'Confirm Repair'),
                ),
              ],
            );
          },
        );
      },
    );
    notesController.dispose();
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
                        labelText: 'Search room, PC, issue, or student',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    selected: _showRepaired,
                    label: const Text('Include repaired'),
                    avatar: const Icon(Icons.history, size: 18),
                    onSelected: (value) => setState(() => _showRepaired = value),
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
          child: FutureBuilder<List<FaultReport>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return MessageState(
                  icon: Icons.wifi_off,
                  title: 'Could not load repairs',
                  message: cleanError(snapshot.error!),
                  onRetry: _refresh,
                );
              }

              final search = _searchController.text.trim().toLowerCase();
              final reports = (snapshot.data ?? const <FaultReport>[])
                  .where((report) {
                if (!_showRepaired && report.repaired) return false;
                if (search.isEmpty) return true;
                return [
                  report.roomName,
                  report.pcId,
                  report.issue,
                  report.details,
                  report.studentEmail ?? '',
                  report.severity,
                ].join(' ').toLowerCase().contains(search);
              }).toList()
                ..sort((a, b) {
                  if (a.repaired != b.repaired) return a.repaired ? 1 : -1;
                  final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });

              if (reports.isEmpty) {
                return const MessageState(
                  icon: Icons.build_circle_outlined,
                  title: 'No matching repair reports',
                  message: 'Open fault reports from Student PCs will appear here.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final updating = _updating.contains(report.id);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (report.repaired
                                  ? Colors.green
                                  : _severityColor(report.severity))
                              .withOpacity(0.14),
                          child: Icon(
                            report.repaired ? Icons.check_circle : Icons.build,
                            color: report.repaired
                                ? Colors.green
                                : _severityColor(report.severity),
                          ),
                        ),
                        title: Text('${report.roomName} - ${report.pcId}'),
                        subtitle: Text(
                          [
                            report.issue,
                            if (report.details.isNotEmpty) report.details,
                            'Severity: ${report.severity.toUpperCase()}',
                            if ((report.studentEmail ?? '').isNotEmpty)
                              'Student: ${report.studentEmail}',
                            'Reported: ${formatDateTime(report.createdAt)}',
                            if (report.repaired)
                              'Repaired: ${formatDateTime(report.repairedAt)}',
                            if ((report.technicianNotes ?? '').isNotEmpty)
                              'Action: ${report.technicianNotes}',
                          ].join('\n'),
                        ),
                        trailing: report.repaired
                            ? const Chip(
                                avatar: Icon(Icons.check, size: 18),
                                label: Text('Repaired'),
                              )
                            : FilledButton.icon(
                                onPressed: updating
                                    ? null
                                    : () => _markRepaired(report),
                                icon: updating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.build, size: 18),
                                label: const Text('Mark Repaired'),
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

Color _severityColor(String value) {
  switch (value.trim().toLowerCase()) {
    case 'critical':
    case 'high':
      return Colors.red;
    case 'low':
    case 'minor':
      return Colors.amber.shade800;
    default:
      return Colors.orange;
  }
}
