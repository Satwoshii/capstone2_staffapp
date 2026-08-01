import 'dart:async';

import 'package:flutter/material.dart';

import '../models/last_known_user_record.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/message_state.dart';

class LastKnownUserScreen extends StatefulWidget {
  const LastKnownUserScreen({super.key});

  @override
  State<LastKnownUserScreen> createState() => _LastKnownUserScreenState();
}

class _LastKnownUserScreenState extends State<LastKnownUserScreen> {
  final _searchController = TextEditingController();
  Future<List<LastKnownUserRecord>>? _future;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
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
      _future = StaffService.instance.listLastKnownUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search room, PC, student, or email',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<LastKnownUserRecord>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return MessageState(
                  icon: Icons.wifi_off,
                  title: 'Could not load login records',
                  message: cleanError(snapshot.error!),
                  onRetry: _refresh,
                );
              }
              final search = _searchController.text.trim().toLowerCase();
              final records = (snapshot.data ?? const <LastKnownUserRecord>[])
                  .where((record) {
                if (search.isEmpty) return true;
                return [
                  record.roomName,
                  record.pcId,
                  record.displayName,
                  record.email ?? '',
                  record.studentId ?? '',
                  record.status,
                ].join(' ').toLowerCase().contains(search);
              }).toList()
                ..sort((a, b) {
                  final room = a.roomName.compareTo(b.roomName);
                  return room != 0 ? room : a.pcId.compareTo(b.pcId);
                });

              if (records.isEmpty) {
                return const MessageState(
                  icon: Icons.person_pin_circle_outlined,
                  title: 'No matching login records',
                  message: 'Student login activity will appear after synchronization.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person_pin)),
                        title: Text('${record.roomName} - ${record.pcId}'),
                        subtitle: Text(
                          [
                            'Last user: ${record.displayName}',
                            if ((record.email ?? '').isNotEmpty &&
                                record.email != record.displayName)
                              record.email!,
                            if ((record.studentId ?? '').isNotEmpty)
                              'Student ID: ${record.studentId}',
                            'Login: ${formatDateTime(record.loginTime)}',
                            if (record.logoutTime != null)
                              'Logout: ${formatDateTime(record.logoutTime)}',
                          ].join('\n'),
                        ),
                        trailing: Chip(label: Text(record.status.toUpperCase())),
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
