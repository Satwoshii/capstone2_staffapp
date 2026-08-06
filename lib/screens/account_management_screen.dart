import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/message_state.dart';

class AccountManagementScreen extends StatefulWidget {
  final AppUser currentUser;

  const AccountManagementScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final _searchController = TextEditingController();
  final _busyUserIds = <String>{};
  Timer? _timer;
  Future<List<AppUser>>? _future;
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _future = StaffService.instance.listAccounts();
    });
  }

  bool _isCurrentUser(AppUser user) => user.uid == widget.currentUser.uid;

  bool _canResetPassword(AppUser user) {
    if (widget.currentUser.isSuperAdmin) return true;
    return _isCurrentUser(user) || user.isStudent;
  }

  bool _canChangeActive(AppUser user) {
    if (_isCurrentUser(user) || user.isSuperAdmin) return false;
    if (widget.currentUser.isSuperAdmin) return true;
    return user.isStudent;
  }

  Future<void> _toggleActive(AppUser user) async {
    if (!_canChangeActive(user) || _busyUserIds.contains(user.uid)) {
      return;
    }
    setState(() => _busyUserIds.add(user.uid));
    try {
      await StaffService.instance.setAccountActive(
        uid: user.uid,
        active: !user.active,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(user.active ? 'Account disabled.' : 'Account enabled.'),
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cleanError(error))),
      );
    } finally {
      if (mounted) setState(() => _busyUserIds.remove(user.uid));
    }
  }

  Future<void> _showResetPasswordDialog(AppUser user) async {
    final controller = TextEditingController();
    final key = GlobalKey<FormState>();
    bool saving = false;
    bool obscure = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (saving || !(key.currentState?.validate() ?? false)) return;
              setDialogState(() => saving = true);
              try {
                await StaffService.instance.resetPassword(
                  uid: user.uid,
                  password: controller.text,
                );
                if (!dialogContext.mounted || !mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Password reset for ${user.displayName}.'),
                  ),
                );
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() => saving = false);
                }
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(cleanError(error))),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Reset Password'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: key,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account: ${user.displayName}'),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: controller,
                        enabled: !saving,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock_reset),
                          suffixIcon: IconButton(
                            onPressed: saving
                                ? null
                                : () => setDialogState(() => obscure = !obscure),
                            icon: Icon(
                              obscure ? Icons.visibility : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: (value) => (value ?? '').length < 8
                            ? 'Use at least 8 characters.'
                            : null,
                        onFieldSubmitted: (_) => save(),
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
                FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Saving...' : 'Reset'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
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
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (saving || !(formKey.currentState?.validate() ?? false)) return;
              setDialogState(() => saving = true);
              try {
                await StaffService.instance.createAccount(
                  displayName: displayNameController.text,
                  email: emailController.text,
                  password: passwordController.text,
                  role: role,
                  studentId: role == 'student' ? studentIdController.text : null,
                  active: active,
                );
                if (!dialogContext.mounted || !mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Account created successfully.')),
                );
                _refresh();
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() => saving = false);
                }
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(cleanError(error))),
                  );
                }
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
                          decoration: const InputDecoration(
                            labelText: 'Display Name',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Display name is required.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          enabled: !saving,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            final email = (value ?? '').trim();
                            if (email.isEmpty) return 'Email is required.';
                            if (!email.contains('@')) return 'Enter a valid email.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          enabled: !saving,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Temporary Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: saving
                                  ? null
                                  : () => setDialogState(
                                        () => obscurePassword = !obscurePassword,
                                      ),
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) => (value ?? '').length < 8
                              ? 'Use at least 8 characters.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: role,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            prefixIcon: Icon(Icons.admin_panel_settings),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'student',
                              child: Text('Student'),
                            ),
                            if (widget.currentUser.isSuperAdmin)
                              const DropdownMenuItem(
                                value: 'admin',
                                child: Text('Admin'),
                              ),
                          ],
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() => role = value);
                                  }
                                },
                        ),
                        if (role == 'student') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: studentIdController,
                            enabled: !saving,
                            decoration: const InputDecoration(
                              labelText: 'Student ID',
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            validator: (value) => role == 'student' &&
                                    (value ?? '').trim().isEmpty
                                ? 'Student ID is required.'
                                : null,
                          ),
                        ],
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: active,
                          onChanged: saving
                              ? null
                              : (value) => setDialogState(() => active = value),
                          title: const Text('Account active'),
                          subtitle: const Text(
                            'Inactive accounts cannot sign in or sync offline login.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(saving ? 'Creating...' : 'Create'),
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
                      Expanded(
                        child: Text(
                          'Accounts are saved in the central MariaDB database. '
                          '${widget.currentUser.isSuperAdmin ? 'Super Admin can manage students and administrators. ' : 'Administrators can manage student accounts. '}'
                          'Active students become available to registered Student PCs.',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                      const SizedBox(width: 8),
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
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All roles')),
                            DropdownMenuItem(
                              value: 'super_admin',
                              child: Text('Super Admin'),
                            ),
                            DropdownMenuItem(
                              value: 'student',
                              child: Text('Student'),
                            ),
                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _roleFilter = value);
                            }
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
          child: FutureBuilder<List<AppUser>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return MessageState(
                  icon: Icons.wifi_off,
                  title: 'Could not load accounts',
                  message: cleanError(snapshot.error!),
                  onRetry: _refresh,
                );
              }

              final search = _searchController.text.trim().toLowerCase();
              final users = (snapshot.data ?? const <AppUser>[]).where((user) {
                if (_roleFilter != 'all' && user.role != _roleFilter) return false;
                if (search.isEmpty) return true;
                return [
                  user.displayName,
                  user.email,
                  user.studentId ?? '',
                  user.role,
                ].join(' ').toLowerCase().contains(search);
              }).toList()
                ..sort((a, b) {
                  final role = a.role.compareTo(b.role);
                  if (role != 0) return role;
                  return a.displayName.toLowerCase().compareTo(
                        b.displayName.toLowerCase(),
                      );
                });

              if (users.isEmpty) {
                return const MessageState(
                  icon: Icons.manage_accounts_outlined,
                  title: 'No matching accounts',
                  message: 'Try another search or role filter.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isCurrent = _isCurrentUser(user);
                    final busy = _busyUserIds.contains(user.uid);
                    final canResetPassword = _canResetPassword(user);
                    final canChangeActive = _canChangeActive(user);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            user.isSuperAdmin
                                ? Icons.verified_user
                                : user.active
                                    ? Icons.person
                                    : Icons.person_off,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(child: Text(user.displayName)),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              const Chip(label: Text('You')),
                            ],
                            if (user.isSuperAdmin) ...[
                              const SizedBox(width: 8),
                              const Chip(
                                avatar: Icon(Icons.shield, size: 16),
                                label: Text('SUPER ADMIN'),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          [
                            user.email,
                            'Role: ${user.roleLabel}',
                            if (user.isStudent && (user.studentId ?? '').isNotEmpty)
                              'Student ID: ${user.studentId}',
                            'Created: ${formatDateTime(user.createdAt)}',
                          ].join('\n'),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: canResetPassword
                                  ? 'Reset password'
                                  : 'Only the Super Admin can reset this password',
                              onPressed: canResetPassword
                                  ? () => _showResetPasswordDialog(user)
                                  : null,
                              icon: const Icon(Icons.lock_reset),
                            ),
                            if (busy)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Switch(
                                value: user.active,
                                onChanged: canChangeActive
                                    ? (_) => _toggleActive(user)
                                    : null,
                              ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
