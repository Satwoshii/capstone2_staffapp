import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pc_health_record.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/message_state.dart';
import 'room_pc_status_screen.dart';

//Status Report Screen

class PcHealthReportsScreen extends StatefulWidget {
  const PcHealthReportsScreen({super.key});

  @override
  State<PcHealthReportsScreen> createState() => _PcHealthReportsScreenState();
}

class _PcHealthReportsScreenState extends State<PcHealthReportsScreen> {
  final _searchController = TextEditingController();
  Future<List<PcHealthRecord>>? _future;
  Timer? _timer;
  bool _issuesOnly = false;
  String? _selectedRoom;

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
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
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
      _future = StaffService.instance.listPcHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedRoom != null) {
      return FutureBuilder<List<PcHealthRecord>>(
        future: _future,
        builder: (context, snapshot) {
          final all = snapshot.data ?? [];
          final records = all.where((r) => r.roomName == _selectedRoom).toList();
          return RoomPcStatusScreen(
            roomName: _selectedRoom!,
            records: records,
            onBack: () => setState(() => _selectedRoom = null),
          );
        },
      );
    }

    return FutureBuilder<List<PcHealthRecord>>(
      future: _future,
      builder: (context, snapshot) {
        final allRecords = snapshot.data ?? const <PcHealthRecord>[];
        final totalIssues = allRecords.where((r) => !_styleForStatus(r.status).isHealthy).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _buildToolbar(totalIssues),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
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
                      title: 'Could not load PC health',
                      message: cleanError(snapshot.error!),
                      onRetry: _refresh,
                    );
                  }
                  final search = _searchController.text.trim().toLowerCase();

                  // Filter based on search and issuesOnly
                  final filteredRecords = allRecords.where((record) {
                    final style = _styleForStatus(record.status);
                    if (_issuesOnly && style.isHealthy) return false;
                    if (search.isEmpty) return true;
                    return [
                      record.roomName,
                      record.pcId,
                      record.status,
                      record.lastDisplayName ?? '',
                      readableHealthDetails(record.details),
                    ].join(' ').toLowerCase().contains(search);
                  }).toList();

                  if (filteredRecords.isEmpty) {
                    return MessageState(
                      icon: Icons.monitor_heart_outlined,
                      title: _issuesOnly ? 'No matching issues' : 'No PC health records',
                      message: _issuesOnly
                          ? 'No unhealthy PCs match the filter.'
                          : 'Student PCs will appear after their first status sync.',
                    );
                  }

                  // Group by room
                  final grouped = <String, List<PcHealthRecord>>{};
                  for (final r in filteredRecords) {
                    grouped.putIfAbsent(r.roomName, () => []).add(r);
                  }

                  // Sort rooms alphabetically
                  final sortedRooms = grouped.keys.toList()..sort();

                  // Sort PCs within each room (by PC ID)
                  for (final room in sortedRooms) {
                    grouped[room]!.sort((a, b) => a.pcId.compareTo(b.pcId));
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    color: _accentAForeground,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          // 3 or 4 columns depending on available width
                          final int crossAxisCount = width > 1400 ? 4 : (width > 950 ? 3 : (width > 650 ? 2 : 1));
                          const double spacing = 16.0;
                          final double itemWidth = (width - (crossAxisCount - 1) * spacing) / crossAxisCount;

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: sortedRooms.map((roomName) {
                              final records = grouped[roomName]!;
                              return SizedBox(
                                width: itemWidth,
                                child: _buildRoomCard(roomName, records),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Toolbar ─────────────────────────────────────────────────────────────
  Widget _buildToolbar(int totalIssues) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: _textColor, fontSize: 14),
            cursorColor: _accentAForeground,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search room, PC, status, or display name',
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
        const SizedBox(width: 12),
        _buildNotificationBell(totalIssues),
        const SizedBox(width: 12),
        _buildIssuesOnlyToggle(),
        const SizedBox(width: 10),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildNotificationBell(int totalIssues) {
    if (totalIssues == 0) return const SizedBox.shrink();

    final activeColor = const Color(0xFFFF6B6B);
    return Tooltip(
      message: '$totalIssues PC issue${totalIssues == 1 ? '' : 's'} detected',
      child: GestureDetector(
        onTap: () {
          setState(() {
            _issuesOnly = true;
            _searchController.clear();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: activeColor.withValues(alpha: 0.15),
            border: Border.all(
              color: activeColor.withValues(alpha: 0.5),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications_active_rounded,
                size: 18,
                color: activeColor,
              ),
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _cardColor, width: 1.5),
                  ),
                  child: Text(
                    '$totalIssues',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIssuesOnlyToggle() {
    final activeColor = _isDarkMode ? _accentA : _accentB;
    return GestureDetector(
      onTap: () => setState(() => _issuesOnly = !_issuesOnly),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _issuesOnly
              ? activeColor.withValues(alpha: 0.15)
              : _fieldColor,
          border: Border.all(
            color: _issuesOnly ? activeColor.withValues(alpha: 0.5) : _borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: _issuesOnly ? activeColor : _subTextColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Issues only',
              style: TextStyle(
                fontSize: 13,
                fontWeight: _issuesOnly ? FontWeight.w600 : FontWeight.w400,
                color: _issuesOnly ? _textColor : _subTextColor,
              ),
            ),
          ],
        ),
      ),
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

  // ── Room card ────────────────────────────────────────────────────────────
  Widget _buildRoomCard(String roomName, List<PcHealthRecord> records) {
    final issueCount = records.where((r) => !_styleForStatus(r.status).isHealthy).length;
    
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _selectedRoom = roomName);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _fieldColor,
                            _fieldColor.withValues(alpha: 0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.meeting_room_rounded,
                        color: _accentAForeground,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            roomName,
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.devices_rounded, size: 12, color: _subTextColor),
                              const SizedBox(width: 4),
                              Text(
                                '${records.length} workstation${records.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: _subTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (issueCount > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8787)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.notifications_active_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$issueCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _fieldColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: _subTextColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _HealthStyle _styleForStatus(String value) {
    final status = value.trim().toLowerCase();
    if (['healthy', 'ok', 'online', 'normal', 'working'].contains(status)) {
      return const _HealthStyle(Icons.check_circle_rounded, Color(0xFF4CAF50), true);
    }
    if (status.contains('offline')) {
      return _HealthStyle(Icons.cloud_off_rounded, _subTextColor, false);
    }
    if (status.contains('critical') ||
        status.contains('broken') ||
        status.contains('failed')) {
      return const _HealthStyle(Icons.error_rounded, Color(0xFFFF6B6B), false);
    }
    if (status.contains('minor') ||
        status.contains('warning') ||
        status.contains('degraded')) {
      return const _HealthStyle(Icons.warning_amber_rounded, Color(0xFFF7B84F), false);
    }
    return _HealthStyle(Icons.help_outline_rounded, _accentBForeground, false);
  }
}

class _HealthStyle {
  final IconData icon;
  final Color color;
  final bool isHealthy;

  const _HealthStyle(this.icon, this.color, this.isHealthy);
}

