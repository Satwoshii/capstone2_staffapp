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

  // ── Palette (matches the rest of the app) ───────────────────────────────
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _cardColor => _isDarkMode ? const Color(0xFF13141A) : Colors.white;
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
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: _buildToolbar(),
        ),
        Expanded(
          child: FutureBuilder<List<LastKnownUserRecord>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_accentAForeground),
                  ),
                );
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
                  record.dashboardDisplayName,
                  record.email,
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
                  message: 'Windows login activity will appear after synchronization.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                color: _accentAForeground,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildRecordCard(record),
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

  // ── Toolbar ─────────────────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: _textColor, fontSize: 14),
            cursorColor: _accentAForeground,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search room, PC, name, or email',
              labelStyle: TextStyle(color: _subTextColor, fontSize: 13.5),
              prefixIcon: Icon(Icons.search_rounded, color: _subTextColor, size: 20),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: IconButton(
        tooltip: 'Refresh',
        onPressed: _refresh,
        icon: Icon(Icons.refresh_rounded, color: _accentBForeground, size: 20),
      ),
    );
  }

  // ── Record card ──────────────────────────────────────────────────────────
  Widget _buildRecordCard(LastKnownUserRecord record) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentA.withValues(alpha: 0.16),
            ),
            child: Icon(Icons.person_pin_circle_rounded, color: _accentAForeground, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${record.roomName} · ${record.pcId}',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _buildStatusBadge(record.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  record.dashboardDisplayName,
                  style: TextStyle(
                    color: _textColor.withValues(alpha: 0.90),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (record.email.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.email.trim(),
                    style: TextStyle(
                      color: _subTextColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Login: ${formatDateTime(record.loginTime)}',
                  style: TextStyle(color: _subTextColor, fontSize: 12.5),
                ),
                if (record.logoutTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Logout: ${formatDateTime(record.logoutTime)}',
                      style: TextStyle(color: _subTextColor, fontSize: 12.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final active = status.trim().toLowerCase() == 'active' ||
        status.trim().toLowerCase() == 'online' ||
        status.trim().toLowerCase() == 'logged in' ||
        status.trim().toLowerCase() == 'logged_in';
    final color = active ? _accentAForeground : _subTextColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}