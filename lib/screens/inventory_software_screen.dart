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

  final _inventorySearch = TextEditingController();
  final _complianceSearch = TextEditingController();
  final _requiredSearch = TextEditingController();
  bool _issuesOnly = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _inventorySearch.dispose();
    _complianceSearch.dispose();
    _requiredSearch.dispose();
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

  Future<void> _refreshAsync() async {
    _refresh();
    await _future;
  }

  bool _isCompliant(String status) => status == 'installed' || status == 'manually_verified';

  // ---------------------------------------------------------------------
  // Add required software dialog
  // ---------------------------------------------------------------------

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
        title: Row(
          children: const [
            Icon(Icons.playlist_add_check_rounded),
            SizedBox(width: 10),
            Text('Add required software'),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DialogSectionLabel('What to check'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: room,
                  decoration: const InputDecoration(
                    labelText: 'Room',
                    hintText: 'e.g. Lab 204',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a room.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Software name',
                    hintText: 'e.g. Google Chrome',
                    prefixIcon: Icon(Icons.apps_rounded),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the software name.' : null,
                ),
                const SizedBox(height: 20),
                const _DialogSectionLabel('Optional matching rules'),
                const SizedBox(height: 4),
                const Text(
                  'Leave blank to accept any version or publisher.',
                  style: TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: version,
                  decoration: const InputDecoration(
                    labelText: 'Minimum version',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: publisher,
                  decoration: const InputDecoration(
                    labelText: 'Publisher',
                    prefixIcon: Icon(Icons.verified_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pattern,
                  decoration: const InputDecoration(
                    labelText: 'Match pattern',
                    helperText: 'Optional text/regex used to match scanned software names.',
                    prefixIcon: Icon(Icons.rule_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton.icon(
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save'),
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
          ),
        ],
      ),
    );
    room.dispose();
    name.dispose();
    version.dispose();
    publisher.dispose();
    pattern.dispose();
    if (saved == true) _refresh();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Workstation Inventory & Software Compliance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.icon(
                onPressed: _addRequiredSoftware,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Required Software'),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
        ),
        FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final data = snapshot.data!;
            final inventory = data.isNotEmpty ? data[0] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];
            final compliance = data.length > 1 ? data[1] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];
            final required = data.length > 2 ? data[2] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];
            final issues = compliance.where((r) => !_isCompliant((r['status'] ?? 'unknown').toString())).length;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _StatChip(icon: Icons.computer_rounded, label: 'PCs found', value: '${inventory.length}'),
                  _StatChip(
                    icon: issues == 0 ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                    label: issues == 0 ? 'All compliant' : 'Issues',
                    value: issues == 0 ? '' : '$issues',
                    emphasize: issues > 0,
                  ),
                  _StatChip(icon: Icons.rule_rounded, label: 'Required rules', value: '${required.length}'),
                ],
              ),
            );
          },
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
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _EmptyState(
                  icon: Icons.error_outline_rounded,
                  message: cleanError(snapshot.error!),
                );
              }
              final data = snapshot.data ?? const [];
              final inventory = data.isNotEmpty ? data[0] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];
              final compliance = data.length > 1 ? data[1] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];
              final required = data.length > 2 ? data[2] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];
              return TabBarView(
                controller: _tabs,
                children: [
                  _inventoryTab(inventory),
                  _complianceTab(compliance),
                  _requiredTab(required),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // PC Specifications tab
  // ---------------------------------------------------------------------

  Widget _inventoryTab(List<Map<String, dynamic>> rows) {
    final query = _inventorySearch.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? rows
        : rows.where((r) {
      final haystack = [r['room_name'], r['pc_id'], r['computer_name'], r['cpu_name']]
          .map((v) => (v ?? '').toString().toLowerCase())
          .join(' ');
      return haystack.contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: _SearchField(
            controller: _inventorySearch,
            hint: 'Search by room, PC ID, computer name, or CPU',
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const _EmptyState(
            icon: Icons.desktop_windows_outlined,
            message: 'No inventory has been received yet.',
          )
              : filtered.isEmpty
              ? const _EmptyState(icon: Icons.search_off_rounded, message: 'No workstations match your search.')
              : RefreshIndicator(
            onRefresh: _refreshAsync,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              child: Center(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: filtered.map((r) => _InventoryCard(row: r)).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Software Compliance tab
  // ---------------------------------------------------------------------

  Widget _complianceTab(List<Map<String, dynamic>> rows) {
    final query = _complianceSearch.text.trim().toLowerCase();
    final scoped = _issuesOnly
        ? rows.where((r) => !_isCompliant((r['status'] ?? 'unknown').toString())).toList()
        : rows;
    final filtered = query.isEmpty
        ? scoped
        : scoped.where((r) {
      final haystack = [r['room_name'], r['pc_id'], r['software_name'], r['detected_name']]
          .map((v) => (v ?? '').toString().toLowerCase())
          .join(' ');
      return haystack.contains(query);
    }).toList();

    final compliantCount = rows.where((r) => _isCompliant((r['status'] ?? 'unknown').toString())).length;
    final ratio = rows.isEmpty ? 0.0 : compliantCount / rows.length;

    return Column(
      children: [
        if (rows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: ratio, minHeight: 8),
                  ),
                ),
                const SizedBox(width: 10),
                Text('$compliantCount / ${rows.length} compliant', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Row(
            children: [
              Expanded(
                child: _SearchField(
                  controller: _complianceSearch,
                  hint: 'Search by room, PC ID, or software',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('Issues only'),
                selected: _issuesOnly,
                avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                onSelected: (v) => setState(() => _issuesOnly = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const _EmptyState(icon: Icons.fact_check_outlined, message: 'No software scan results yet.')
              : filtered.isEmpty
              ? const _EmptyState(icon: Icons.search_off_rounded, message: 'Nothing matches your current filters.')
              : RefreshIndicator(
            onRefresh: _refreshAsync,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              child: Center(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: filtered.map((r) => _ComplianceCard(
                    row: r,
                    isCompliant: _isCompliant((r['status'] ?? 'unknown').toString()),
                    onVerify: () async {
                      try {
                        await StaffService.instance.manuallyVerifySoftware(
                          workstationId: (r['workstation_id'] ?? '').toString(),
                          requiredSoftwareId: (r['required_software_id'] as num).toInt(),
                          notes: 'Verified manually during ITSO maintenance.',
                        );
                        _refresh();
                      } catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error))));
                        }
                      }
                    },
                  )).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Required Software tab
  // ---------------------------------------------------------------------

  Widget _requiredTab(List<Map<String, dynamic>> rows) {
    final query = _requiredSearch.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? rows
        : rows.where((r) {
      final haystack = [r['room_name'], r['software_name']].map((v) => (v ?? '').toString().toLowerCase()).join(' ');
      return haystack.contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: _SearchField(
            controller: _requiredSearch,
            hint: 'Search by room or software name',
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const _EmptyState(icon: Icons.playlist_add_check_circle_outlined, message: 'No required software configured.')
              : filtered.isEmpty
              ? const _EmptyState(icon: Icons.search_off_rounded, message: 'No rules match your search.')
              : RefreshIndicator(
            onRefresh: _refreshAsync,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              child: Center(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: filtered.map((r) => _RequiredCard(
                    row: r,
                    onDelete: () async {
                      try {
                        await StaffService.instance.deleteRequiredSoftware((r['id'] as num).toInt());
                        _refresh();
                      } catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error))));
                        }
                      }
                    },
                  )).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Reusable pieces
// ===========================================================================

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Colors.black54),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.value, this.emphasize = false});
  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          if (value.isNotEmpty) ...[
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            const SizedBox(width: 5),
          ],
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint, required this.onChanged});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: () {
            controller.clear();
            onChanged('');
          },
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.black38),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// PC Specifications card
// ===========================================================================

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.row});
  final Map<String, dynamic> row;

  static String _gb(int bytes) => bytes <= 0 ? 'Unknown' : '${(bytes / 1073741824).toStringAsFixed(1)} GB';

  @override
  Widget build(BuildContext context) {
    final r = row;
    final ramBytes = (r['ram_total_bytes'] as num?)?.toInt() ?? 0;
    final storageBytes = (r['total_storage_bytes'] as num?)?.toInt() ?? 0;
    final windows = '${r['windows_version'] ?? ''} ${r['windows_build'] ?? ''}'.trim();

    return SizedBox(
      width: 380,
      child: Card(
        elevation: 3,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: const Icon(Icons.computer_rounded, size: 22, color: Colors.blue),
          ),
          title: Text(
            '${r['computer_name'] ?? 'Unknown PC'}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${r['room_name']} · ${r['pc_id']}',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54, fontWeight: FontWeight.w500),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 14),
            _kv('CPU', r['cpu_name']),
            _kv('RAM', _gb(ramBytes)),
            _kv('Storage', _gb(storageBytes)),
            _kv('Windows', windows),
            _kv('MAC address', r['mac_address']),
            _kv('Local IP', r['local_ip']),
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
      ),
    );
  }

  Widget _kv(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.black54))),
        Expanded(child: Text((value ?? 'Not available').toString(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500))),
      ],
    ),
  );
}

