import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/firestore_helpers.dart';

class LastKnownUserScreen extends StatefulWidget {
  const LastKnownUserScreen({super.key});

  @override
  State<LastKnownUserScreen> createState() => _LastKnownUserScreenState();
}

class _LastKnownUserScreenState extends State<LastKnownUserScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search room, PC, student, or email',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('login_logs')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load login records: ${snapshot.error}',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final latestByPc = <String, _LoginRecord>{};
              for (final document in snapshot.data!.docs) {
                final data = document.data();
                final room = stringFromFirestore(data['roomName']);
                final pc = stringFromFirestore(data['pcId']);
                final key =
                    room.isEmpty && pc.isEmpty ? document.id : '${room}_$pc';
                final loginTime =
                    data['loginTime'] ?? data['createdAt'] ?? data['timestamp'];
                final candidate = _LoginRecord(
                  data: data,
                  loginTime: loginTime,
                );
                final existing = latestByPc[key];

                if (existing == null ||
                    compareFirestoreTimestamps(
                          candidate.loginTime,
                          existing.loginTime,
                        ) >
                        0) {
                  latestByPc[key] = candidate;
                }
              }

              final search = _searchController.text.trim().toLowerCase();
              final rows = latestByPc.values.where((record) {
                if (search.isEmpty) return true;
                final data = record.data;
                final searchable = [
                  data['roomName'],
                  data['pcId'],
                  data['displayName'],
                  data['studentName'],
                  data['email'],
                  data['studentEmail'],
                  data['studentId'],
                ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
                return searchable.contains(search);
              }).toList()
                ..sort((a, b) {
                  final roomComparison = stringFromFirestore(
                    a.data['roomName'],
                  ).compareTo(
                    stringFromFirestore(b.data['roomName']),
                  );
                  if (roomComparison != 0) return roomComparison;
                  return stringFromFirestore(a.data['pcId']).compareTo(
                    stringFromFirestore(b.data['pcId']),
                  );
                });

              if (rows.isEmpty) {
                return const Center(
                  child: Text('No matching login records.'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final record = rows[index];
                  final data = record.data;
                  final room = stringFromFirestore(
                    data['roomName'],
                    fallback: 'Unknown room',
                  );
                  final pc = stringFromFirestore(
                    data['pcId'],
                    fallback: 'Unknown PC',
                  );
                  final name = stringFromFirestore(
                    data['displayName'] ?? data['studentName'],
                    fallback: stringFromFirestore(
                      data['email'] ?? data['studentEmail'],
                      fallback: 'Unknown user',
                    ),
                  );
                  final email = stringFromFirestore(
                    data['email'] ?? data['studentEmail'],
                  );
                  final studentId = stringFromFirestore(data['studentId']);
                  final status = stringFromFirestore(
                    data['status'],
                    fallback: 'logged in',
                  );

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_pin),
                      ),
                      title: Text('$room - $pc'),
                      subtitle: Text(
                        [
                          'Last user: $name',
                          if (email.isNotEmpty && email != name) email,
                          if (studentId.isNotEmpty) 'Student ID: $studentId',
                          'Login: '
                              '${formatFirestoreTimestamp(record.loginTime)}',
                        ].join('\n'),
                      ),
                      trailing: Chip(label: Text(status.toUpperCase())),
                      isThreeLine: true,
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

class _LoginRecord {
  final Map<String, dynamic> data;
  final dynamic loginTime;

  const _LoginRecord({
    required this.data,
    required this.loginTime,
  });
}
