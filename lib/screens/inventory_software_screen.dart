import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';

import '../models/room_record.dart';
import '../services/exe_metadata_service.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import 'room_inventory_detail_screen.dart';

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

class _InventorySoftwareScreenState extends State<InventorySoftwareScreen> {
  late Future<List<dynamic>> _future;
  final _searchController = TextEditingController();
  bool _issuesOnly = false;
  String? _selectedRoom;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _cardColor => _isDarkMode ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor => _isDarkMode ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _accentA => const Color(0xFFFFD700);
  Color get _accentB => const Color(0xFF003366);
  Color get _accentAForeground => _isDarkMode ? _accentA : _accentB;
  Color get _accentBForeground => _isDarkMode ? Colors.white : _accentB;
  Color get _textColor => _isDarkMode ? Colors.white : const Color(0xFF1A1C1E);
  Color get _subTextColor => _isDarkMode ? Colors.white54 : Colors.black45;
  Color get _borderColor => _isDarkMode
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.09);
  Color get _buttonBg => _isDarkMode ? _accentA : _accentB;
  Color get _buttonFg => _isDarkMode ? Colors.black : Colors.white;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _future = Future.wait([
        StaffService.instance.listWorkstationInventory(),
        StaffService.instance.listSoftwareCompliance(),
        StaffService.instance.listRequiredSoftware(),
      ]);
    });
  }

  bool _isCompliant(String status) => status == 'installed' || status == 'manually_verified';

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

    await showDialog<int>(
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
                acceptedTypeGroups: [executableFiles],
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
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, count);
                _refresh();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Required software added to $count room${count == 1 ? '' : 's'}.')),
                );
              }
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
          final accent = _accentAForeground;

          return AlertDialog(
            backgroundColor: _cardColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.playlist_add_check_rounded, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Add required software',
                    style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
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
                      _DialogSectionLabel('1. Choose setup method', color: accent, subTextColor: _subTextColor),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_SoftwareSetupMethod>(
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return accent.withValues(alpha: 0.15);
                              }
                              return _fieldColor;
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return _textColor;
                              }
                              return _subTextColor;
                            }),
                            side: WidgetStatePropertyAll(BorderSide(color: _borderColor)),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
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
                          dropdownColor: _cardColor,
                          decoration: InputDecoration(
                            labelText: 'Software list',
                            labelStyle: TextStyle(color: _subTextColor),
                            prefixIcon: Icon(Icons.apps_rounded, color: _subTextColor),
                            filled: true,
                            fillColor: _fieldColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _borderColor)),
                          ),
                          items: _softwarePresets
                              .map(
                                (preset) => DropdownMenuItem<String>(
                                  value: preset.id,
                                  child: Text(preset.label, style: TextStyle(color: _textColor)),
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
                                  ? accent.withValues(alpha: 0.12)
                                  : _fieldColor,
                              border: Border.all(
                                width: dragging ? 2 : 1,
                                color: importError != null
                                    ? const Color(0xFFFF6B6B)
                                    : dragging
                                        ? accent
                                        : _borderColor,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                if (importing)
                                  SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: accent,
                                    ),
                                  )
                                else
                                  Icon(
                                    importedExe == null
                                        ? Icons.drive_folder_upload_rounded
                                        : Icons.check_circle_rounded,
                                    size: 40,
                                    color: importedExe == null
                                        ? accent
                                        : const Color(0xFF4CAF50),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  importing
                                      ? 'Reading metadata...'
                                      : importedExe == null
                                          ? 'Drag and drop one .exe file here'
                                          : importedExe!.fileName,
                                  style: TextStyle(fontWeight: FontWeight.w800, color: _textColor),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: busy ? null : browseForExe,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: accent,
                                    side: BorderSide(color: accent.withValues(alpha: 0.5)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
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
                        if (importError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(importError!,
                                style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12)),
                          ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: name,
                        enabled: !busy,
                        style: TextStyle(color: _textColor),
                        decoration: InputDecoration(
                          labelText: 'Software name shown to ITSO',
                          labelStyle: TextStyle(color: _subTextColor),
                          prefixIcon: Icon(Icons.label_rounded, color: _subTextColor),
                          filled: true,
                          fillColor: _fieldColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _borderColor)),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter the software name.'
                            : null,
                      ),
                      const SizedBox(height: 22),
                      _DialogSectionLabel('2. Select affected rooms', color: accent, subTextColor: _subTextColor),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${selectedRooms.length} of ${availableRooms.length} selected',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _textColor,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setDialogState(() {
                                      selectedRooms.addAll(
                                        availableRooms.map((r) => r.roomName),
                                      );
                                      roomSelectionInvalid = false;
                                    }),
                            style: TextButton.styleFrom(foregroundColor: accent),
                            child: const Text('Select all'),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setDialogState(() {
                                      selectedRooms.clear();
                                      roomSelectionInvalid = false;
                                    }),
                            style: TextButton.styleFrom(foregroundColor: _subTextColor),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      TextField(
                        controller: roomSearch,
                        enabled: !busy,
                        style: TextStyle(color: _textColor),
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search rooms',
                          hintStyle: TextStyle(color: _subTextColor),
                          prefixIcon: Icon(Icons.search_rounded, color: _subTextColor),
                          filled: true,
                          fillColor: _fieldColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _borderColor)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _fieldColor.withValues(alpha: 0.4),
                          border: Border.all(
                            color: roomSelectionInvalid
                                ? const Color(0xFFFF6B6B)
                                : _borderColor,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: visibleRooms.isEmpty
                            ? Center(child: Text('No rooms match.', style: TextStyle(color: _subTextColor)))
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
                                      backgroundColor: _cardColor,
                                      selectedColor: accent.withValues(alpha: 0.15),
                                      checkmarkColor: accent,
                                      side: BorderSide(
                                        color: selected ? accent.withValues(alpha: 0.5) : _borderColor,
                                      ),
                                      labelStyle: TextStyle(
                                        color: selected ? _textColor : _subTextColor,
                                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                        fontSize: 12.5,
                                      ),
                                      avatar: Icon(
                                        selected
                                            ? Icons.check_rounded
                                            : Icons.meeting_room_outlined,
                                        size: 17,
                                        color: selected ? accent : _subTextColor,
                                      ),
                                      onSelected: busy
                                          ? null
                                          : (value) => setDialogState(() {
                                                if (value) {
                                                  selectedRooms.add(room.roomName);
                                                } else {
                                                  selectedRooms.remove(room.roomName);
                                                }
                                                roomSelectionInvalid = false;
                                              }),
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                      if (roomSelectionInvalid)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Select at least one room.',
                              style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 12)),
                        ),
                      const SizedBox(height: 22),
                      _DialogSectionLabel('3. Review detection rules', color: accent, subTextColor: _subTextColor),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: pattern,
                        enabled: !busy,
                        style: TextStyle(color: _textColor),
                        decoration: InputDecoration(
                          labelText: 'Installed name contains',
                          labelStyle: TextStyle(color: _subTextColor),
                          helperText: 'Use a stable part of the name; do not include the version.',
                          helperStyle: TextStyle(color: _subTextColor, fontSize: 11),
                          prefixIcon: Icon(Icons.manage_search_rounded, color: _subTextColor),
                          filled: true,
                          fillColor: _fieldColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _borderColor)),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter matching text.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: publisher,
                        enabled: !busy,
                        style: TextStyle(color: _textColor),
                        decoration: InputDecoration(
                          labelText: 'Publisher contains (optional)',
                          labelStyle: TextStyle(color: _subTextColor),
                          prefixIcon: Icon(Icons.verified_outlined, color: _subTextColor),
                          filled: true,
                          fillColor: _fieldColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _borderColor)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: version,
                        enabled: !busy,
                        style: TextStyle(color: _textColor),
                        decoration: InputDecoration(
                          labelText: 'Minimum version (optional)',
                          labelStyle: TextStyle(color: _subTextColor),
                          prefixIcon: Icon(Icons.numbers_rounded, color: _subTextColor),
                          filled: true,
                          fillColor: _fieldColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _borderColor)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: accent.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 19, color: accent),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Syswatch reads embedded product details only. The EXE is not uploaded or installed.',
                                style: TextStyle(fontSize: 12.5, color: _textColor),
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
                style: TextButton.styleFrom(foregroundColor: _subTextColor),
                child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
              ),
              FilledButton.icon(
                onPressed: busy ? null : save,
                style: FilledButton.styleFrom(
                  backgroundColor: _buttonBg,
                  foregroundColor: _buttonFg,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: busy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _buttonFg),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  saving
                      ? 'Saving...'
                      : importing
                          ? 'Reading EXE...'
                          : 'Save to ${selectedRooms.length} room${selectedRooms.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
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
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final inventory = data.isNotEmpty ? data[0] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];
        final compliance = data.length > 1 ? data[1] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];
        final requiredSoftware = data.length > 2 ? data[2] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];

        if (_selectedRoom != null) {
          final roomInventory = inventory.where((r) => r['room_name'] == _selectedRoom).toList();
          final roomCompliance = compliance.where((r) => r['room_name'] == _selectedRoom).toList();
          final roomRequired = requiredSoftware.where((r) => r['room_name'] == _selectedRoom).toList();

          return RoomInventoryDetailScreen(
            roomName: _selectedRoom!,
            inventory: roomInventory,
            compliance: roomCompliance,
            requiredSoftware: roomRequired,
            onBack: () => setState(() => _selectedRoom = null),
            onRefresh: _refresh,
          );
        }

        final search = _searchController.text.trim().toLowerCase();
        final roomsSet = <String>{};
        for (var r in inventory) {
          if (r['room_name'] != null) roomsSet.add(r['room_name'].toString());
        }
        for (var r in compliance) {
          if (r['room_name'] != null) roomsSet.add(r['room_name'].toString());
        }
        for (var r in requiredSoftware) {
          if (r['room_name'] != null) roomsSet.add(r['room_name'].toString());
        }

        final filteredRooms = roomsSet.where((name) {
          if (search.isEmpty) return true;
          return name.toLowerCase().contains(search);
        }).toList()
          ..sort();

        final totalIssues = compliance.where((r) => !_isCompliant((r['status'] ?? 'unknown').toString())).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _buildToolbar(totalIssues),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _StatChip(icon: Icons.meeting_room_rounded, label: 'Rooms', value: '${roomsSet.length}', textColor: _textColor, subTextColor: _subTextColor, borderColor: _borderColor),
                  _StatChip(
                    icon: totalIssues == 0 ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                    label: totalIssues == 0 ? 'All compliant' : 'Issues',
                    value: totalIssues == 0 ? '' : '$totalIssues',
                    emphasize: totalIssues > 0,
                    textColor: _textColor,
                    subTextColor: _subTextColor,
                    borderColor: _borderColor,
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _refresh(),
                color: _accentAForeground,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (filteredRooms.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.meeting_room_outlined,
                                size: 64, color: _subTextColor.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text('No rooms found',
                                style: TextStyle(
                                    color: _textColor, fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text('Try adjusting your search or filters.',
                                style: TextStyle(color: _subTextColor, fontSize: 14)),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: Center(
                        child: Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: filteredRooms.map((roomName) {
                            final roomInventory = inventory.where((r) => r['room_name'] == roomName).toList();
                            final roomIssues = compliance
                                .where((r) =>
                                    r['room_name'] == roomName &&
                                    !_isCompliant((r['status'] ?? 'unknown').toString()))
                                .length;
                            return _buildRoomCard(roomName, roomInventory.length, roomIssues);
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(int totalIssues) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: _textColor, fontSize: 14),
            cursorColor: _accentAForeground,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search by room name',
              labelStyle: TextStyle(color: _subTextColor, fontSize: 13.5),
              prefixIcon: Icon(Icons.search_rounded, color: _subTextColor, size: 20),
              filled: true,
              fillColor: _fieldColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _accentAForeground, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildNotificationBadge(totalIssues),
        const SizedBox(width: 12),
        _buildIssuesOnlyToggle(),
        const SizedBox(width: 12),
        _buildAddButton(),
        const SizedBox(width: 10),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildNotificationBadge(int totalIssues) {
    if (totalIssues == 0) return const SizedBox.shrink();
    const activeColor = Color(0xFFFF6B6B);
    return Tooltip(
      message: '$totalIssues compliance issues detected',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: activeColor.withValues(alpha: 0.15),
          border: Border.all(color: activeColor.withValues(alpha: 0.5)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_active_rounded, size: 18, color: activeColor),
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _cardColor, width: 1.5),
                ),
                child: Text('$totalIssues',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesOnlyToggle() {
    final activeColor = _isDarkMode ? _accentA : _accentB;
    return GestureDetector(
      onTap: () => setState(() => _issuesOnly = !_issuesOnly),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _issuesOnly ? activeColor.withValues(alpha: 0.15) : _fieldColor,
          border: Border.all(color: _issuesOnly ? activeColor.withValues(alpha: 0.5) : _borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: _issuesOnly ? activeColor : _subTextColor),
            const SizedBox(width: 8),
            Text(
              'Issues only',
              style: TextStyle(
                fontSize: 13,
                fontWeight: _issuesOnly ? FontWeight.w600 : FontWeight.w400,
                color: _issuesOnly ? _textColor : _subTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _addRequiredSoftware,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _fieldColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.add_rounded, color: _accentAForeground, size: 18),
            const SizedBox(width: 8),
            Text(
              'Add Software',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
          ],
        ),
      ),
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
        icon: Icon(Icons.refresh_rounded, color: _accentBForeground, size: 20),
      ),
    );
  }

  Widget _buildRoomCard(String roomName, int pcCount, int issueCount) {
    if (_issuesOnly && issueCount == 0) return const SizedBox.shrink();

    return Container(
      width: 380,
      height: 110,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedRoom = roomName),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _fieldColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.meeting_room_rounded,
                    color: _accentAForeground,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        roomName,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.devices_rounded, size: 12, color: _subTextColor),
                          const SizedBox(width: 4),
                          Text(
                            '$pcCount workstation${pcCount == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: _subTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (issueCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8787)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$issueCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _fieldColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: _subTextColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel(this.text, {this.color, required this.subTextColor});
  final String text;
  final Color? color;
  final Color subTextColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: color ?? subTextColor,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon, 
    required this.label, 
    required this.value, 
    this.emphasize = false,
    required this.textColor,
    required this.subTextColor,
    required this.borderColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;
  final Color textColor;
  final Color subTextColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFFF7B84F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: emphasize ? activeColor : subTextColor),
          const SizedBox(width: 6),
          if (value.isNotEmpty) ...[
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: emphasize ? activeColor : textColor)),
            const SizedBox(width: 5),
          ],
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: emphasize ? activeColor : subTextColor)),
        ],
      ),
    );
  }
}
