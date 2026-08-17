import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/room_record.dart';
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

  // ── Palette (matches StaffLoginScreen / SupportChatScreen / RoomManagementScreen) ──
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor =>
      _isDarkMode ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _accentA => const Color(0xFF2EE6C5);
  Color get _accentB => const Color(0xFF4F8EF7);
  Color get _textColor =>
      _isDarkMode ? Colors.white : const Color(0xFF1A1C1E);
  Color get _subTextColor => _isDarkMode ? Colors.white54 : Colors.black45;
  Color get _borderColor => _isDarkMode
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.09);
  Color get _errorColor => const Color(0xFFFF6B6B);

  LinearGradient get _accentGradient => LinearGradient(
    colors: [_accentA, _accentB],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

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
      _showMessage(user.active ? 'Account disabled.' : 'Account enabled.');
      _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMessage(cleanError(error));
    } finally {
      if (mounted) setState(() => _busyUserIds.remove(user.uid));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Shared themed field decoration ──────────────────────────────────────
  InputDecoration _fieldDecoration(
      String label,
      IconData icon, {
        Widget? suffixIcon,
      }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _subTextColor, fontSize: 14),
      prefixIcon: Icon(icon, color: _subTextColor.withValues(alpha: 0.45), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _accentA, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _errorColor, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _errorColor, width: 1.5),
      ),
      errorStyle: TextStyle(color: _errorColor, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  ButtonStyle get _textButtonStyle =>
      TextButton.styleFrom(foregroundColor: _subTextColor);

  Widget _gradientDialogButton({
    required String label,
    IconData? icon,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    final disabled = onPressed == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: disabled ? null : _accentGradient,
        color: disabled ? _accentA.withValues(alpha: 0.2) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF080A0E)),
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 17, color: const Color(0xFF080A0E)),
                if (loading || icon != null) const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF080A0E),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Reset password dialog ───────────────────────────────────────────────
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
                _showMessage('Password reset for ${user.displayName}.');
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() => saving = false);
                }
                if (mounted) _showMessage(cleanError(error));
              }
            }

            return AlertDialog(
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Reset Password', style: TextStyle(color: _textColor)),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: key,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account: ${user.displayName}',
                          style: TextStyle(color: _subTextColor, fontSize: 13.5)),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: controller,
                        enabled: !saving,
                        obscureText: obscure,
                        maxLength: StaffService.maximumPasswordLength,
                        style: TextStyle(color: _textColor),
                        cursorColor: _accentA,
                        decoration: _fieldDecoration(
                          'New Password',
                          Icons.lock_reset,
                          suffixIcon: IconButton(
                            onPressed: saving
                                ? null
                                : () => setDialogState(() => obscure = !obscure),
                            icon: Icon(
                              obscure ? Icons.visibility : Icons.visibility_off,
                              color: _subTextColor,
                              size: 20,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final length = (value ?? '').runes.length;
                          if (length < StaffService.minimumPasswordLength ||
                              length > StaffService.maximumPasswordLength) {
                            return 'Use 8 to 64 characters.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => save(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  style: _textButtonStyle,
                  child: const Text('Cancel'),
                ),
                _gradientDialogButton(
                  label: saving ? 'Saving...' : 'Reset',
                  loading: saving,
                  onPressed: saving ? null : save,
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }

  // ── Add account dialog ──────────────────────────────────────────────────
  Future<void> _showAddAccountDialog() async {
    List<RoomRecord> availableRooms = const [];
    if (widget.currentUser.isSuperAdmin) {
      try {
        availableRooms = (await StaffService.instance.listRooms())
            .where((room) => room.active)
            .toList();
      } catch (error) {
        if (mounted) _showMessage(cleanError(error));
        return;
      }
    }
    final formKey = GlobalKey<FormState>();
    final displayNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final studentIdController = TextEditingController();
    String role = 'student';
    String? assignedRoomName =
        availableRooms.isEmpty ? null : availableRooms.first.roomName;
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
                  assignedRoomName:
                      role == AppUser.teacherRole ? assignedRoomName : null,
                  active: active,
                );
                if (!dialogContext.mounted || !mounted) return;
                Navigator.pop(dialogContext);
                _showMessage('Account created successfully.');
                _refresh();
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() => saving = false);
                }
                if (mounted) _showMessage(cleanError(error));
              }
            }

            return AlertDialog(
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Add Account', style: TextStyle(color: _textColor)),
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
                          style: TextStyle(color: _textColor),
                          cursorColor: _accentA,
                          decoration:
                          _fieldDecoration('Display Name', Icons.badge_outlined),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Display name is required.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          enabled: !saving,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: _textColor),
                          cursorColor: _accentA,
                          decoration:
                          _fieldDecoration('Email', Icons.email_outlined),
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
                          maxLength: StaffService.maximumPasswordLength,
                          style: TextStyle(color: _textColor),
                          cursorColor: _accentA,
                          decoration: _fieldDecoration(
                            'Temporary Password',
                            Icons.lock_outline,
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
                                color: _subTextColor,
                                size: 20,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final length = (value ?? '').runes.length;
                            if (length < StaffService.minimumPasswordLength ||
                                length > StaffService.maximumPasswordLength) {
                              return 'Use 8 to 64 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: role,
                          dropdownColor: _cardColor,
                          style: TextStyle(color: _textColor, fontSize: 14.5),
                          icon: Icon(Icons.expand_more, color: _subTextColor),
                          decoration: _fieldDecoration(
                              'Role', Icons.admin_panel_settings),
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
                            if (widget.currentUser.isSuperAdmin)
                              const DropdownMenuItem(
                                value: 'teacher',
                                child: Text('Teacher Room Account'),
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
                            style: TextStyle(color: _textColor),
                            cursorColor: _accentA,
                            decoration:
                            _fieldDecoration('Student ID', Icons.numbers),
                            validator: (value) => role == 'student' &&
                                (value ?? '').trim().isEmpty
                                ? 'Student ID is required.'
                                : null,
                          ),
                        ],
                        if (role == AppUser.teacherRole) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: assignedRoomName,
                            dropdownColor: _cardColor,
                            style: TextStyle(color: _textColor, fontSize: 14.5),
                            icon: Icon(Icons.expand_more, color: _subTextColor),
                            decoration: _fieldDecoration(
                              'Assigned Laboratory Room',
                              Icons.meeting_room_rounded,
                            ),
                            items: availableRooms
                                .map(
                                  (room) => DropdownMenuItem(
                                    value: room.roomName,
                                    child: Text('Room ${room.roomName}'),
                                  ),
                                )
                                .toList(),
                            onChanged: saving
                                ? null
                                : (value) => setDialogState(
                                      () => assignedRoomName = value,
                                    ),
                            validator: (_) => role == AppUser.teacherRole &&
                                    (assignedRoomName == null ||
                                        assignedRoomName!.trim().isEmpty)
                                ? 'Create or activate a room first.'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This is the shared Teacher login for the selected '
                            'room. Scheduled teachers in that room use the same account.',
                            style: TextStyle(color: _subTextColor, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 10),
                        _buildActiveToggleRow(
                          active: active,
                          saving: saving,
                          onChanged: (value) => setDialogState(() => active = value),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  style: _textButtonStyle,
                  child: const Text('Cancel'),
                ),
                _gradientDialogButton(
                  label: saving ? 'Creating...' : 'Create',
                  icon: Icons.person_add,
                  loading: saving,
                  onPressed: saving ? null : save,
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

  Widget _buildActiveToggleRow({
    required bool active,
    required bool saving,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account active',
                    style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  'Inactive accounts cannot sign in or sync offline login.',
                  style: TextStyle(color: _subTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          _ThemedSwitch(
            value: active,
            onChanged: saving ? (_) {} : onChanged,
            accentA: _accentA,
            accentB: _accentB,
            fieldColor: _cardColor,
            borderColor: _borderColor,
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bgColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: _buildToolbarCard(),
          ),
          Expanded(
            child: FutureBuilder<List<AppUser>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                        color: _accentA, strokeWidth: 2.5),
                  );
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
                    user.assignedRoomName ?? '',
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
                  color: _accentA,
                  backgroundColor: _cardColor,
                  onRefresh: () async => _refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      return _buildUserTile(users[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.4 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Accounts are saved in the central MariaDB database. '
                      '${widget.currentUser.isSuperAdmin ? 'Super Admin can manage students, administrators, and one shared Teacher account per room. ' : 'Administrators can manage student accounts. '}'
                      'Active students become available to registered Student PCs.',
                  style: TextStyle(color: _subTextColor, fontSize: 12.5, height: 1.4),
                ),
              ),
              const SizedBox(width: 12),
              _buildRefreshButton(),
              const SizedBox(width: 8),
              _buildAddAccountButton(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: _textColor, fontSize: 14),
                  cursorColor: _accentA,
                  decoration: _fieldDecoration(
                    'Search name, email, or Student ID',
                    Icons.search,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _roleFilter,
                  dropdownColor: _cardColor,
                  style: TextStyle(color: _textColor, fontSize: 14),
                  icon: Icon(Icons.expand_more, color: _subTextColor),
                  decoration: _fieldDecoration('Role', Icons.filter_list),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All roles')),
                    DropdownMenuItem(
                      value: 'super_admin',
                      child: Text('Super Admin'),
                    ),
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
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
    );
  }

  Widget _buildRefreshButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _fieldColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _refresh,
            child: Icon(Icons.refresh, color: _subTextColor, size: 21),
          ),
        ),
      ),
    );
  }

  Widget _buildAddAccountButton() {
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _accentGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _accentA.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _showAddAccountDialog,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add, color: Color(0xFF080A0E), size: 19),
                  SizedBox(width: 8),
                  Text(
                    'Add Account',
                    style: TextStyle(
                      color: Color(0xFF080A0E),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserTile(AppUser user) {
    final isCurrent = _isCurrentUser(user);
    final busy = _busyUserIds.contains(user.uid);
    final canResetPassword = _canResetPassword(user);
    final canChangeActive = _canChangeActive(user);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: user.isSuperAdmin
              ? _accentB.withValues(alpha: 0.35)
              : (user.active ? _accentA.withValues(alpha: 0.2) : _borderColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: user.active
                  ? LinearGradient(
                colors: [
                  _accentA.withValues(alpha: 0.15),
                  _accentB.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              color: user.active ? null : _fieldColor,
              border: Border.all(
                color: user.active
                    ? _accentA.withValues(alpha: 0.35)
                    : _borderColor,
                width: 1.2,
              ),
            ),
            child: user.active
                ? ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [_accentA, _accentB],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Icon(
                user.isSuperAdmin ? Icons.verified_user : Icons.person,
                color: Colors.white,
                size: 22,
              ),
            )
                : Icon(Icons.person_off, color: _subTextColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      user.displayName,
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                    if (isCurrent) _buildTag('You', _accentA),
                    if (user.isSuperAdmin)
                      _buildTag('SUPER ADMIN', _accentB, icon: Icons.shield),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(color: _subTextColor, fontSize: 12.5),
                ),
                Text(
                  'Role: ${user.roleLabel}',
                  style: TextStyle(color: _subTextColor, fontSize: 12.5),
                ),
                if (user.isStudent && (user.studentId ?? '').isNotEmpty)
                  Text(
                    'Student ID: ${user.studentId}',
                    style: TextStyle(color: _subTextColor, fontSize: 12.5),
                  ),
                if (user.isTeacher &&
                    (user.assignedRoomName ?? '').isNotEmpty)
                  Text(
                    'Assigned room: ${user.assignedRoomName}',
                    style: TextStyle(color: _subTextColor, fontSize: 12.5),
                  ),
                Text(
                  'Created: ${formatDateTime(user.createdAt)}',
                  style: TextStyle(color: _subTextColor, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconAction(
                icon: Icons.lock_reset,
                tooltip: canResetPassword
                    ? 'Reset password'
                    : 'Only the Super Admin can reset this password',
                onPressed: canResetPassword
                    ? () => _showResetPasswordDialog(user)
                    : null,
              ),
              const SizedBox(height: 8),
              busy
                  ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _accentA,
                ),
              )
                  : _ThemedSwitch(
                value: user.active,
                onChanged: canChangeActive
                    ? (_) => _toggleActive(user)
                    : (_) {},
                disabled: !canChangeActive,
                accentA: _accentA,
                accentB: _accentB,
                fieldColor: _fieldColor,
                borderColor: _borderColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color accent, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: _isDarkMode ? 0.14 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 36,
        height: 36,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _fieldColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderColor),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onPressed,
              child: Icon(
                icon,
                size: 18,
                color: disabled
                    ? _subTextColor.withValues(alpha: 0.4)
                    : _accentB,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemedSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accentA;
  final Color accentB;
  final Color fieldColor;
  final Color borderColor;
  final bool disabled;

  const _ThemedSwitch({
    required this.value,
    required this.onChanged,
    required this.accentA,
    required this.accentB,
    required this.fieldColor,
    required this.borderColor,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : () => onChanged(!value),
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            gradient: value ? LinearGradient(colors: [accentA, accentB]) : null,
            color: value ? null : fieldColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: value ? Colors.transparent : borderColor),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
