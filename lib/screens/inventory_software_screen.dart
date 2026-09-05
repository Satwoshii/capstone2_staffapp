import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';

import '../models/room_record.dart';
import '../services/exe_metadata_service.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';

enum _SoftwareSetupMethod { catalog, executable }

class _SoftwarePreset {
  const _SoftwarePreset({
    required this.id,
    required this.label,
    this.softwareName = '',
    this.matchText = '',
    this.publisher = '',
  });

  final String id;
  final String label;
  final String softwareName;
  final String matchText;
  final String publisher;

  bool get isCustom => id == 'custom';
}

const _softwarePresets = <_SoftwarePreset>[
  _SoftwarePreset(id: 'custom', label: 'Custom software'),
  _SoftwarePreset(
    id: 'packet_tracer',
    label: 'Cisco Packet Tracer',
    softwareName: 'Cisco Packet Tracer',
    matchText: 'Packet Tracer',
    publisher: 'Cisco',
  ),
  _SoftwarePreset(
    id: 'chrome',
    label: 'Google Chrome',
    softwareName: 'Google Chrome',
    matchText: 'Google Chrome',
    publisher: 'Google',
  ),
  _SoftwarePreset(
    id: 'edge',
    label: 'Microsoft Edge',
    softwareName: 'Microsoft Edge',
    matchText: 'Microsoft Edge',
    publisher: 'Microsoft',
  ),
  _SoftwarePreset(
    id: 'firefox',
    label: 'Mozilla Firefox',
    softwareName: 'Mozilla Firefox',
    matchText: 'Mozilla Firefox',
    publisher: 'Mozilla',
  ),
  _SoftwarePreset(
    id: 'vscode',
    label: 'Visual Studio Code',
    softwareName: 'Visual Studio Code',
    matchText: 'Visual Studio Code',
    publisher: 'Microsoft',
  ),
  _SoftwarePreset(
    id: 'android_studio',
    label: 'Android Studio',
    softwareName: 'Android Studio',
    matchText: 'Android Studio',
    publisher: 'Google',
  ),
  _SoftwarePreset(
    id: 'xampp',
    label: 'XAMPP',
    softwareName: 'XAMPP',
    matchText: 'XAMPP',
    publisher: 'Apache Friends',
  ),
  _SoftwarePreset(
    id: 'java',
    label: 'Java Runtime / JDK',
    softwareName: 'Java',
    matchText: 'Java',
  ),
];

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
    List<RoomRecord> availableRooms;
    try {
      availableRooms = (await StaffService.instance.listRooms())
          .where((room) => room.active)
          .toList()
        ..sort((a, b) => a.roomName.compareTo(b.roomName));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load rooms: ${cleanError(error)}')),
        );
      }
      return;
    }

    if (availableRooms.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Create and activate at least one room first.'),
          ),
        );
      }
      return;
    }

    final name = TextEditingController();
    final version = TextEditingController();
    final publisher = TextEditingController();
    final pattern = TextEditingController();
    final roomSearch = TextEditingController();
    final key = GlobalKey<FormState>();
    final selectedRooms = <String>{};
    var setupMethod = _SoftwareSetupMethod.catalog;
    var selectedPreset = _softwarePresets.first.id;
    ExeMetadata? importedExe;
    String? importError;
    var saving = false;
    var importing = false;
    var dragging = false;
    var roomSelectionInvalid = false;

    final savedCount = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final search = roomSearch.text.trim().toLowerCase();
          final visibleRooms = search.isEmpty
              ? availableRooms
              : availableRooms
                  .where(
                    (room) => room.roomName.toLowerCase().contains(search),
                  )
                  .toList();

          void applyPreset(String id) {
            final preset = _softwarePresets.firstWhere((item) => item.id == id);
            setDialogState(() {
              selectedPreset = id;
              importedExe = null;
              importError = null;
              name.text = preset.softwareName;
              pattern.text = preset.matchText;
              publisher.text = preset.publisher;
              version.clear();
            });
          }

          Future<void> inspectExe(String path) async {
            if (saving || importing) return;
            setDialogState(() {
              importing = true;
              dragging = false;
              importError = null;
            });
            try {
              final metadata =
                  await ExeMetadataService.instance.inspect(path);
              if (!dialogContext.mounted) return;
              setDialogState(() {
                importedExe = metadata;
                selectedPreset = _softwarePresets.first.id;
                name.text = metadata.displayName;
                pattern.text = metadata.suggestedMatchText;
                publisher.text = metadata.publisher;
                version.text = metadata.suggestedMinimumVersion;
              });
            } catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                importedExe = null;
                importError = cleanError(error);
              });
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => importing = false);
              }
            }
          }

          Future<void> browseForExe() async {
            if (saving || importing) return;
            try {
              const executableFiles = XTypeGroup(
                label: 'Windows applications',
                extensions: <String>['exe'],
              );
              final file = await openFile(
                acceptedTypeGroups: const <XTypeGroup>[executableFiles],
              );
              if (file != null) await inspectExe(file.path);
            } catch (error) {
              if (dialogContext.mounted) {
                setDialogState(() => importError = cleanError(error));
              }
            }
          }

          Future<void> save() async {
            if (setupMethod == _SoftwareSetupMethod.executable &&
                importedExe == null) {
              setDialogState(
                () => importError = 'Drop or browse for one EXE file first.',
              );
              return;
            }

            final formValid = key.currentState?.validate() ?? false;
            if (selectedRooms.isEmpty) {
              setDialogState(() => roomSelectionInvalid = true);
            }
            if (saving ||
                importing ||
                !formValid ||
                selectedRooms.isEmpty) {
              return;
            }

            setDialogState(() => saving = true);
            try {
              final count = await StaffService.instance
                  .saveRequiredSoftwareForRooms(
                roomNames: selectedRooms,
                softwareName: name.text,
                minimumVersion: version.text,
                publisher: publisher.text,
                matchPattern: pattern.text,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, count);
            } catch (error) {
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(cleanError(error))),
                );
              }
            }
          }

          final busy = saving || importing;
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.playlist_add_check_rounded),
                SizedBox(width: 10),
                Text('Add required software'),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: Form(
                key: key,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DialogSectionLabel('1. Choose setup method'),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_SoftwareSetupMethod>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: _SoftwareSetupMethod.catalog,
                              icon: Icon(Icons.list_alt_rounded),
                              label: Text('Select from Software List'),
                            ),
                            ButtonSegment(
                              value: _SoftwareSetupMethod.executable,
                              icon: Icon(Icons.file_open_rounded),
                              label: Text('Import from EXE'),
                            ),
                          ],
                          selected: {setupMethod},
                          onSelectionChanged: busy
                              ? null
                              : (selection) {
                                  final next = selection.first;
                                  setDialogState(() {
                                    setupMethod = next;
                                    importedExe = null;
                                    importError = null;
                                    if (next ==
                                        _SoftwareSetupMethod.catalog) {
                                      final preset = _softwarePresets.firstWhere(
                                        (item) => item.id == selectedPreset,
                                      );
                                      name.text = preset.softwareName;
                                      pattern.text = preset.matchText;
                                      publisher.text = preset.publisher;
                                      version.clear();
                                    } else {
                                      selectedPreset =
                                          _softwarePresets.first.id;
                                      name.clear();
                                      pattern.clear();
                                      publisher.clear();
                                      version.clear();
                                    }
                                  });
                                },
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (setupMethod == _SoftwareSetupMethod.catalog) ...[
                        DropdownButtonFormField<String>(
                          value: selectedPreset,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Software list',
                            prefixIcon: Icon(Icons.apps_rounded),
                          ),
                          items: _softwarePresets
                              .map(
                                (preset) => DropdownMenuItem<String>(
                                  value: preset.id,
                                  child: Text(preset.label),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (value) {
                                  if (value != null) applyPreset(value);
                                },
                        ),
                      ] else ...[
                        DropTarget(
                          onDragEntered: (_) {
                            if (!busy) {
                              setDialogState(() => dragging = true);
                            }
                          },
                          onDragExited: (_) {
                            if (dragging) {
                              setDialogState(() => dragging = false);
                            }
                          },
                          onDragDone: (details) {
                            if (busy) return;
                            if (details.files.length != 1) {
                              setDialogState(() {
                                dragging = false;
                                importError =
                                    'Drop exactly one Windows EXE file.';
                              });
                              return;
                            }
                            inspectExe(details.files.single.path);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              color: dragging
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerLow,
                              border: Border.all(
                                width: dragging ? 2 : 1,
                                color: importError != null
                                    ? Theme.of(context).colorScheme.error
                                    : dragging
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                if (importing)
                                  const SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  )
                                else
                                  Icon(
                                    importedExe == null
                                        ? Icons.drive_folder_upload_rounded
                                        : Icons.check_circle_rounded,
                                    size: 40,
                                    color: importedExe == null
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.green.shade700,
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  importing
                                      ? 'Reading Windows file metadata...'
                                      : importedExe == null
                                          ? 'Drag and drop one .exe file here'
                                          : importedExe!.fileName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  importedExe == null
                                      ? 'or use Browse EXE below'
                                      : 'Metadata loaded. Review the detection rules below.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: busy ? null : browseForExe,
                                  icon: const Icon(Icons.folder_open_rounded),
                                  label: Text(
                                    importedExe == null
                                        ? 'Browse EXE'
                                        : 'Choose another EXE',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Syswatch reads the embedded product details only. The EXE is not uploaded, installed, or started.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        if (importError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            importError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: name,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'Software name shown to ITSO',
                          hintText: 'e.g. Cisco Packet Tracer',
                          prefixIcon: Icon(Icons.label_rounded),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter the software name.'
                            : null,
                        onChanged: (_) {
                          if (setupMethod == _SoftwareSetupMethod.catalog &&
                              selectedPreset != _softwarePresets.first.id) {
                            setDialogState(
                              () => selectedPreset = _softwarePresets.first.id,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 22),
                      const _DialogSectionLabel('2. Select affected rooms'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${selectedRooms.length} of ${availableRooms.length} selected',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setDialogState(() {
                                      selectedRooms
                                        ..clear()
                                        ..addAll(
                                          availableRooms.map(
                                            (room) => room.roomName,
                                          ),
                                        );
                                      roomSelectionInvalid = false;
                                    }),
                            child: const Text('Select all'),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setDialogState(() {
                                      selectedRooms.clear();
                                      roomSelectionInvalid = false;
                                    }),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      TextField(
                        controller: roomSearch,
                        enabled: !busy,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Search rooms',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: roomSelectionInvalid
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: visibleRooms.isEmpty
                            ? const Center(child: Text('No rooms match.'))
                            : SingleChildScrollView(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: visibleRooms.map((room) {
                                    final selected =
                                        selectedRooms.contains(room.roomName);
                                    return FilterChip(
                                      selected: selected,
                                      label: Text(room.roomName),
                                      avatar: Icon(
                                        selected
                                            ? Icons.check_rounded
                                            : Icons.meeting_room_outlined,
                                        size: 17,
                                      ),
                                      onSelected: busy
                                          ? null
                                          : (value) => setDialogState(() {
                                                if (value) {
                                                  selectedRooms
                                                      .add(room.roomName);
                                                } else {
                                                  selectedRooms
                                                      .remove(room.roomName);
                                                }
                                                roomSelectionInvalid = false;
                                              }),
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                      if (roomSelectionInvalid) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Select at least one room.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      const _DialogSectionLabel('3. Review detection rules'),
                      const SizedBox(height: 5),
                      const Text(
                        'These values can be corrected before saving. Matching is not case-sensitive.',
                        style: TextStyle(fontSize: 12.5, color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: pattern,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'Installed name contains',
                          hintText: 'e.g. Packet Tracer',
                          helperText:
                              'Use a stable part of the name; do not include the version.',
                          prefixIcon: Icon(Icons.manage_search_rounded),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter text used to identify the installed app.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: publisher,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'Publisher contains (optional)',
                          hintText: 'e.g. Cisco',
                          prefixIcon: Icon(Icons.verified_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: version,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'Minimum version (optional)',
                          hintText: 'Leave blank to accept any version',
                          prefixIcon: Icon(Icons.numbers_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 19),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'EXE import creates the same installed-software rule used by the Student Agent. If the Windows installed-app name is different, edit “Installed name contains” before saving.',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : save,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  saving
                      ? 'Saving...'
                      : importing
                          ? 'Reading EXE...'
                          : 'Save to ${selectedRooms.length} room${selectedRooms.length == 1 ? '' : 's'}',
                ),
              ),
            ],
          );
        },
      ),
    );
    name.dispose();
    version.dispose();
    publisher.dispose();
    pattern.dispose();
    roomSearch.dispose();
    if (savedCount != null && mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Required software added to $savedCount room${savedCount == 1 ? '' : 's'}.',
          ),
        ),
      );
    }
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
            final requirementGroups = _groupRequiredSoftware(required);
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
                  _StatChip(
                    icon: Icons.rule_rounded,
                    label: 'Required software',
                    value: '${requirementGroups.length}',
                  ),
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

  List<_RequiredSoftwareGroup> _groupRequiredSoftware(
    List<Map<String, dynamic>> rows,
  ) {
    final grouped = <String, _RequiredSoftwareGroup>{};
    for (final row in rows) {
      String normalized(dynamic value) =>
          (value ?? '').toString().trim().toLowerCase();
      final key = <String>[
        normalized(row['software_name']),
        normalized(row['minimum_version']),
        normalized(row['publisher']),
        normalized(row['match_pattern']),
      ].join('|');
      grouped.putIfAbsent(key, () => _RequiredSoftwareGroup(row)).add(row);
    }
    final result = grouped.values.toList()
      ..sort(
        (a, b) => a.softwareName
            .toLowerCase()
            .compareTo(b.softwareName.toLowerCase()),
      );
    return result;
  }

  Future<void> _deleteRequiredSoftwareGroup(
    _RequiredSoftwareGroup group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove required software?'),
        content: Text(
          '${group.softwareName} will be removed from '
          '${group.rooms.length} room${group.rooms.length == 1 ? '' : 's'}: '
          '${group.rooms.join(', ')}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      for (final id in group.ids) {
        await StaffService.instance.deleteRequiredSoftware(id);
      }
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${group.softwareName} removed from ${group.rooms.length} room${group.rooms.length == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(error))),
        );
        _refresh();
      }
    }
  }

  Widget _requiredTab(List<Map<String, dynamic>> rows) {
    final query = _requiredSearch.text.trim().toLowerCase();
    final groups = _groupRequiredSoftware(rows);
    final filtered = query.isEmpty
        ? groups
        : groups.where((group) {
            final haystack = <String>[
              group.softwareName,
              group.rooms.join(' '),
              (group.row['publisher'] ?? '').toString(),
              (group.row['match_pattern'] ?? '').toString(),
            ].join(' ').toLowerCase();
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
                  children: filtered
                      .map(
                        (group) => _RequiredCard(
                          group: group,
                          onDelete: () =>
                              _deleteRequiredSoftwareGroup(group),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RequiredSoftwareGroup {
  _RequiredSoftwareGroup(this.row);

  final Map<String, dynamic> row;
  final Map<String, int> _roomIds = <String, int>{};

  String get softwareName =>
      (row['software_name'] ?? 'Unnamed software').toString();

  List<String> get rooms {
    final values = _roomIds.keys.toList()..sort();
    return values;
  }

  List<int> get ids => _roomIds.values.toList();

  void add(Map<String, dynamic> source) {
    final id = int.tryParse((source['id'] ?? '').toString());
    if (id == null || id <= 0) return;
    final room = (source['room_name'] ?? '').toString().trim();
    _roomIds[room.isEmpty ? 'All rooms' : room] = id;
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
  const _RequiredCard({required this.group, required this.onDelete});
  final _RequiredSoftwareGroup group;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = group.row;
    final rooms = group.rooms;
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
              'Required in ${rooms.length} room${rooms.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54, fontWeight: FontWeight.w500),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 14),
            _kv('Rooms', rooms.join(', ')),
            _kv('Min version', r['minimum_version']),
            _kv('Publisher', r['publisher']),
            _kv('Installed name contains', r['match_pattern']),
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
                label: const Text('Remove from all listed rooms', style: TextStyle(fontWeight: FontWeight.w700)),
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
