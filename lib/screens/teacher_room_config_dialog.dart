import 'package:flutter/material.dart';

import '../services/teacher_service.dart';
import '../utils/value_helpers.dart';

/// Protected Teacher PC configuration opened with Ctrl + Shift + A.
///
/// It is intentionally separate from normal Teacher access. The signed-in
/// Windows user can use the Teacher app without a SysWatch password, but room
/// configuration requires an Admin or Super Admin credential check.
class TeacherRoomConfigDialog extends StatefulWidget {
  const TeacherRoomConfigDialog({super.key});

  @override
  State<TeacherRoomConfigDialog> createState() =>
      _TeacherRoomConfigDialogState();
}

class _TeacherRoomConfigDialogState extends State<TeacherRoomConfigDialog> {
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _roomController = TextEditingController();
  final _pcCountController = TextEditingController(text: '40');
  final _verifyKey = GlobalKey<FormState>();
  final _saveKey = GlobalKey<FormState>();

  bool _passwordVisible = false;
  bool _verifying = false;
  bool _saving = false;
  bool _verified = false;
  String? _error;
  String? _selectedTeacherUid;
  List<Map<String, dynamic>> _teachers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _rooms = <Map<String, dynamic>>[];

  @override
  void dispose() {
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _roomController.dispose();
    _pcCountController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((item) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  Future<void> _verifyAdmin() async {
    if (_verifying || !(_verifyKey.currentState?.validate() ?? false)) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final response = await TeacherService.instance.loadRoomConfiguration(
        adminEmail: _adminEmailController.text,
        adminPassword: _adminPasswordController.text,
      );
      final teachers = _mapList(response['teachers']);
      final rooms = _mapList(response['rooms']);
      if (teachers.isEmpty) {
        throw Exception(
          'No active Teacher account exists. Create the Teacher account in '
          'the Admin application first.',
        );
      }

      final first = teachers.first;
      final assigned = (first['assigned_room_name'] ?? '').toString().trim();
      Map<String, dynamic>? assignedRoom;
      if (assigned.isNotEmpty) {
        for (final room in rooms) {
          if ((room['room_name'] ?? '').toString().toLowerCase() ==
              assigned.toLowerCase()) {
            assignedRoom = room;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _teachers = teachers;
        _rooms = rooms;
        _selectedTeacherUid = (first['uid'] ?? '').toString();
        _verified = true;
        _verifying = false;
        _roomController.text = assigned;
        if (assignedRoom != null) {
          _pcCountController.text =
              (assignedRoom['pc_count'] ?? 40).toString();
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verified = false;
        _error = cleanError(error);
      });
    }
  }

  void _selectTeacher(String? uid) {
    if (uid == null || uid.isEmpty) return;
    final teacher = _teachers.firstWhere(
      (item) => (item['uid'] ?? '').toString() == uid,
      orElse: () => const <String, dynamic>{},
    );
    final assigned = (teacher['assigned_room_name'] ?? '').toString().trim();
    Map<String, dynamic>? assignedRoom;
    if (assigned.isNotEmpty) {
      for (final room in _rooms) {
        if ((room['room_name'] ?? '').toString().toLowerCase() ==
            assigned.toLowerCase()) {
          assignedRoom = room;
          break;
        }
      }
    }

    setState(() {
      _selectedTeacherUid = uid;
      _roomController.text = assigned;
      if (assignedRoom != null) {
        _pcCountController.text = (assignedRoom['pc_count'] ?? 40).toString();
      }
    });
  }

  void _selectRoom(Map<String, dynamic> room) {
    setState(() {
      _roomController.text = (room['room_name'] ?? '').toString();
      _pcCountController.text = (room['pc_count'] ?? 40).toString();
    });
  }

  Future<void> _save() async {
    if (_saving || !(_saveKey.currentState?.validate() ?? false)) return;
    final uid = (_selectedTeacherUid ?? '').trim();
    if (uid.isEmpty) {
      setState(() => _error = 'Select the Teacher account.');
      return;
    }

    final pcCount = int.tryParse(_pcCountController.text.trim());
    if (pcCount == null || pcCount < 1 || pcCount > 200) {
      setState(() => _error = 'PC count must be from 1 to 200.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await TeacherService.instance.configureRoom(
        adminEmail: _adminEmailController.text,
        adminPassword: _adminPasswordController.text,
        teacherUid: uid,
        roomName: _roomController.text,
        pcCount: pcCount,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = cleanError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final card = dark ? const Color(0xFF13141A) : Colors.white;
    final field = dark ? const Color(0xFF1C1E26) : const Color(0xFFF2F4F7);
    final text = dark ? Colors.white : const Color(0xFF1A1C1E);
    final sub = dark ? Colors.white60 : Colors.black54;
    final accent = dark ? const Color(0xFFFFD700) : const Color(0xFF003366);

    InputDecoration decoration(String label, {String? helper}) {
      return InputDecoration(
        labelText: label,
        helperText: helper,
        filled: true,
        fillColor: field,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
    }

    return AlertDialog(
      backgroundColor: card,
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.admin_panel_settings_rounded, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teacher Room Configuration',
                  style: TextStyle(
                    color: text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Protected shortcut: Ctrl + Shift + A',
                  style: TextStyle(color: sub, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Form(
                key: _verifyKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _adminEmailController,
                      enabled: !_verifying && !_saving,
                      keyboardType: TextInputType.emailAddress,
                      decoration: decoration('Admin / Super Admin Email'),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Enter the administrator email.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _adminPasswordController,
                      enabled: !_verifying && !_saving,
                      obscureText: !_passwordVisible,
                      decoration: decoration('Password').copyWith(
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible,
                          ),
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                      validator: (value) => (value ?? '').isEmpty
                          ? 'Enter the administrator password.'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _verifying || _saving ? null : _verifyAdmin,
                  icon: _verifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_user_rounded),
                  label: Text(_verified ? 'Refresh / Verify Again' : 'Verify Admin'),
                ),
              ),
              if (_verified) ...[
                const SizedBox(height: 20),
                Divider(color: sub.withValues(alpha: 0.25)),
                const SizedBox(height: 12),
                Form(
                  key: _saveKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedTeacherUid,
                        isExpanded: true,
                        decoration: decoration('Teacher Account'),
                        items: _teachers.map((teacher) {
                          final uid = (teacher['uid'] ?? '').toString();
                          final name = (teacher['display_name'] ?? 'Teacher').toString();
                          final email = (teacher['email'] ?? '').toString();
                          final room = (teacher['assigned_room_name'] ?? '').toString();
                          return DropdownMenuItem(
                            value: uid,
                            child: Text(
                              room.isEmpty
                                  ? '$name · $email'
                                  : '$name · $email · Room $room',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _saving ? null : _selectTeacher,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _roomController,
                        enabled: !_saving,
                        decoration: decoration(
                          'Laboratory Room',
                          helper: _rooms.isEmpty
                              ? 'No rooms exist yet. Enter a room name and it will be created.'
                              : 'Enter a new room or choose an existing room below.',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter the laboratory room.'
                            : null,
                      ),
                      if (_rooms.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _rooms.map((room) {
                            final roomName = (room['room_name'] ?? '').toString();
                            final active = room['active'] == true ||
                                room['active'] == 1 ||
                                room['active'].toString() == '1';
                            return ActionChip(
                              avatar: Icon(
                                Icons.meeting_room_rounded,
                                size: 17,
                                color: active ? accent : sub,
                              ),
                              label: Text(
                                '$roomName (${room['pc_count'] ?? 0} PCs)'
                                '${active ? '' : ' · inactive'}',
                              ),
                              onPressed: _saving ? null : () => _selectRoom(room),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pcCountController,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: decoration(
                          'PC Count',
                          helper: 'Used by the Teacher Lab Map. Allowed range: 1–200.',
                        ),
                        validator: (value) {
                          final count = int.tryParse((value ?? '').trim());
                          if (count == null || count < 1 || count > 200) {
                            return 'Enter a PC count from 1 to 200.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (_verified)
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving...' : 'Save Teacher Room'),
          ),
      ],
    );
  }
}
