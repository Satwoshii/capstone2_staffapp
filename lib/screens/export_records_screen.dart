import 'package:flutter/material.dart';

import '../services/staff_service.dart';
import '../utils/value_helpers.dart';

class ExportRecordsScreen extends StatefulWidget {
  const ExportRecordsScreen({super.key});

  @override
  State<ExportRecordsScreen> createState() => _ExportRecordsScreenState();
}

class _ExportRecordsScreenState extends State<ExportRecordsScreen> {
  String _type = 'reports';
  String _format = 'csv';
  DateTime? _from;
  DateTime? _to;
  final _room = TextEditingController();
  bool _busy = false;

  static const _labels = {
    'reports': 'Reports',
    'repairs': 'Repairs',
    'audit_logs': 'Audit logs',
    'login_records': 'Login records',
    'maintenance_records': 'Maintenance records',
  };

  static const _typeIcons = {
    'reports': Icons.description_outlined,
    'repairs': Icons.build_outlined,
    'audit_logs': Icons.fact_check_outlined,
    'login_records': Icons.login_outlined,
    'maintenance_records': Icons.handyman_outlined,
  };

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  Future<void> _pick(bool from) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) {
      setState(() => from
          ? _from = selected
          : _to = selected.add(const Duration(hours: 23, minutes: 59, seconds: 59)));
    }
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await StaffService.instance.exportRecords(
        type: _type,
        format: _format,
        dateFrom: _from,
        dateTo: _to,
        roomName: _room.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export saved to ${file.path}')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDateRange = _from != null || _to != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        // ---- Header -------------------------------------------------
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.lock_outline, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Controlled record export',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ITSO/Admin and Super Admin only. Every export is logged to '
                        'export_audit_logs and the main audit log.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ---- Section: What to export --------------------------------
        _SectionCard(
          icon: Icons.dataset_outlined,
          title: 'What to export',
          subtitle: 'Choose the record type and output format',
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _labels.entries.map((e) {
                  final selected = e.key == _type;
                  return ChoiceChip(
                    label: Text(e.value),
                    avatar: Icon(
                      _typeIcons[e.key],
                      size: 18,
                      color: selected
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    selected: selected,
                    onSelected: _busy ? null : (_) => setState(() => _type = e.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'csv',
                          label: Text('CSV'),
                          icon: Icon(Icons.table_chart_outlined),
                        ),
                        ButtonSegment(
                          value: 'pdf',
                          label: Text('PDF'),
                          icon: Icon(Icons.picture_as_pdf_outlined),
                        ),
                      ],
                      selected: {_format},
                      onSelectionChanged: _busy
                          ? null
                          : (v) => setState(() => _format = v.first),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ---- Section: Filters ----------------------------------------
        _SectionCard(
          icon: Icons.filter_alt_outlined,
          title: 'Filters',
          subtitle: 'Narrow the export by room and date range',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _room,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Room filter',
                  hintText: 'Optional — leave blank for all rooms',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(true),
                    icon: const Icon(Icons.date_range),
                    label: Text(_from == null ? 'From date' : 'From ${_fmtDate(_from!)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(false),
                    icon: const Icon(Icons.event),
                    label: Text(_to == null ? 'To date' : 'To ${_fmtDate(_to!)}'),
                  ),
                  if (hasDateRange)
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                        _from = null;
                        _to = null;
                      }),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Clear dates'),
                    ),
                ],
              ),
              if (!hasDateRange) ...[
                const SizedBox(height: 8),
                Text(
                  'No date range set — export will include all available records.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ---- Action -----------------------------------------------------
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: _busy
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.download_rounded),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _busy ? 'Exporting…' : 'Export ${_format.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A quiet, reusable card wrapper that groups related controls under a
/// small icon + title + subtitle header.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}