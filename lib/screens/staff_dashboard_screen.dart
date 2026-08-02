import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/app_config_service.dart';
import '../services/staff_service.dart';
import 'account_management_screen.dart';
import 'last_known_user_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _menuItems = [
      const _MenuItem('PC Health', Icons.monitor_heart, PcHealthReportsScreen()),
      _MenuItem(
        'Repairs',
        Icons.build,
        RepairManagementScreen(user: widget.user),
      ),
      const _MenuItem(
        'Last Known User',
        Icons.person_pin_circle,
        LastKnownUserScreen(),
      ),
      const _MenuItem('Reports', Icons.analytics, ReportsScreen()),
      const _MenuItem(
        'ITSO Support',
        Icons.support_agent,
        SupportChatScreen(),
      ),
      const _MenuItem('Rooms', Icons.meeting_room, RoomManagementScreen()),
      _MenuItem(
        'Accounts',
        Icons.manage_accounts,
        AccountManagementScreen(currentUserId: widget.user.uid),
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
      appBar: AppBar(
        title: const Text('Syswatch Admin'),
        actions: [
          Tooltip(
            message: AppConfigService.instance.serverUrl,
            child: const Chip(
              avatar: Icon(Icons.lan, size: 18),
              label: Text('Intranet'),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Chip(
              avatar: const Icon(Icons.person, size: 18),
              label: Text(
                widget.user.displayName.isEmpty
                    ? widget.user.email
                    : widget.user.displayName,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: const CircleAvatar(child: Text('A')),
            ),
            destinations: [
              for (final item in _menuItems)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(
                    item.icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(item.title),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                    children: [
                      Icon(selected.icon),
                      const SizedBox(width: 10),
                      Text(
                        selected.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final Widget screen;

  const _MenuItem(this.title, this.icon, this.screen);
}
