import 'package:flutter/material.dart';

import '../services/staff_service.dart';
import '../utils/value_helpers.dart';

class InventorySoftwareScreen extends StatefulWidget {
  const InventorySoftwareScreen({super.key});

  @override
  State<InventorySoftwareScreen> createState() => _InventorySoftwareScreenState();
}

class _InventorySoftwareScreenState extends State<InventorySoftwareScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = Future.wait([
        StaffService.instance.listWorkstationInventory(),
        StaffService.instance.listSoftwareCompliance(),
        StaffService.instance.listRequiredSoftware(),
      ]);
    });
  }

  Future<void> _addRequiredSoftware() async {
    final room = TextEditingController();
    final name = TextEditingController();
    final version = TextEditingController();
    final publisher = TextEditingController();
    final pattern = TextEditingController();
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add required software'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: room, decoration: const InputDecoration(labelText: 'Room'), validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a room.' : null),
                TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Software name'), validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the software name.' : null),
                TextFormField(controller: version, decoration: const InputDecoration(labelText: 'Minimum version (optional)')),
                TextFormField(controller: publisher, decoration: const InputDecoration(labelText: 'Publisher (optional)')),
                TextFormField(controller: pattern, decoration: const InputDecoration(labelText: 'Match pattern (optional)')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!(key.currentState?.validate() ?? false)) return;
              try {
                await StaffService.instance.saveRequiredSoftware(
                  roomName: room.text,
                  softwareName: name.text,
                  minimumVersion: version.text,
                  publisher: publisher.text,
                  matchPattern: pattern.text,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(cleanError(error))));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    room.dispose(); name.dispose(); version.dispose(); publisher.dispose(); pattern.dispose();
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Workstation Inventory & Software Compliance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              FilledButton.icon(onPressed: _addRequiredSoftware, icon: const Icon(Icons.add_rounded), label: const Text('Required Software')),
              const SizedBox(width: 8),
              IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'PC Specifications'),
            Tab(text: 'Software Compliance'),
            Tab(text: 'Required Software'),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text(cleanError(snapshot.error!)));
              final data = snapshot.data ?? const [];
              final inventory = data.isNotEmpty ? data[0] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];
              final compliance = data.length > 1 ? data[1] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];
              final required = data.length > 2 ? data[2] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];
              return TabBarView(
                controller: _tabs,
                children: [
                  _inventoryList(inventory),
                  _complianceList(compliance),
                  _requiredList(required),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _inventoryList(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const Center(child: Text('No inventory has been received yet.'));
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final r = rows[i];
        final ramBytes = (r['ram_total_bytes'] as num?)?.toInt() ?? 0;
        final storageBytes = (r['total_storage_bytes'] as num?)?.toInt() ?? 0;
        String gb(int bytes) => bytes <= 0 ? 'Unknown' : '${(bytes / 1073741824).toStringAsFixed(1)} GB';
        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.computer_rounded),
            title: Text('${r['room_name']} · ${r['pc_id']} · ${r['computer_name'] ?? 'Unknown PC'}'),
            subtitle: Text('CPU: ${r['cpu_name'] ?? 'Unknown'} · RAM: ${gb(ramBytes)} · Storage: ${gb(storageBytes)}'),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            children: [
              _kv('MAC address', r['mac_address']),
              _kv('Local IP (ITSO only)', r['local_ip']),
              _kv('Windows', '${r['windows_version'] ?? ''} ${r['windows_build'] ?? ''}'.trim()),
              _kv('System UUID', r['system_uuid']),
              _kv('BIOS serial', r['bios_serial_number']),
              _kv('Motherboard', '${r['motherboard_manufacturer'] ?? ''} ${r['motherboard_model'] ?? ''}'.trim()),
              _kv('Motherboard serial', r['motherboard_serial']),
              _kv('CPU cores / threads', '${r['cpu_cores'] ?? '?'} / ${r['cpu_threads'] ?? '?'}'),
              _kv('GPU', readableValue(r['gpu'])),
              _kv('Disks', readableValue(r['disks'])),
              _kv('Last inventory', r['last_inventory_at']),
            ],
          ),
        );
      },
    );
  }

  Widget _complianceList(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const Center(child: Text('No software scan results yet.'));
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        final status = (r['status'] ?? 'unknown').toString();
        return Card(
          child: ListTile(
            leading: Icon(status == 'installed' || status == 'manually_verified' ? Icons.check_circle_rounded : Icons.warning_amber_rounded),
            title: Text('${r['room_name']} · ${r['pc_id']} · ${r['software_name']}'),
            subtitle: Text('Status: ${status.replaceAll('_', ' ')}\nDetected: ${r['detected_name'] ?? 'Not detected'} ${r['detected_version'] ?? ''}'),
            trailing: status == 'installed' || status == 'manually_verified'
                ? null
                : TextButton(
                    onPressed: () async {
                      try {
                        await StaffService.instance.manuallyVerifySoftware(
                          workstationId: (r['workstation_id'] ?? '').toString(),
                          requiredSoftwareId: (r['required_software_id'] as num).toInt(),
                          notes: 'Verified manually during ITSO maintenance.',
                        );
                        _refresh();
                      } catch (error) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error))));
                      }
                    },
                    child: const Text('Verify manually'),
                  ),
          ),
        );
      },
    );
  }

  Widget _requiredList(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const Center(child: Text('No required software configured.'));
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.apps_rounded),
            title: Text('Room ${r['room_name']} · ${r['software_name']}'),
            subtitle: Text('Minimum version: ${r['minimum_version'] ?? 'Any'} · Publisher: ${r['publisher'] ?? 'Any'}'),
            trailing: IconButton(
              tooltip: 'Remove requirement',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                try {
                  await StaffService.instance.deleteRequiredSoftware((r['id'] as num).toInt());
                  _refresh();
                } catch (error) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error))));
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _kv(String label, dynamic value) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 170, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            Expanded(child: Text((value ?? 'Not available').toString())),
          ],
        ),
      );
}
