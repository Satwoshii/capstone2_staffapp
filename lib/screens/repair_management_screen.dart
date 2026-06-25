import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import 'staff_dashboard_screen.dart';

class RepairManagementScreen extends StatelessWidget {
  final AppUser user;

  const RepairManagementScreen({super.key, required this.user});

  Future<void> _markRepaired(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final notesController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as Repaired'),
        content: TextField(
          controller: notesController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Technician notes',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (confirm != true) return;

    final data = doc.data();
    final now = DateTime.now().toIso8601String();

    await doc.reference.set({
      'repaired': 1,
      'repairedAt': now,
      'technicianNotes': notesController.text.trim(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('maintenance_logs').add({
      'faultReportId': doc.id,
      'roomName': data['roomName'],
      'pcId': data['pcId'],
      'technicianName': user.displayName.isEmpty ? user.email : user.displayName,
      'notes': notesController.text.trim(),
      'repairDate': now,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('fault_reports').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        docs.sort((a, b) => formatTimestamp(b.data()['createdAt']).compareTo(formatTimestamp(a.data()['createdAt'])));

        if (docs.isEmpty) return const Center(child: Text('No fault reports yet.'));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final repaired = data['repaired'] == 1 || data['repaired'] == true;

            return Card(
              child: ListTile(
                leading: Icon(repaired ? Icons.check_circle : Icons.build_circle, color: repaired ? Colors.green : Colors.orange),
                title: Text('${data['roomName'] ?? ''} - ${data['pcId'] ?? ''}'),
                subtitle: Text('${data['issue'] ?? ''}\n${data['details'] ?? ''}\nCreated: ${data['createdAt'] ?? ''}'),
                isThreeLine: true,
                trailing: repaired
                    ? const Text('Repaired')
                    : ElevatedButton(
                        onPressed: () => _markRepaired(context, doc),
                        child: const Text('Mark Repaired'),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
