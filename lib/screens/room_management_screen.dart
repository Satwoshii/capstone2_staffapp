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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room created successfully.')),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cleanError(error))),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cleanError(error))),
      );
    } finally {
      if (mounted) setState(() => _busyRooms.remove(room.roomName));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final roomField = TextFormField(
                      controller: _roomController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Room/Lab Name',
                        prefixIcon: Icon(Icons.meeting_room_outlined),
                      ),
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
                      decoration: const InputDecoration(
                        labelText: 'Planned PC Count',
                        prefixIcon: Icon(Icons.computer),
                      ),
                      validator: (value) {
                        final count = int.tryParse((value ?? '').trim());
                        if (count == null) return 'Enter a number.';
                        if (count < 1 || count > 200) return 'Use 1 to 200.';
                        return null;
                      },
                      onFieldSubmitted: (_) => _addRoom(),
                    );
                    final button = FilledButton.icon(
                      onPressed: _saving ? null : _addRoom,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(_saving ? 'Creating...' : 'Add Room'),
                    );

                    if (constraints.maxWidth < 700) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          roomField,
                          const SizedBox(height: 12),
                          countField,
                          const SizedBox(height: 12),
                          button,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(flex: 2, child: roomField),
                        const SizedBox(width: 12),
                        Expanded(child: countField),
                        const SizedBox(width: 12),
                        button,
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<RoomRecord>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
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
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final busy = _busyRooms.contains(room.roomName);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            room.active ? Icons.meeting_room : Icons.block,
                          ),
                        ),
                        title: Text(room.roomName),
                        subtitle: Text(
                          'Planned PCs: ${room.pcCount}\n'
                          'Registered workstations: ${room.registeredPcCount}',
                        ),
                        trailing: busy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(room.active ? 'Active' : 'Inactive'),
                                  const SizedBox(width: 8),
                                  Switch(
                                    value: room.active,
                                    onChanged: (_) => _toggleRoom(room),
                                  ),
                                ],
                              ),
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
