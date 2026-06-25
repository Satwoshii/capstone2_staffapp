import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/firebase_user_service.dart';
import 'account_management_screen.dart';
import 'last_known_user_screen.dart';
import 'pc_health_reports_screen.dart';
import 'repair_management_screen.dart';
import 'reports_screen.dart';
import 'room_management_screen.dart';
import 'staff_login_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  final AppUser user;

  const StaffDashboardScreen({super.key, required this.user});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  int selectedIndex = 0;

  bool get isAdmin => widget.user.role.trim().toLowerCase() == 'admin';

  List<_MenuItem> get menuItems {
    final items = <_MenuItem>[
      _MenuItem('PC Health', Icons.monitor_heart, const PcHealthReportsScreen()),
      _MenuItem('Repairs', Icons.build, RepairManagementScreen(user: widget.user)),
      _MenuItem('Last Known User', Icons.person_pin_circle, const LastKnownUserScreen()),
      _MenuItem('Reports', Icons.analytics, const ReportsScreen()),
    ];

    if (isAdmin) {
      items.addAll([
        _MenuItem('Rooms', Icons.meeting_room, const RoomManagementScreen()),
        _MenuItem('Accounts', Icons.manage_accounts, const AccountManagementScreen()),
      ]);
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = menuItems;
    final selected = items[selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('${isAdmin ? 'Admin' : 'ITSO'} Management App'),
        actions: [
          Center(child: Text(widget.user.displayName.isEmpty ? widget.user.email : widget.user.displayName)),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseUserService.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const StaffLoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final item in items)
                NavigationRailDestination(
                  icon: Icon(item.icon),
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
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Text(
                    selected.title,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(child: selected.screen),
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

  _MenuItem(this.title, this.icon, this.screen);
}

String formatTimestamp(dynamic value) {
  if (value == null) return '';
  if (value is Timestamp) return value.toDate().toString();
  return value.toString();
}
