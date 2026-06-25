import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_user_service.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  Future<void> _toggleActive(String uid, bool active) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'active': !active,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _showAddAccountDialog() async {
    final displayNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final studentIdController = TextEditingController();

    String role = 'student';
    bool active = true;
    bool saving = false;
    bool obscurePassword = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveAccount() async {
              if (saving) return;

              setDialogState(() {
                saving = true;
              });

              try {
                await FirebaseUserService.createAccount(
                  displayName: displayNameController.text,
                  email: emailController.text,
                  password: passwordController.text,
                  role: role,
                  studentId: studentIdController.text,
                  active: active,
                );

                if (!mounted) return;

                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account created successfully.')),
                );
              } catch (e) {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.toString().replaceAll('Exception:', '').trim(),
                    ),
                  ),
                );
              } finally {
                if (mounted) {
                  setDialogState(() {
                    saving = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Add Account'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Display Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword ? Icons.visibility : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'student', child: Text('Student')),
                          DropdownMenuItem(value: 'itso', child: Text('ITSO')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  role = value;
                                });
                              },
                      ),
                      if (role == 'student') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: studentIdController,
                          decoration: const InputDecoration(
                            labelText: 'Student ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: active,
                        title: const Text('Active account'),
                        onChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  active = value;
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : saveAccount,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(saving ? 'Creating...' : 'Create Account'),
                ),
              ],
            );
          },
        );
      },
    );

    displayNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    studentIdController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Create and manage Firebase Auth accounts and Firestore user profiles.',
                ),
              ),
              FilledButton.icon(
                onPressed: _showAddAccountDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Account'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              docs.sort(
                (a, b) => (a.data()['role'] ?? '')
                    .toString()
                    .compareTo((b.data()['role'] ?? '').toString()),
              );

              if (docs.isEmpty) {
                return const Center(child: Text('No user profiles yet.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final active = data['active'] != false;
                  final role = (data['role'] ?? '').toString();
                  final studentId = (data['studentId'] ?? '').toString();

                  return Card(
                    child: ListTile(
                      leading: Icon(active ? Icons.person : Icons.person_off),
                      title: Text(data['displayName'] ?? data['email'] ?? doc.id),
                      subtitle: Text(
                        'Email: ${data['email'] ?? ''}\n'
                        'Role: $role\n'
                        'Student ID: $studentId',
                      ),
                      isThreeLine: true,
                      trailing: Switch(
                        value: active,
                        onChanged: (_) => _toggleActive(doc.id, active),
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