// ===========================================================================
// Software Compliance card
// ===========================================================================

class _ComplianceCard extends StatelessWidget {
  const _ComplianceCard({required this.row, required this.isCompliant, required this.onVerify});
  final Map<String, dynamic> row;
  final bool isCompliant;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final status = (r['status'] ?? 'unknown').toString().replaceAll('_', ' ');
    final detected = r['detected_name'] == null
        ? 'Not detected'
        : '${r['detected_name']} ${r['detected_version'] ?? ''}'.trim();

    return SizedBox(
      width: 380,
      child: Card(
        elevation: 3,
        shadowColor: isCompliant ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: isCompliant ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: isCompliant ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            child: Icon(
              isCompliant ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              size: 22,
              color: isCompliant ? Colors.green : Colors.orange,
            ),
          ),
          title: Text(
            '${r['software_name']}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${r['room_name']} · ${r['pc_id']} · $status',
              style: TextStyle(
                fontSize: 12.5,
                color: isCompliant ? Colors.black54 : Colors.orange.shade800,
                fontWeight: isCompliant ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 14),
            _kv('Status', status),
            _kv('Detected software', detected),
            _kv('Publisher (Rule)', r['publisher']),
            _kv('Min version (Rule)', r['minimum_version']),
            _kv('Match pattern', r['match_pattern']),
            if (!isCompliant) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onVerify,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.task_alt_rounded, size: 19),
                  label: const Text('Mark as manually verified', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.black54))),
        Expanded(child: Text((value ?? 'Any').toString(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500))),
      ],
    ),
  );
}

// ===========================================================================
// Required Software card
// ===========================================================================

class _RequiredCard extends StatelessWidget {
  const _RequiredCard({required this.row, required this.onDelete});
  final Map<String, dynamic> row;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = row;
    return SizedBox(
      width: 380,
      child: Card(
        elevation: 3,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.indigo.withOpacity(0.1),
            child: const Icon(Icons.apps_rounded, size: 22, color: Colors.indigo),
          ),
          title: Text(
            '${r['software_name']}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Required for ${r['room_name']}',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54, fontWeight: FontWeight.w500),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 14),
            _kv('Room', r['room_name']),
            _kv('Min version', r['minimum_version']),
            _kv('Publisher', r['publisher']),
            _kv('Match pattern', r['match_pattern']),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                label: const Text('Remove requirement', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.black54))),
        Expanded(child: Text((value ?? 'Any').toString(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500))),
      ],
    ),
  );
}