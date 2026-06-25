import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  final roomController = TextEditingController();
  final pcCountController = TextEditingController(text: '40');

  @override
  void dispose() {
    roomController.dispose();
    pcCountController.dispose();
    super.dispose();
  }

  Future<void> _addRoom() async {
    final roomName = roomController.text.trim();
    final count = int.tryParse(pcCountController.text.trim()) ?? 40;
    if (roomName.isEmpty) return;

    await FirebaseFirestore.instance.collection('rooms').doc(roomName).set({
      'roomName': roomName,
      'pcCount': count,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (int i = 1; i <= count; i++) {
      final pcId = 'PC-${i.toString().padLeft(2, '0')}';
      await FirebaseFirestore.instance.collection('pcs').doc('${roomName}_$pcId').set({
        'roomName': roomName,
        'pcId': pcId,
        'status': 'unknown',
        'active': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    roomController.clear();
  }

  Future<void> _toggleRoom(String id, bool active) async {
    await FirebaseFirestore.instance.collection('rooms').doc(id).set({
      'active': !active,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: roomController,
                    decoration: const InputDecoration(labelText: 'Room/Lab Name', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: pcCountController,
                    decoration: const InputDecoration(labelText: 'PC Count', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(onPressed: _addRoom, icon: const Icon(Icons.add), label: const Text('Add Room')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Card(child: ListTile(title: Text('No rooms yet.')));
            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final active = data['active'] != false;
                return Card(
                  child: ListTile(
                    leading: Icon(active ? Icons.meeting_room : Icons.block),
                    title: Text(data['roomName'] ?? doc.id),
                    subtitle: Text('PC Count: ${data['pcCount'] ?? ''}'),
                    trailing: Switch(value: active, onChanged: (_) => _toggleRoom(doc.id, active)),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
