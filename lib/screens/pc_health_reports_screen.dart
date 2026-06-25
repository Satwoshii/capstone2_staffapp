import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'staff_dashboard_screen.dart';

class PcHealthReportsScreen extends StatelessWidget {
  const PcHealthReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('pc_status').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        docs.sort((a, b) => formatTimestamp(b.data()['lastCheck']).compareTo(formatTimestamp(a.data()['lastCheck'])));

        if (docs.isEmpty) {
          return const Center(child: Text('No PC health records yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final status = (data['status'] ?? 'unknown').toString();
            final broken = status.toLowerCase() == 'broken';

            return Card(
              child: ListTile(
                leading: Icon(
                  broken ? Icons.warning : Icons.check_circle,
                  color: broken ? Colors.red : Colors.green,
                ),
                title: Text('${data['roomName'] ?? ''} - ${data['pcId'] ?? docs[index].id}'),
                subtitle: Text('Status: $status\nLast check: ${data['lastCheck'] ?? ''}\n${data['details'] ?? ''}'),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}
