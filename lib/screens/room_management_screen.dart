import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/firestore_helpers.dart';

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomController = TextEditingController();
  final _pcCountController = TextEditingController(text: '40');
  final _busyRoomIds = <String>{};

  bool _saving = false;

  @override
  void dispose() {
    _roomController.dispose();
    _pcCountController.dispose();
    super.dispose();
  }

  Future<void> _addRoom() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;

    final roomName = _roomController.text.trim();
    final count = int.parse(_pcCountController.text.trim());

    setState(() => _saving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final roomReference = firestore.collection('rooms').doc(roomName);
      final existingRoom = await roomReference.get();
      if (existingRoom.exists) {
        throw Exception('Room "$roomName" already exists.');
      }

      final existingPcs = await firestore
          .collection('pcs')
          .where('roomName', isEqualTo: roomName)
          .limit(1)
          .get();
      if (existingPcs.docs.isNotEmpty) {
        throw Exception(
          'PC records already use room "$roomName". '
          'Choose another room name.',
        );
      }

      final batch = firestore.batch();
      batch.set(roomReference, {
        'roomName': roomName,
        'pcCount': count,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (var number = 1; number <= count; number++) {
        final pcId = 'PC-${number.toString().padLeft(2, '0')}';
        final pcReference =
            firestore.collection('pcs').doc('${roomName}_$pcId');
        batch.set(pcReference, {
          'roomName': roomName,
          'pcId': pcId,
          'status': 'unknown',
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;
      _roomController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Room $roomName and $count PC records were created.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleRoom({
    required String roomId,
    required bool currentlyActive,
  }) async {
    if (_busyRoomIds.contains(roomId)) return;
    setState(() => _busyRoomIds.add(roomId));

    try {
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
        'active': !currentlyActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyRoomIds.remove(roomId));
      }
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
                    final fields = [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _roomController,
                          enabled: !_saving,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Room/Lab Name',
                            prefixIcon: Icon(Icons.meeting_room_outlined),
                          ),
                          validator: (value) {
                            final room = (value ?? '').trim();
                            if (room.isEmpty) {
                              return 'Room name is required.';
                            }
                            if (room.contains('/')) {
                              return 'Room name cannot contain "/".';
                            }
                            return null;
                          },
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _pcCountController,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'PC Count',
                            prefixIcon: Icon(Icons.computer),
                          ),
                          validator: (value) {
                            final count = int.tryParse((value ?? '').trim());
                            if (count == null) {
                              return 'Enter a number.';
                            }
                            if (count < 1 || count > 200) {
                              return 'Use 1 to 200.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _addRoom(),
                        ),
                      ),
                    ];

                    final addButton = FilledButton.icon(
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
                          for (var index = 0; index < fields.length; index++) ...[
                            Row(children: [fields[index]]),
                            if (index != fields.length - 1)
                              const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 12),
                          addButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        fields[0],
                        const SizedBox(width: 12),
                        fields[1],
                        const SizedBox(width: 12),
                        addButton,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance.collection('rooms').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load rooms: ${_cleanError(snapshot.error!)}',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final documents = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final aName = stringFromFirestore(
                    a.data()['roomName'],
                    fallback: a.id,
                  );
                  final bName = stringFromFirestore(
                    b.data()['roomName'],
                    fallback: b.id,
                  );
                  return aName.compareTo(bName);
                });

              if (documents.isEmpty) {
                return const Center(child: Text('No rooms have been added.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final document = documents[index];
                  final data = document.data();
                  final active = boolFromFirestore(
                    data['active'],
                    fallback: true,
                  );
                  final busy = _busyRoomIds.contains(document.id);

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          active ? Icons.meeting_room : Icons.block,
                        ),
                      ),
                      title: Text(
                        stringFromFirestore(
                          data['roomName'],
                          fallback: document.id,
                        ),
                      ),
                      subtitle: Text(
                        'PC Count: ${data['pcCount'] ?? 'Not set'}',
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
                                Text(active ? 'Active' : 'Inactive'),
                                const SizedBox(width: 8),
                                Switch(
                                  value: active,
                                  onChanged: (_) => _toggleRoom(
                                    roomId: document.id,
                                    currentlyActive: active,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

String _cleanError(Object error) {
  return error.toString().replaceFirst('Exception:', '').trim();
}
