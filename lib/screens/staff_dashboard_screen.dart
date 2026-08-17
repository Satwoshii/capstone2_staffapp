import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/app_config_service.dart';
import '../services/staff_service.dart';
import '../widgets/theme_toggle_button.dart';
import 'account_management_screen.dart';
import 'admin_teacher_chat_screen.dart';
import 'last_known_user_screen.dart';
import 'lab_maintenance_overview_screen.dart';
import 'pc_health_reports_screen.dart';
import 'repair_management_screen.dart';
import 'reports_screen.dart';
import 'room_management_screen.dart';
import 'staff_login_screen.dart';
import 'support_chat_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  final AppUser user;

  const StaffDashboardScreen({super.key, required this.user});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  late final List<_MenuItem> _menuItems;
  int _selectedIndex = 0;
  bool _loggingOut = false;

  // ── Palette (matches StudentLoginScreen / StaffLoginScreen) ────────────────
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

  @override
  void initState() {
    super.initState();
    _menuItems = [
      const _MenuItem('Status Report', Icons.monitor_heart_rounded, PcHealthReportsScreen()),
      _MenuItem(
        'Repairs',
        Icons.build_rounded,
        RepairManagementScreen(user: widget.user),
      ),
      const _MenuItem(
        'Maintenance',
        Icons.home_repair_service_rounded,
        LabMaintenanceOverviewScreen(),
      ),
      const _MenuItem(
        'Audit Log',
        Icons.person_pin_circle_rounded,
        LastKnownUserScreen(),
      ),
      const _MenuItem('Reports', Icons.analytics_rounded, ReportsScreen()),
      const _MenuItem(
        'ITSO Support',
        Icons.support_agent_rounded,
        SupportChatScreen(),
      ),
      const _MenuItem(
        'Teacher Chat',
        Icons.forum_rounded,
        AdminTeacherChatScreen(),
      ),
      const _MenuItem('Rooms', Icons.meeting_room_rounded, RoomManagementScreen()),
      _MenuItem(
        'Accounts',
        Icons.manage_accounts_rounded,
        AccountManagementScreen(currentUser: widget.user),
      ),
    ];
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    await StaffService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StaffLoginScreen()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _menuItems[_selectedIndex];
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSidebar(),
                    Expanded(child: _buildContent(selected)),
                  ],
                ),
              ),
            ],
          ),
          const Positioned(
            bottom: 24,
            left: 24,
            child: ThemeToggleButton(),
          ),
        ],
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          _buildLogoBadge(),
          const SizedBox(width: 12),
          Text(
            widget.user.isSuperAdmin ? 'Syswatch Super Admin' : 'Syswatch Admin',
            style: TextStyle(
              color: _textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          _buildServerChip(),
          const SizedBox(width: 10),
          _buildUserChip(),
          const SizedBox(width: 10),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildLogoBadge() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_accentA.withValues(alpha: 0.15), _accentB.withValues(alpha: 0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _accentA.withValues(alpha: 0.45), width: 1.2),
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [_accentA, _accentB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: const Icon(Icons.memory_rounded, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildServerChip() {
    return Tooltip(
      message: AppConfigService.instance.serverUrl,
      child: _buildPillChip(
        icon: Icons.lan_rounded,
        label: 'Intranet',
        iconColor: _accentB,
      ),
    );
  }

  Widget _buildUserChip() {
    final name = widget.user.displayName.isEmpty
        ? widget.user.email
        : widget.user.displayName;
    return _buildPillChip(
      icon: Icons.person_rounded,
      label: '$name • ${widget.user.roleLabel}',
      iconColor: _accentA,
    );
  }

  Widget _buildPillChip({
    required IconData icon,
    required String label,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12.5, color: _textColor, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      decoration: BoxDecoration(
        color: _fieldColor,
        shape: BoxShape.circle,
        border: Border.all(color: _borderColor),
      ),
      child: IconButton(
        tooltip: 'Sign out',
        onPressed: _loggingOut ? null : _logout,
        icon: _loggingOut
            ? SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_accentB),
          ),
        )
            : Icon(Icons.logout_rounded, size: 19, color: _subTextColor),
      ),
    );
  }

  // ── Sidebar ─────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: 220,
      color: _cardColor,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _accentA.withValues(alpha: 0.15),
                  child: Text(
                    widget.user.isSuperAdmin ? 'S' : 'A',
                    style: TextStyle(
                      color: _accentA,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.user.isSuperAdmin ? 'Super Admin' : 'Admin',
                    style: TextStyle(
                      color: _subTextColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: _borderColor, height: 20),
          for (int i = 0; i < _menuItems.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _sidebarItem(index: i, item: _menuItems[i]),
            ),
        ],
      ),
    );
  }

  Widget _sidebarItem({required int index, required _MenuItem item}) {
    final selected = index == _selectedIndex;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected
              ? LinearGradient(
            colors: [
              _accentA.withValues(alpha: 0.18),
              _accentB.withValues(alpha: 0.14),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
              : null,
          border: selected
              ? Border.all(color: _accentA.withValues(alpha: 0.35), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 19,
              color: selected ? _accentA : _subTextColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? _textColor : _subTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Content area ─────────────────────────────────────────────────────────
  Widget _buildContent(_MenuItem selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              Icon(selected.icon, color: _accentA, size: 22),
              const SizedBox(width: 10),
              Text(
                selected.title,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: [for (final item in _menuItems) item.screen],
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final Widget screen;

  const _MenuItem(this.title, this.icon, this.screen);
}
