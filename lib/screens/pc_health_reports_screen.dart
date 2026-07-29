import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/firestore_helpers.dart';

class PcHealthReportsScreen extends StatefulWidget {
  const PcHealthReportsScreen({super.key});

  @override
  State<PcHealthReportsScreen> createState() => _PcHealthReportsScreenState();
}

class _PcHealthReportsScreenState extends State<PcHealthReportsScreen> {
  final _searchController = TextEditingController();
  bool _issuesOnly = false;

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
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search room or PC',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    selected: _issuesOnly,
                    avatar: const Icon(Icons.warning_amber, size: 18),
                    label: const Text('Issues only'),
                    onSelected: (value) {
                      setState(() => _issuesOnly = value);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('pc_status')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load PC health: ${snapshot.error}',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final search = _searchController.text.trim().toLowerCase();
              final documents = snapshot.data!.docs.where((document) {
                final data = document.data();
                final status =
                    stringFromFirestore(data['status'], fallback: 'unknown');
                final style = _styleForStatus(status);

                if (_issuesOnly && style.isHealthy) return false;
                if (search.isEmpty) return true;

                final searchable = [
                  data['roomName'],
                  data['pcId'],
                  status,
                  document.id,
                ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
                return searchable.contains(search);
              }).toList()
                ..sort(
                  (a, b) => compareFirestoreTimestamps(
                    b.data()['lastCheck'] ?? b.data()['updatedAt'],
                    a.data()['lastCheck'] ?? a.data()['updatedAt'],
                  ),
                );

              if (documents.isEmpty) {
                return Center(
                  child: Text(
                    _issuesOnly
                        ? 'No PC issues match the current filter.'
                        : 'No PC health records yet.',
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final document = documents[index];
                  final data = document.data();
                  final status =
                      stringFromFirestore(data['status'], fallback: 'unknown');
                  final style = _styleForStatus(status);
                  final room = stringFromFirestore(
                    data['roomName'],
                    fallback: 'Unknown room',
                  );
                  final pc = stringFromFirestore(
                    data['pcId'],
                    fallback: document.id,
                  );
                  final details = _healthDetails(data);
                  final lastCheck =
                      data['lastCheck'] ?? data['updatedAt'] ?? data['timestamp'];

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: style.color.withOpacity(0.14),
                        child: Icon(style.icon, color: style.color),
                      ),
                      title: Text('$room - $pc'),
                      subtitle: Text(
                        [
                          'Last check: ${formatFirestoreTimestamp(lastCheck)}',
                          if (details.isNotEmpty) details,
                        ].join('\n'),
                      ),
                      trailing: Chip(
                        avatar: Icon(style.icon, size: 18, color: style.color),
                        label: Text(status.toUpperCase()),
                      ),
                      isThreeLine: details.isNotEmpty,
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

  String _healthDetails(Map<String, dynamic> data) {
    final directDetails = readableFirestoreValue(
      data['details'] ?? data['issues'] ?? data['detectedIssues'],
    );
    if (directDetails.isNotEmpty) return directDetails;

    final parts = <String>[
      if (data.containsKey('cpu')) 'CPU: ${readableFirestoreValue(data['cpu'])}',
      if (data.containsKey('ram')) 'RAM: ${readableFirestoreValue(data['ram'])}',
      if (data.containsKey('disk'))
        'Disk: ${readableFirestoreValue(data['disk'])}',
      if (data.containsKey('storage'))
        'Storage: ${readableFirestoreValue(data['storage'])}',
      if (data.containsKey('keyboard'))
        'Keyboard: ${readableFirestoreValue(data['keyboard'])}',
      if (data.containsKey('mouse'))
        'Mouse: ${readableFirestoreValue(data['mouse'])}',
      if (data.containsKey('monitor'))
        'Monitor: ${readableFirestoreValue(data['monitor'])}',
      if (data.containsKey('ethernet'))
        'Ethernet: ${readableFirestoreValue(data['ethernet'])}',
    ];

    return parts.join(' • ');
  }
}

class _HealthStyle {
  final IconData icon;
  final Color color;
  final bool isHealthy;

  const _HealthStyle(this.icon, this.color, this.isHealthy);
}

_HealthStyle _styleForStatus(String value) {
  final status = value.trim().toLowerCase();

  if (status == 'healthy' ||
      status == 'ok' ||
      status == 'online' ||
      status == 'normal' ||
      status == 'working') {
    return const _HealthStyle(Icons.check_circle, Colors.green, true);
  }

  if (status.contains('critical') ||
      status.contains('broken') ||
      status.contains('offline') ||
      status.contains('failed')) {
    return const _HealthStyle(Icons.error, Colors.red, false);
  }

  if (status.contains('minor') ||
      status.contains('high') ||
      status.contains('warning') ||
      status.contains('degraded')) {
    return const _HealthStyle(Icons.warning_amber, Colors.orange, false);
  }

  return const _HealthStyle(Icons.help_outline, Colors.blueGrey, false);
}
