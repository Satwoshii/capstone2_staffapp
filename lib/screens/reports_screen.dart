import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/firestore_helpers.dart';
import '../widgets/dashboard_card.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('fault_reports').snapshots(),
      builder: (context, faultSnapshot) {
        if (faultSnapshot.hasError) {
          return _ReportError(error: faultSnapshot.error!);
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance.collection('login_logs').snapshots(),
          builder: (context, loginSnapshot) {
            if (loginSnapshot.hasError) {
              return _ReportError(error: loginSnapshot.error!);
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance.collection('pc_status').snapshots(),
              builder: (context, pcSnapshot) {
                if (pcSnapshot.hasError) {
                  return _ReportError(error: pcSnapshot.error!);
                }

                if (!faultSnapshot.hasData ||
                    !loginSnapshot.hasData ||
                    !pcSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final faults = faultSnapshot.data!.docs;
                final logins = loginSnapshot.data!.docs;
                final pcs = pcSnapshot.data!.docs;

                final pending = faults.where((document) {
                  return !boolFromFirestore(document.data()['repaired']);
                }).length;
                final repaired = faults.length - pending;
                final pcIssues = pcs.where((document) {
                  final status = stringFromFirestore(
                    document.data()['status'],
                  ).toLowerCase();
                  if (status.isEmpty ||
                      status == 'unknown' ||
                      status == 'not checked') {
                    return false;
                  }
                  return status != 'healthy' &&
                      status != 'ok' &&
                      status != 'normal' &&
                      status != 'online' &&
                      status != 'working';
                }).length;

                final recentFaults = faults.toList()
                  ..sort(
                    (a, b) => compareFirestoreTimestamps(
                      b.data()['createdAt'],
                      a.data()['createdAt'],
                    ),
                  );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        DashboardCard(
                          title: 'Fault Reports',
                          value: faults.length.toString(),
                          icon: Icons.report,
                          color: Colors.red,
                        ),
                        DashboardCard(
                          title: 'Pending Repairs',
                          value: pending.toString(),
                          icon: Icons.build,
                          color: Colors.orange,
                        ),
                        DashboardCard(
                          title: 'Completed Repairs',
                          value: repaired.toString(),
                          icon: Icons.check_circle,
                          color: Colors.green,
                        ),
                        DashboardCard(
                          title: 'PCs With Issues',
                          value: pcIssues.toString(),
                          icon: Icons.warning,
                          color: Colors.red,
                        ),
                        DashboardCard(
                          title: 'Login Records',
                          value: logins.length.toString(),
                          icon: Icons.history,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Recent Fault Reports',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 10),
                    if (recentFaults.isEmpty)
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.inbox_outlined),
                          title: Text('No synchronized fault reports yet.'),
                        ),
                      )
                    else
                      for (final document in recentFaults.take(5))
                        _RecentFaultTile(document: document),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RecentFaultTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  const _RecentFaultTile({required this.document});

  @override
  Widget build(BuildContext context) {
    final data = document.data();
    final repaired = boolFromFirestore(data['repaired']);
    final room = stringFromFirestore(
      data['roomName'],
      fallback: 'Unknown room',
    );
    final pc = stringFromFirestore(
      data['pcId'],
      fallback: 'Unknown PC',
    );
    final issue = readableFirestoreValue(
      data['issue'] ??
          data['issues'] ??
          data['detectedIssues'] ??
          data['faultType'],
    );

    return Card(
      child: ListTile(
        leading: Icon(
          repaired ? Icons.check_circle : Icons.warning_amber,
          color: repaired ? Colors.green : Colors.orange,
        ),
        title: Text('$room - $pc'),
        subtitle: Text(
          [
            if (issue.isNotEmpty) issue,
            formatFirestoreTimestamp(data['createdAt']),
          ].join('\n'),
        ),
        trailing: Chip(
          label: Text(repaired ? 'REPAIRED' : 'PENDING'),
        ),
      ),
    );
  }
}

class _ReportError extends StatelessWidget {
  final Object error;

  const _ReportError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 52,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text('Could not load the report summary.'),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
