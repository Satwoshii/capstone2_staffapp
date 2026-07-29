import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../utils/firestore_helpers.dart';

class RepairManagementScreen extends StatefulWidget {
  final AppUser user;

  const RepairManagementScreen({super.key, required this.user});

  @override
  State<RepairManagementScreen> createState() =>
      _RepairManagementScreenState();
}

class _RepairManagementScreenState extends State<RepairManagementScreen> {
  final _updatingReportIds = <String>{};
  bool _pendingOnly = true;

  Future<void> _markRepaired(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    if (_updatingReportIds.contains(document.id)) return;

    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final notes = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mark as Repaired'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: notesController,
                autofocus: true,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Technician notes',
                  hintText: 'Describe the action taken or part replaced.',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Technician notes are required.';
                  }
                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.of(dialogContext).pop(notesController.text.trim());
              },
              icon: const Icon(Icons.check),
              label: const Text('Save Repair'),
            ),
          ],
        );
      },
    );

    notesController.dispose();
    if (notes == null) return;

    setState(() => _updatingReportIds.add(document.id));

    try {
      final firestore = FirebaseFirestore.instance;
      final maintenanceReference =
          firestore.collection('maintenance_logs').doc();
      final data = document.data();
      final batch = firestore.batch();

      batch.set(
        document.reference,
        {
          'repaired': true,
          'status': 'repaired',
          'repairedAt': FieldValue.serverTimestamp(),
          'repairedByUid': widget.user.uid,
          'technicianName': widget.user.displayName.isEmpty
              ? widget.user.email
              : widget.user.displayName,
          'technicianNotes': notes,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(maintenanceReference, {
        'faultReportId': document.id,
        'roomName': data['roomName'],
        'pcId': data['pcId'],
        'technicianUid': widget.user.uid,
        'technicianEmail': widget.user.email,
        'technicianName': widget.user.displayName.isEmpty
            ? widget.user.email
            : widget.user.displayName,
        'notes': notes,
        'repairDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Repair saved successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save repair: ${_cleanError(error)}')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingReportIds.remove(document.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Card(
            child: SwitchListTile(
              value: _pendingOnly,
              title: const Text('Show pending repairs only'),
              subtitle: const Text(
                'Turn this off to include completed maintenance records.',
              ),
              secondary: const Icon(Icons.filter_alt_outlined),
              onChanged: (value) => setState(() => _pendingOnly = value),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('fault_reports')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load fault reports: '
                    '${_cleanError(snapshot.error!)}',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final documents = snapshot.data!.docs.where((document) {
                final repaired = boolFromFirestore(
                  document.data()['repaired'],
                );
                return !_pendingOnly || !repaired;
              }).toList()
                ..sort(
                  (a, b) => compareFirestoreTimestamps(
                    b.data()['createdAt'],
                    a.data()['createdAt'],
                  ),
                );

              if (documents.isEmpty) {
                return Center(
                  child: Text(
                    _pendingOnly
                        ? 'No pending repairs.'
                        : 'No fault reports yet.',
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final document = documents[index];
                  final data = document.data();
                  final repaired = boolFromFirestore(data['repaired']);
                  final updating = _updatingReportIds.contains(document.id);
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
                  final details = readableFirestoreValue(
                    data['details'] ?? data['description'] ?? data['comment'],
                  );

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: repaired
                              ? Colors.green.withOpacity(0.14)
                              : Colors.orange.withOpacity(0.14),
                          child: Icon(
                            repaired ? Icons.check_circle : Icons.build,
                            color: repaired ? Colors.green : Colors.orange,
                          ),
                        ),
                        title: Text('$room - $pc'),
                        subtitle: Text(
                          [
                            if (issue.isNotEmpty) issue,
                            if (details.isNotEmpty) details,
                            'Reported: '
                                '${formatFirestoreTimestamp(data['createdAt'])}',
                            if (repaired)
                              'Repaired: '
                                  '${formatFirestoreTimestamp(data['repairedAt'])}',
                            if (repaired &&
                                stringFromFirestore(
                                  data['technicianNotes'],
                                ).isNotEmpty)
                              'Action: ${data['technicianNotes']}',
                          ].join('\n'),
                        ),
                        trailing: repaired
                            ? const Chip(
                                avatar: Icon(Icons.check, size: 18),
                                label: Text('Repaired'),
                              )
                            : FilledButton.icon(
                                onPressed:
                                    updating ? null : () => _markRepaired(document),
                                icon: updating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.build, size: 18),
                                label: Text(
                                  updating ? 'Saving...' : 'Mark Repaired',
                                ),
                              ),
                        isThreeLine: true,
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
