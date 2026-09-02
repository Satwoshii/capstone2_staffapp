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
    if (selected != null) setState(() => from ? _from = selected : _to = selected.add(const Duration(hours: 23, minutes: 59, seconds: 59)));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export saved to ${file.path}')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = {
      'reports': 'Reports',
      'repairs': 'Repairs',
      'audit_logs': 'Audit logs',
      'login_records': 'Login records',
      'maintenance_records': 'Maintenance records',
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Controlled Record Export', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Available only to ITSO/Admin and Super Admin. Every export is written to export_audit_logs and the main audit log.'),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Record type', border: OutlineInputBorder()),
          items: labels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: _busy ? null : (v) => setState(() => _type = v ?? _type),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _format,
          decoration: const InputDecoration(labelText: 'Format', border: OutlineInputBorder()),
          items: const [DropdownMenuItem(value: 'csv', child: Text('CSV')), DropdownMenuItem(value: 'pdf', child: Text('PDF'))],
          onChanged: _busy ? null : (v) => setState(() => _format = v ?? _format),
        ),
        const SizedBox(height: 14),
        TextField(controller: _room, enabled: !_busy, decoration: const InputDecoration(labelText: 'Room filter (optional)', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(onPressed: _busy ? null : () => _pick(true), icon: const Icon(Icons.date_range), label: Text(_from == null ? 'From date' : 'From ${_from!.year}-${_from!.month.toString().padLeft(2, '0')}-${_from!.day.toString().padLeft(2, '0')}')),
            OutlinedButton.icon(onPressed: _busy ? null : () => _pick(false), icon: const Icon(Icons.event), label: Text(_to == null ? 'To date' : 'To ${_to!.year}-${_to!.month.toString().padLeft(2, '0')}-${_to!.day.toString().padLeft(2, '0')}')),
            TextButton(onPressed: _busy ? null : () => setState(() { _from = null; _to = null; }), child: const Text('Clear dates')),
          ],
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded),
            label: Text(_busy ? 'Exporting...' : 'Export ${_format.toUpperCase()}'),
          ),
        ),
      ],
    );
  }
}
