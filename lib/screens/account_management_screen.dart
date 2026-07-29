import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/firebase_user_service.dart';
import '../utils/firestore_helpers.dart';

class AccountManagementScreen extends StatefulWidget {
  final String currentUserId;

  const AccountManagementScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final _searchController = TextEditingController();
  final _busyUserIds = <String>{};

  String _roleFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleActive({
    required String uid,
    required bool currentlyActive,
  }) async {
    if (uid == widget.currentUserId || _busyUserIds.contains(uid)) return;

    setState(() => _busyUserIds.add(uid));

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'active': !currentlyActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyActive ? 'Account disabled.' : 'Account enabled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyUserIds.remove(uid));
      }
    }
  }

  Future<void> _showAddAccountDialog() async {
    final formKey = GlobalKey<FormState>();
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
          builder: (dialogBuildContext, setDialogState) {
            Future<void> saveAccount() async {
              if (saving || !(formKey.currentState?.validate() ?? false)) {
                return;
              }

              setDialogState(() => saving = true);

              try {
                await FirebaseUserService.createAccount(
                  displayName: displayNameController.text,
                  email: emailController.text,
                  password: passwordController.text,
                  role: role,
                  studentId:
                      role == 'student' ? studentIdController.text : null,
                  active: active,
                );

                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account created successfully.'),
                  ),
                );
              } catch (error) {
                if (!mounted) return;
                if (dialogContext.mounted) {
                  setDialogState(() => saving = false);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_cleanError(error))),
                );
              }
            }

            return AlertDialog(
              title: const Text('Add Account'),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: displayNameController,
                          enabled: !saving,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Display Name',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Display name is required.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          enabled: !saving,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            final email = (value ?? '').trim();
                            if (email.isEmpty) return 'Email is required.';
                            if (!email.contains('@') ||
                                !email.split('@').last.contains('.')) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          enabled: !saving,
                          obscureText: obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Temporary Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: saving
                                  ? null
                                  : () {
                                      setDialogState(
                                        () => obscurePassword =
                                            !obscurePassword,
                                      );
                                    },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').length < 6) {
                              return 'Use at least 6 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: role,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            prefixIcon: Icon(Icons.admin_panel_settings),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'student',
                              child: Text('Student'),
                            ),
                            DropdownMenuItem(
                              value: 'itso',
                              child: Text('ITSO'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() => role = value);
                                },
                        ),
                        if (role == 'student') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: studentIdController,
                            enabled: !saving,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Student ID',
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            validator: (value) {
                              if (role == 'student' &&
                                  (value ?? '').trim().isEmpty) {
                                return 'Student ID is required.';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => saveAccount(),
                          ),
                        ],
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: active,
                          title: const Text('Active account'),
                          subtitle: const Text(
                            'Inactive accounts cannot sign in.',
                          ),
                          onChanged: saving
                              ? null
                              : (value) {
                                  setDialogState(() => active = value);
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.of(dialogContext).pop(),
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Manage Student, ITSO, and Admin accounts. '
                          'Workstation profiles are kept out of this list.',
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _showAddAccountDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Account'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: 'Search name, email, or Student ID',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 170,
                        child: DropdownButtonFormField<String>(
                          value: _roleFilter,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All roles'),
                            ),
                            DropdownMenuItem(
                              value: 'student',
                              child: Text('Student'),
                            ),
                            DropdownMenuItem(
                              value: 'itso',
                              child: Text('ITSO'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _roleFilter = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where(
                  'role',
                  whereIn: AppUser.firestoreAccountRoleValues,
                )
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _MessageState(
                  icon: Icons.cloud_off,
                  title: 'Could not load accounts',
                  message: _cleanError(snapshot.error!),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final search = _searchController.text.trim().toLowerCase();
              final documents = snapshot.data!.docs.where((document) {
                final data = document.data();
                final role = stringFromFirestore(data['role']).toLowerCase();
                if (_roleFilter != 'all' && role != _roleFilter) return false;

                if (search.isEmpty) return true;
                final searchableText = [
                  data['displayName'],
                  data['email'],
                  data['studentId'],
                  role,
                ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
                return searchableText.contains(search);
              }).toList()
                ..sort((a, b) {
                  final aData = a.data();
                  final bData = b.data();
                  final roleComparison =
                      stringFromFirestore(aData['role']).compareTo(
                    stringFromFirestore(bData['role']),
                  );
                  if (roleComparison != 0) return roleComparison;

                  final aName = stringFromFirestore(
                    aData['displayName'],
                    fallback: stringFromFirestore(aData['email'], fallback: a.id),
                  ).toLowerCase();
                  final bName = stringFromFirestore(
                    bData['displayName'],
                    fallback: stringFromFirestore(bData['email'], fallback: b.id),
                  ).toLowerCase();
                  return aName.compareTo(bName);
                });

              if (documents.isEmpty) {
                return const _MessageState(
                  icon: Icons.manage_accounts_outlined,
                  title: 'No matching accounts',
                  message: 'Try another search or role filter.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final document = documents[index];
                  final data = document.data();
                  final active = boolFromFirestore(
                    data['active'],
                    fallback: true,
                  );
                  final role =
                      stringFromFirestore(data['role']).toLowerCase();
                  final studentId = stringFromFirestore(data['studentId']);
                  final isCurrentUser = document.id == widget.currentUserId;
                  final busy = _busyUserIds.contains(document.id);
                  final displayName = stringFromFirestore(
                    data['displayName'],
                    fallback: stringFromFirestore(
                      data['email'],
                      fallback: document.id,
                    ),
                  );

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          active ? Icons.person : Icons.person_off,
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(child: Text(displayName)),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 8),
                            const Chip(label: Text('You')),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        [
                          stringFromFirestore(data['email']),
                          'Role: ${role.toUpperCase()}',
                          if (role == 'student' && studentId.isNotEmpty)
                            'Student ID: $studentId',
                        ].where((line) => line.isNotEmpty).join('\n'),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(active ? 'Active' : 'Disabled'),
                          const SizedBox(width: 8),
                          if (busy)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Switch(
                              value: active,
                              onChanged: isCurrentUser
                                  ? null
                                  : (_) => _toggleActive(
                                        uid: document.id,
                                        currentlyActive: active,
                                      ),
                            ),
                        ],
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

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _cleanError(Object error) {
  return error.toString().replaceFirst('Exception:', '').trim();
}
