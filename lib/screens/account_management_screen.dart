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
  Color get _accentA => const Color(0xFFFFD700);
  Color get _accentB => const Color(0xFF003366);
  Color get _accentAForeground =>
      _isDarkMode ? _accentA : _accentB;
  Color get _accentBForeground => _isDarkMode ? Colors.white : _accentB;
  Color get _textColor =>
      _isDarkMode ? Colors.white : const Color(0xFF1A1C1E);
  Color get _subTextColor => _isDarkMode ? Colors.white54 : Colors.black45;
  Color get _borderColor => _isDarkMode
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.09);
  Color get _errorColor => const Color(0xFFFF6B6B);
  Color get _accentColor => _isDarkMode ? _accentA : _accentB;

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
        borderSide: BorderSide(color: _accentAForeground, width: 1.5),
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

  Widget _primaryDialogButton({
    required String label,
    IconData? icon,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    final disabled = onPressed == null;
    final bgColor = disabled
        ? _accentAForeground.withValues(alpha: 0.2)
        : _accentColor;
    final fgColor = _isDarkMode ? Colors.black : Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
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
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 17, color: fgColor),
                if (loading || icon != null) const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: fgColor,
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
    final key = GlobalKey<FormState>();
    String password = '';
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
                  password: password,
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
                        enabled: !saving,
                        obscureText: obscure,
                        maxLength: StaffService.maximumPasswordLength,
                        style: TextStyle(color: _textColor),
                        cursorColor: _accentAForeground,
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
                        onChanged: (value) => password = value,
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
                _primaryDialogButton(
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
    String displayName = '';
    String email = '';
    String password = '';
    String studentId = '';
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
                  displayName: displayName.trim(),
                  email: email.trim(),
                  password: password,
                  role: role,
                  studentId: role == 'student' ? studentId.trim() : null,
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
                          enabled: !saving,
                          style: TextStyle(color: _textColor),
                          cursorColor: _accentAForeground,
                          decoration:
                          _fieldDecoration('Display Name', Icons.badge_outlined),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Display name is required.'
                              : null,
                          onChanged: (value) => displayName = value,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          enabled: !saving,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: _textColor),
                          cursorColor: _accentAForeground,
                          decoration:
                          _fieldDecoration('Email', Icons.email_outlined),
                          validator: (value) {
                            final email = (value ?? '').trim();
                            if (email.isEmpty) return 'Email is required.';
                            if (!email.contains('@')) return 'Enter a valid email.';
                            return null;
                          },
                          onChanged: (value) => email = value,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          enabled: !saving,
                          obscureText: obscurePassword,
                          maxLength: StaffService.maximumPasswordLength,
                          style: TextStyle(color: _textColor),
                          cursorColor: _accentAForeground,
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
                          onChanged: (value) => password = value,
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
                            enabled: !saving,
                            style: TextStyle(color: _textColor),
                            cursorColor: _accentAForeground,
                            decoration:
                            _fieldDecoration('Student ID', Icons.numbers),
                            validator: (value) => role == 'student' &&
                                (value ?? '').trim().isEmpty
                                ? 'Student ID is required.'
                                : null,
                            onChanged: (value) => studentId = value,
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
                _primaryDialogButton(
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
            accentColor: _accentColor,
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
                        color: _accentAForeground, strokeWidth: 2.5),
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
                  color: _accentAForeground,
                  backgroundColor: _cardColor,
                  onRefresh: () async => _refresh(),
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: users.length,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisExtent: 185,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
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
                      '${widget.currentUser.isSuperAdmin ? 'Super Admin can manage all roles. ' : 'Administrators manage students. '}'
                      'Active students can log into Student PCs.',
                  style: TextStyle(color: _subTextColor, fontSize: 12, height: 1.4),
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
                  style: TextStyle(color: _textColor, fontSize: 13.5),
                  cursorColor: _accentAForeground,
                  decoration: _fieldDecoration(
                    'Search name or email',
                    Icons.search,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  value: _roleFilter,
                  dropdownColor: _cardColor,
                  style: TextStyle(color: _textColor, fontSize: 13.5),
                  icon: Icon(Icons.expand_more, color: _subTextColor),
                  decoration: _fieldDecoration('Role', Icons.filter_list),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'super_admin', child: Text('Super')),
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
      width: 44,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _fieldColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _refresh,
            child: Icon(Icons.refresh, color: _subTextColor, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildAddAccountButton() {
    final bgColor = _isDarkMode ? _accentA : _accentB;
    final fgColor = _isDarkMode ? Colors.black : Colors.white;

    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _showAddAccountDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add, color: fgColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Add',
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: user.isSuperAdmin
              ? _accentB.withValues(alpha: 0.35)
              : (user.active ? _accentAForeground.withValues(alpha: 0.15) : _borderColor),
        ),
        boxShadow: [
          if (!_isDarkMode)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: user.active
                      ? _accentAForeground.withValues(alpha: 0.1)
                      : _fieldColor,
                ),
                child: Icon(
                  user.isSuperAdmin ? Icons.verified_user : Icons.person,
                  color: user.active ? _accentAForeground : _subTextColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      user.roleLabel,
                      style: TextStyle(
                        color: _subTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrent) _buildTag('YOU', _accentAForeground),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _subTextColor, fontSize: 12),
          ),
          if (user.isStudent && (user.studentId ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'ID: ${user.studentId}',
                style: TextStyle(color: _subTextColor, fontSize: 11.5),
              ),
            ),
          if (user.isTeacher && (user.assignedRoomName ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Room: ${user.assignedRoomName}',
                style: TextStyle(color: _subTextColor, fontSize: 11.5),
              ),
            ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIconAction(
                icon: Icons.lock_reset,
                tooltip: canResetPassword ? 'Reset Password' : 'Locked',
                onPressed: canResetPassword ? () => _showResetPasswordDialog(user) : null,
              ),
              if (busy)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accentAForeground,
                  ),
                )
              else
                _ThemedSwitch(
                  value: user.active,
                  onChanged: canChangeActive ? (_) => _toggleActive(user) : (_) {},
                  disabled: !canChangeActive,
                  accentColor: _accentColor,
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
                    : _accentBForeground,
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
  final Color accentColor;
  final Color fieldColor;
  final Color borderColor;
  final bool disabled;

  const _ThemedSwitch({
    required this.value,
    required this.onChanged,
    required this.accentColor,
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
            color: value
                ? accentColor
                : fieldColor,
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
