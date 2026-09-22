import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/app_config_service.dart';
import '../services/staff_service.dart';
import '../widgets/theme_toggle_button.dart';
import 'account_management_screen.dart';
import 'admin_teacher_chat_screen.dart';
import 'last_known_user_screen.dart';
import 'lab_maintenance_overview_screen.dart';
import 'inventory_software_screen.dart';
import 'export_records_screen.dart';
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
  Timer? _sessionHeartbeatTimer;

  // ── Palette (matches StudentLoginScreen / StaffLoginScreen) ────────────────
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

  @override
  void initState() {
    super.initState();
    unawaited(StaffService.instance.heartbeatStaffSession().catchError((_) {}));
    _sessionHeartbeatTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(StaffService.instance.heartbeatStaffSession().catchError((_) {})),
    );
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
        'Inventory & Software',
        Icons.inventory_2_rounded,
        InventorySoftwareScreen(),
      ),
      const _MenuItem(
        'Export Records',
        Icons.file_download_rounded,
        ExportRecordsScreen(),
      ),
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

  @override
  void dispose() {
    _sessionHeartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() => _loggingOut = true);

    try {
      await StaffService.instance.logout();
    } catch (_) {
      // A local route reset must still be possible if the server logout request
      // fails. The saved token is cleared by StaffService where applicable.
    }

    if (!mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).pushAndRemoveUntil(
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
    final navBg = _isDarkMode ? _cardColor : _accentB;
    final navFg = _isDarkMode ? _textColor : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: navBg,
        border: Border(bottom: BorderSide(color: _isDarkMode ? _borderColor : Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          _buildLogoBadge(),
          const SizedBox(width: 12),
          Text(
            widget.user.isSuperAdmin ? 'SysWatch Super Admin' : 'SysWatch Admin',
            style: TextStyle(
              color: navFg,
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
        color: _isDarkMode ? (_isDarkMode ? _accentA : _accentB) : Colors.white.withOpacity(0.2),
        border: Border.all(color: (_isDarkMode ? _accentAForeground : Colors.white).withValues(alpha: 0.45), width: 1.2),
      ),
      child: Icon(
        Icons.memory_rounded,
        color: _isDarkMode ? Colors.black : Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildServerChip() {
    return Tooltip(
      message: AppConfigService.instance.serverUrl,
      child: _buildPillChip(
        icon: Icons.lan_rounded,
        label: 'Intranet',
        iconColor: _accentBForeground,
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
      iconColor: _accentAForeground,
    );
  }

  Widget _buildPillChip({
    required IconData icon,
    required String label,
    required Color iconColor,
  }) {
    final navBorder = _isDarkMode ? _borderColor : Colors.white.withOpacity(0.1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _isDarkMode ? _fieldColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isDarkMode ? _borderColor : _accentB.withOpacity(0.2), width: 1.2),
        boxShadow: [
          if (!_isDarkMode)
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _isDarkMode ? iconColor : _accentB),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12.5, color: _isDarkMode ? _textColor : Colors.black87, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? _fieldColor : Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: _isDarkMode ? _borderColor : Colors.white.withOpacity(0.1)),
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
            valueColor: AlwaysStoppedAnimation<Color>(_isDarkMode ? _accentBForeground : Colors.white),
          ),
        )
            : Icon(Icons.logout_rounded, size: 19, color: _isDarkMode ? _subTextColor : Colors.white70),
      ),
    );
  }

  // ── Sidebar ─────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    final sideBg = _isDarkMode ? _cardColor : _accentA;

    return Container(
      width: 220,
      color: sideBg,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isDarkMode ? _fieldColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isDarkMode ? _borderColor : Colors.black.withOpacity(0.1),
                width: 1.2,
              ),
              boxShadow: [
                if (!_isDarkMode)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _isDarkMode ? _accentAForeground.withValues(alpha: 0.15) : Colors.black.withOpacity(0.1),
                  child: Text(
                    widget.user.isSuperAdmin ? 'S' : 'A',
                    style: TextStyle(
                      color: _isDarkMode ? _accentAForeground : Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.isSuperAdmin ? 'Super Admin' : 'Admin',
                        style: TextStyle(
                          color: _isDarkMode ? _subTextColor : Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.user.displayName.split(' ').first,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _isDarkMode ? _textColor : Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: _isDarkMode ? _borderColor : Colors.black.withOpacity(0.08), height: 1),
          const SizedBox(height: 16),
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
    final activeBg = _isDarkMode ? _accentA : _accentB;
    final activeFg = _isDarkMode ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? activeBg : null,
          boxShadow: [
            if (selected && !_isDarkMode)
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 19,
              color: selected ? activeFg : (_isDarkMode ? _subTextColor.withValues(alpha: 0.7) : Colors.black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? activeFg : (_isDarkMode ? _subTextColor : Colors.black87),
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
              Icon(selected.icon, color: _accentAForeground, size: 22),
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
          // Mount only the selected screen. The previous IndexedStack kept every
          // Admin module alive at the same time, including all of their periodic
          // timers and inherited-widget dependencies. During logout/theme
          // changes that made the route subtree much harder to deactivate safely.
          child: KeyedSubtree(
            key: ValueKey<String>(selected.title),
            child: selected.screen,
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
