import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'staff_dashboard_screen.dart';

class LastKnownUserScreen extends StatelessWidget {
  const LastKnownUserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('login_logs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final latestByPc = <String, Map<String, dynamic>>{};
        for (final doc in snapshot.data!.docs) {
          final data = doc.data();
          final key = '${data['roomName'] ?? ''}_${data['pcId'] ?? ''}';
          final existing = latestByPc[key];
          if (existing == null || formatTimestamp(data['loginTime']).compareTo(formatTimestamp(existing['loginTime'])) > 0) {
            latestByPc[key] = data;
          }
        }

        final rows = latestByPc.values.toList()
          ..sort((a, b) => '${a['roomName']}_${a['pcId']}'.compareTo('${b['roomName']}_${b['pcId']}'));

        if (rows.isEmpty) return const Center(child: Text('No login records yet.'));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final data = rows[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person_pin),
                title: Text('${data['roomName'] ?? ''} - ${data['pcId'] ?? ''}'),
                subtitle: Text('Last user: ${data['displayName'] ?? data['email'] ?? ''}\nStudent ID: ${data['studentId'] ?? ''}\nLogin: ${data['loginTime'] ?? ''}\nStatus: ${data['status'] ?? ''}'),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}
