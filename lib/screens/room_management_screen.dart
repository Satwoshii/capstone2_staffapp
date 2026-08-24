import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/room_record.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/message_state.dart';

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomController = TextEditingController();
  final _pcCountController = TextEditingController(text: '40');
  final _busyRooms = <String>{};
  Future<List<RoomRecord>>? _future;
  Timer? _timer;
  bool _saving = false;

  // ── Palette (matches StaffLoginScreen / SupportChatScreen) ─────────────────
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor =>
      _isDarkMode ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _accentA => const Color(0xFFC0C0C0);
  Color get _accentB => const Color(0xFF000000);
  Color get _accentAForeground =>
      _isDarkMode ? _accentA : const Color(0xFF606060);
  Color get _accentBForeground => _isDarkMode ? Colors.white : _accentB;
  Color get _textColor =>
      _isDarkMode ? Colors.white : const Color(0xFF1A1C1E);
  Color get _subTextColor => _isDarkMode ? Colors.white54 : Colors.black45;
  Color get _borderColor => _isDarkMode
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.09);
  Color get _errorColor => const Color(0xFFFF6B6B);
  Color get _successColor => _accentAForeground;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _roomController.dispose();
    _pcCountController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _future = StaffService.instance.listRooms();
    });
  }

  Future<void> _addRoom() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await StaffService.instance.createRoom(
        roomName: _roomController.text,
        pcCount: int.parse(_pcCountController.text.trim()),
      );
      if (!mounted) return;
      _roomController.clear();
      _showMessage('Room created successfully.');
      _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMessage(cleanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleRoom(RoomRecord room) async {
    if (_busyRooms.contains(room.roomName)) return;
    setState(() => _busyRooms.add(room.roomName));
    try {
      await StaffService.instance.setRoomActive(
        roomName: room.roomName,
        active: !room.active,
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMessage(cleanError(error));
    } finally {
      if (mounted) setState(() => _busyRooms.remove(room.roomName));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Input decoration (matches StaffLoginScreen) ─────────────────────────
  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _subTextColor, fontSize: 14),
      prefixIcon: Icon(icon, color: _subTextColor.withValues(alpha: 0.45), size: 20),
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
        borderSide: BorderSide(color: _accentA, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _errorColor, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _errorColor, width: 1.5),
      ),
      errorStyle: TextStyle(color: _errorColor, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bgColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: _buildAddRoomCard(),
          ),
          Expanded(
            child: FutureBuilder<List<RoomRecord>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                        color: _accentAForeground, strokeWidth: 2.5),
                  );
                }
                if (snapshot.hasError) {
                  return MessageState(
                    icon: Icons.wifi_off,
                    title: 'Could not load rooms',
                    message: cleanError(snapshot.error!),
                    onRetry: _refresh,
                  );
                }
                final rooms = snapshot.data ?? const <RoomRecord>[];
                if (rooms.isEmpty) {
                  return const MessageState(
                    icon: Icons.meeting_room_outlined,
                    title: 'No rooms yet',
                    message: 'Add the first laboratory room above.',
                  );
                }
                return RefreshIndicator(
                  color: _accentAForeground,
                  backgroundColor: _cardColor,
                  onRefresh: () async => _refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      return _buildRoomTile(rooms[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRoomCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.4 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final roomField = TextFormField(
              controller: _roomController,
              enabled: !_saving,
              style: TextStyle(color: _textColor, fontSize: 15),
              cursorColor: _accentAForeground,
              decoration: _fieldDecoration('Room/Lab Name', Icons.meeting_room_outlined),
              validator: (value) {
                final room = (value ?? '').trim();
                if (room.isEmpty) return 'Room name is required.';
                if (room.contains('/')) return 'Room cannot contain "/".';
                return null;
              },
            );
            final countField = TextFormField(
              controller: _pcCountController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: _textColor, fontSize: 15),
              cursorColor: _accentAForeground,
              decoration: _fieldDecoration('Planned PC Count', Icons.computer),
              validator: (value) {
                final count = int.tryParse((value ?? '').trim());
                if (count == null) return 'Enter a number.';
                if (count < 1 || count > 200) return 'Use 1 to 200.';
                return null;
              },
              onFieldSubmitted: (_) => _addRoom(),
            );
            final button = _buildAddButton();
            final refreshButton = _buildRefreshButton();

            if (constraints.maxWidth < 700) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  roomField,
                  const SizedBox(height: 12),
                  countField,
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: button),
                      const SizedBox(width: 10),
                      refreshButton,
                    ],
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 2, child: roomField),
                const SizedBox(width: 12),
                Expanded(child: countField),
                const SizedBox(width: 12),
                button,
                const SizedBox(width: 8),
                refreshButton,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    final bgColor = _saving
        ? _accentA.withValues(alpha: 0.25)
        : (_isDarkMode ? _accentA : _accentB);
    final fgColor = _isDarkMode ? Colors.black : Colors.white;

    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _saving
              ? []
              : [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _saving ? null : _addRoom,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_saving)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                      ),
                    )
                  else
                    Icon(Icons.add, color: fgColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _saving ? 'Creating...' : 'Add Room',
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return SizedBox(
      width: 52,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _fieldColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _refresh,
            child: Icon(Icons.refresh, color: _subTextColor, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomTile(RoomRecord room) {
    final busy = _busyRooms.contains(room.roomName);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: room.active ? _accentA.withValues(alpha: 0.25) : _borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: room.active
                  ? (_isDarkMode ? _accentA : _accentB)
                  : _fieldColor,
              border: Border.all(
                color: room.active
                    ? _accentA.withValues(alpha: 0.35)
                    : _borderColor,
                width: 1.2,
              ),
            ),
            child: Icon(
              room.active ? Icons.meeting_room : Icons.block,
              color: room.active
                  ? (_isDarkMode ? Colors.black : Colors.white)
                  : _subTextColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.roomName,
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Planned PCs: ${room.pcCount}  •  Registered: ${room.registeredPcCount}',
                  style: TextStyle(color: _subTextColor, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          busy
              ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _accentAForeground,
            ),
          )
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                room.active ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: room.active ? _successColor : _subTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: 8),
              _ThemedSwitch(
                value: room.active,
                onChanged: (_) => _toggleRoom(room),
                accentA: _accentA,
                accentB: _accentB,
                fieldColor: _fieldColor,
                borderColor: _borderColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemedSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accentA;
  final Color accentB;
  final Color fieldColor;
  final Color borderColor;

  const _ThemedSwitch({
    required this.value,
    required this.onChanged,
    required this.accentA,
    required this.accentB,
    required this.fieldColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value
                ? (Theme.of(context).brightness == Brightness.dark
                    ? accentA
                    : accentB)
                : fieldColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: value ? Colors.transparent : borderColor),
          ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}