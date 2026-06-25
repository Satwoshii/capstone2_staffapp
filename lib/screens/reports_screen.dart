import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/dashboard_card.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('fault_reports').snapshots(),
      builder: (context, faultSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('login_logs').snapshots(),
          builder: (context, loginSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('pc_status').snapshots(),
              builder: (context, pcSnapshot) {
                final faults = faultSnapshot.data?.docs ?? [];
                final logins = loginSnapshot.data?.docs ?? [];
                final pcs = pcSnapshot.data?.docs ?? [];

                final pending = faults.where((d) {
                  final repaired = d.data()['repaired'];
                  return repaired != 1 && repaired != true;
                }).length;
                final repaired = faults.length - pending;
                final broken = pcs.where((d) => (d.data()['status'] ?? '').toString().toLowerCase() == 'broken').length;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        DashboardCard(title: 'Total Fault Reports', value: faults.length.toString(), icon: Icons.report, color: Colors.red),
                        DashboardCard(title: 'Pending Repairs', value: pending.toString(), icon: Icons.build, color: Colors.orange),
                        DashboardCard(title: 'Repaired', value: repaired.toString(), icon: Icons.check_circle, color: Colors.green),
                        DashboardCard(title: 'Broken PCs', value: broken.toString(), icon: Icons.warning, color: Colors.red),
                        DashboardCard(title: 'Login Logs', value: logins.length.toString(), icon: Icons.history, color: Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'This screen summarizes synced Firebase data from the Student PC App.',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
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
