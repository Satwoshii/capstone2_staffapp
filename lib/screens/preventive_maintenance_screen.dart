import 'dart:async';

import 'package:flutter/material.dart';

import '../models/maintenance_record.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/message_state.dart';

class PreventiveMaintenanceScreen extends StatefulWidget {
  const PreventiveMaintenanceScreen({super.key});

  @override
  State<PreventiveMaintenanceScreen> createState() =>
      _PreventiveMaintenanceScreenState();
}

class _PreventiveMaintenanceScreenState
    extends State<PreventiveMaintenanceScreen> {
  static const Map<String, String> _checklistLabels = {
    'system_unit_cleaned': 'System unit and ventilation cleaned',
    'keyboard_cleaned': 'Keyboard inspected and cleaned',
    'mouse_cleaned': 'Mouse inspected and cleaned',
    'monitor_cleaned': 'Monitor inspected and cleaned',
    'cables_secured': 'Power and display cables checked',
    'ethernet_tested': 'Ethernet cable and LAN tested',
    'cpu_tested': 'CPU health and temperature checked',
    'ram_tested': 'RAM health checked',
    'disk_health_checked': 'Disk health checked',
    'storage_space_checked': 'Available storage checked',
    'os_updates_checked': 'Operating system updates checked',
    'antivirus_scan_checked': 'Security/antivirus scan completed',
  };

  final _searchController = TextEditingController();
  Future<List<MaintenanceSchedule>>? _future;
  Timer? _timer;
  String _filter = 'all';
  final Set<String> _saving = <String>{};

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _card => _isDark ? const Color(0xFF13141A) : Colors.white;
  Color get _field =>
      _isDark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _text => _isDark ? Colors.white : const Color(0xFF1A1C1E);
  Color get _sub => _isDark ? Colors.white54 : Colors.black45;
  Color get _border => _isDark
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.09);
  Color get _teal => const Color(0xFF2EE6C5);
  Color get _blue => const Color(0xFF4F8EF7);
  Color get _amber => const Color(0xFFF7B84F);
  Color get _red => const Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
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
      _future = StaffService.instance.listMaintenanceSchedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MaintenanceSchedule>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_teal),
            ),
          );
        }
        if (snapshot.hasError) {
          return MessageState(
            icon: Icons.event_busy_rounded,
            title: 'Could not load maintenance schedule',
            message: cleanError(snapshot.error!),
            onRetry: _refresh,
          );
        }

        final all = snapshot.data ?? const <MaintenanceSchedule>[];
        final query = _searchController.text.trim().toLowerCase();
        final filtered = all.where((item) {
          if (_filter != 'all' && item.scheduleStatus != _filter) return false;
          if (query.isEmpty) return true;
          return '${item.roomName} ${item.pcId} ${item.workstationId}'
              .toLowerCase()
              .contains(query);
        }).toList()
          ..sort((a, b) {
            final aDate = a.nextDueDate ?? DateTime(9999);
            final bDate = b.nextDueDate ?? DateTime(9999);
            return aDate.compareTo(bDate);
          });

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
              child: Column(
                children: [
                  _summaryRow(all),
                  const SizedBox(height: 12),
                  _toolbar(),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? MessageState(
                      icon: Icons.fact_check_outlined,
                      title: all.isEmpty
                          ? 'No registered workstations'
                          : 'No matching maintenance records',
                      message: all.isEmpty
                          ? 'Registered Student PCs will appear here automatically.'
                          : 'Change the search text or status filter.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      color: _teal,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _scheduleCard(filtered[index]),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryRow(List<MaintenanceSchedule> records) {
    final overdue = records.where((item) => item.isOverdue).length;
    final dueSoon = records.where((item) => item.isDueSoon).length;
    final upToDate = records.where((item) => item.isUpToDate).length;
    return Row(
      children: [
        _summaryTile('All PCs', records.length, Icons.computer_rounded, _blue),
        const SizedBox(width: 10),
        _summaryTile('Overdue', overdue, Icons.warning_amber_rounded, _red),
        const SizedBox(width: 10),
        _summaryTile('Due in 30 days', dueSoon, Icons.schedule_rounded, _amber),
        const SizedBox(width: 10),
        _summaryTile('Up to date', upToDate, Icons.verified_rounded, _teal),
      ],
    );
  }

  Widget _summaryTile(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    color: _text,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(label, style: TextStyle(color: _sub, fontSize: 11.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: _text, fontSize: 14),
            cursorColor: _teal,
            decoration: InputDecoration(
              labelText: 'Search room or PC',
              labelStyle: TextStyle(color: _sub, fontSize: 13.5),
              prefixIcon: Icon(Icons.search_rounded, color: _sub, size: 20),
              filled: true,
              fillColor: _field,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _teal, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        for (final filter in const <String, String>{
          'all': 'All',
          'overdue': 'Overdue',
          'due_soon': 'Due soon',
          'up_to_date': 'Up to date',
        }.entries) ...[
          _filterChip(filter.key, filter.value),
          const SizedBox(width: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: _field,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: Icon(Icons.refresh_rounded, color: _blue, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? _teal.withValues(alpha: 0.14) : _field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _teal.withValues(alpha: 0.45) : _border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _teal : _sub,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _scheduleCard(MaintenanceSchedule item) {
    final color = _statusColor(item.scheduleStatus);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.13),
            ),
            child: Icon(Icons.home_repair_service_rounded, color: color, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.roomName} · ${item.pcId}',
                  style: TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.lastMaintenanceDate == null
                      ? 'No preventive maintenance recorded'
                      : 'Last: ${_dateOnly(item.lastMaintenanceDate)} · ${item.lastTechnicianName ?? 'Staff'}',
                  style: TextStyle(color: _sub, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEXT DUE', style: TextStyle(color: _sub, fontSize: 10.5)),
                const SizedBox(height: 3),
                Text(
                  _dateOnly(item.nextDueDate),
                  style: TextStyle(
                    color: _text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _statusBadge(item),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => _showHistory(item),
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              side: BorderSide(color: _blue.withValues(alpha: 0.35)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.history_rounded, size: 17),
            label: const Text('History'),
          ),
          const SizedBox(width: 8),
          _gradientButton(
            label: 'Record Maintenance',
            loading: _saving.contains(item.workstationId),
            onPressed: _saving.contains(item.workstationId)
                ? null
                : () => _showMaintenanceForm(item),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(MaintenanceSchedule item) {
    final color = _statusColor(item.scheduleStatus);
    String label;
    if (item.isOverdue) {
      label = '${item.daysUntilDue.abs()} day(s) overdue';
    } else if (item.isDueSoon) {
      label = item.daysUntilDue <= 0 ? 'Due today' : 'Due in ${item.daysUntilDue} day(s)';
    } else {
      label = 'Up to date';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _showMaintenanceForm(MaintenanceSchedule item) async {
    final checklist = <String, bool>{
      for (final key in _checklistLabels.keys) key: false,
    };
    String findings = '';
    String actions = '';
    String recommendations = '';
    String condition = 'good';
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            if (saving) return;
            if (checklist.values.any((checked) => !checked)) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('Complete every inspection item before saving.'),
                ),
              );
              return;
            }
            if (condition != 'good' && findings.trim().isEmpty) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('Describe the findings for this PC condition.'),
                ),
              );
              return;
            }

            setDialogState(() => saving = true);
            setState(() => _saving.add(item.workstationId));
            try {
              await StaffService.instance.completePreventiveMaintenance(
                workstationId: item.workstationId,
                checklist: checklist,
                overallCondition: condition,
                findings: findings.trim(),
                actionsTaken: actions.trim(),
                recommendations: recommendations.trim(),
              );
              if (!dialogContext.mounted || !mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Quarterly maintenance saved. The next due date is three months from today.',
                  ),
                ),
              );
              _refresh();
            } catch (error) {
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(cleanError(error))),
                );
              }
            } finally {
              if (mounted) setState(() => _saving.remove(item.workstationId));
            }
          }

          return Dialog(
            backgroundColor: _card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _border),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fact_check_rounded, color: _teal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Quarterly Maintenance · ${item.roomName} ${item.pcId}',
                            style: TextStyle(
                              color: _text,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: saving ? null : () => Navigator.pop(dialogContext),
                          icon: Icon(Icons.close_rounded, color: _sub),
                        ),
                      ],
                    ),
                    Text(
                      'Inspect every item. Checked means the item was examined, not necessarily that it passed.',
                      style: TextStyle(color: _sub, fontSize: 12.5),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'PREVENTIVE MAINTENANCE CHECKLIST',
                                  style: TextStyle(
                                    color: _sub,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: saving
                                      ? null
                                      : () => setDialogState(() {
                                            for (final key in checklist.keys) {
                                              checklist[key] = true;
                                            }
                                          }),
                                  child: const Text('Check all'),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _checklistLabels.entries.map((entry) {
                                final checked = checklist[entry.key] ?? false;
                                return SizedBox(
                                  width: 340,
                                  child: CheckboxListTile(
                                    value: checked,
                                    enabled: !saving,
                                    onChanged: (value) => setDialogState(
                                      () => checklist[entry.key] = value ?? false,
                                    ),
                                    activeColor: _teal,
                                    checkColor: const Color(0xFF080A0E),
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: _border),
                                    ),
                                    title: Text(
                                      entry.value,
                                      style: TextStyle(color: _text, fontSize: 12.5),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: condition,
                              decoration: _inputDecoration('Overall PC condition'),
                              dropdownColor: _card,
                              style: TextStyle(color: _text),
                              items: const [
                                DropdownMenuItem(value: 'good', child: Text('Good / Healthy')),
                                DropdownMenuItem(
                                  value: 'needs_attention',
                                  child: Text('Needs attention'),
                                ),
                                DropdownMenuItem(value: 'critical', child: Text('Critical')),
                              ],
                              onChanged: saving
                                  ? null
                                  : (value) => setDialogState(
                                        () => condition = value ?? 'good',
                                      ),
                            ),
                            const SizedBox(height: 10),
                            _notesField(
                              'Findings / problems observed',
                              3,
                              (value) => findings = value,
                            ),
                            const SizedBox(height: 10),
                            _notesField(
                              'Actions taken',
                              3,
                              (value) => actions = value,
                            ),
                            const SizedBox(height: 10),
                            _notesField(
                              'Recommendations / parts needed',
                              3,
                              (value) => recommendations = value,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: saving ? null : () => Navigator.pop(dialogContext),
                          child: Text('Cancel', style: TextStyle(color: _sub)),
                        ),
                        const SizedBox(width: 8),
                        _gradientButton(
                          label: 'Complete Maintenance',
                          loading: saving,
                          onPressed: saving ? null : save,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _notesField(
    String label,
    int lines,
    ValueChanged<String> onChanged,
  ) {
    return TextField(
      maxLines: lines,
      style: TextStyle(color: _text, fontSize: 13.5),
      cursorColor: _teal,
      decoration: _inputDecoration(label),
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      labelStyle: TextStyle(color: _sub, fontSize: 13),
      filled: true,
      fillColor: _field,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _teal, width: 1.4),
      ),
    );
  }

  Future<void> _showHistory(MaintenanceSchedule item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _border),
        ),
        child: SizedBox(
          width: 720,
          height: 620,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history_rounded, color: _blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Maintenance History · ${item.roomName} ${item.pcId}',
                        style: TextStyle(
                          color: _text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Icon(Icons.close_rounded, color: _sub),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<MaintenanceRecord>>(
                    future: StaffService.instance.listMaintenanceHistory(
                      workstationId: item.workstationId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(_teal),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return MessageState(
                          icon: Icons.error_outline_rounded,
                          title: 'Could not load history',
                          message: cleanError(snapshot.error!),
                        );
                      }
                      final records = snapshot.data ?? const <MaintenanceRecord>[];
                      if (records.isEmpty) {
                        return const MessageState(
                          icon: Icons.history_toggle_off_rounded,
                          title: 'No preventive maintenance yet',
                          message: 'Completed quarterly reports will appear here.',
                        );
                      }
                      return ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _historyCard(records[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyCard(MaintenanceRecord record) {
    final color = _conditionColor(record.overallCondition);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _dateOnly(record.maintenanceDate),
                  style: TextStyle(color: _text, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _conditionLabel(record.overallCondition),
                  style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Technician: ${record.technicianName} · Checklist: '
            '${record.completedChecklistItems}/${_checklistLabels.length}',
            style: TextStyle(color: _sub, fontSize: 12.5),
          ),
          if (record.findings.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Findings: ${record.findings}', style: TextStyle(color: _sub, fontSize: 12.5)),
          ],
          if (record.actionsTaken.isNotEmpty)
            Text('Actions: ${record.actionsTaken}', style: TextStyle(color: _sub, fontSize: 12.5)),
          if (record.recommendations.isNotEmpty)
            Text(
              'Recommendations: ${record.recommendations}',
              style: TextStyle(color: _sub, fontSize: 12.5),
            ),
          const SizedBox(height: 5),
          Text(
            'Next due: ${_dateOnly(record.nextDueDate)}',
            style: TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: loading ? null : LinearGradient(colors: [_teal, _blue]),
        color: loading ? _teal.withValues(alpha: 0.25) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: const Color(0xFF080A0E),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF080A0E)),
                ),
              )
            : const Icon(Icons.task_alt_rounded, size: 17),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _dateOnly(DateTime? value) {
    if (value == null) return 'Not available';
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'overdue':
        return _red;
      case 'due_soon':
        return _amber;
      default:
        return _teal;
    }
  }

  Color _conditionColor(String condition) {
    switch (condition) {
      case 'critical':
        return _red;
      case 'needs_attention':
        return _amber;
      default:
        return _teal;
    }
  }

  String _conditionLabel(String condition) {
    switch (condition) {
      case 'critical':
        return 'Critical';
      case 'needs_attention':
        return 'Needs attention';
      default:
        return 'Good / Healthy';
    }
  }
}
