import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pc_health_record.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/message_state.dart';

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
  final Set<String> _expandedRecords = <String>{};

  // ── Palette (matches the rest of the app) ───────────────────────────────
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _cardColor => _isDarkMode ? const Color(0xFF13141A) : Colors.white;
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: _buildToolbar(),
        ),
        Expanded(
          child: FutureBuilder<List<PcHealthRecord>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_accentA),
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
              final records = (snapshot.data ?? const <PcHealthRecord>[])
                  .where((record) {
                final style = _styleForStatus(record.status);
                if (_issuesOnly && style.isHealthy) return false;
                if (search.isEmpty) return true;
                return [
                  record.roomName,
                  record.pcId,
                  record.status,
                  record.lastStudentEmail ?? '',
                  readableHealthDetails(record.details),
                ].join(' ').toLowerCase().contains(search);
              }).toList()
                ..sort((a, b) {
                  final aTime = a.lastCheck ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime = b.lastCheck ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });

              if (records.isEmpty) {
                return MessageState(
                  icon: Icons.monitor_heart_outlined,
                  title: _issuesOnly ? 'No matching issues' : 'No PC health records',
                  message: _issuesOnly
                      ? 'No unhealthy PCs match the filter.'
                      : 'Student PCs will appear after their first status sync.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                color: _accentA,
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
            cursorColor: _accentA,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search room, PC, status, or student',
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
                borderSide: BorderSide(color: _accentA, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildIssuesOnlyToggle(),
        const SizedBox(width: 10),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildIssuesOnlyToggle() {
    return GestureDetector(
      onTap: () => setState(() => _issuesOnly = !_issuesOnly),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _issuesOnly ? null : _fieldColor,
          gradient: _issuesOnly
              ? LinearGradient(
            colors: [
              _accentA.withValues(alpha: 0.2),
              _accentB.withValues(alpha: 0.16),
            ],
          )
              : null,
          border: Border.all(
            color: _issuesOnly ? _accentA.withValues(alpha: 0.5) : _borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: _issuesOnly ? _accentA : _subTextColor,
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
        icon: Icon(Icons.refresh_rounded, color: _accentB, size: 20),
      ),
    );
  }

  // ── Record card ──────────────────────────────────────────────────────────
  Widget _buildRecordCard(PcHealthRecord record) {
    final style = _styleForStatus(record.status);
    final recordKey = '${record.roomName}|${record.pcId}';
    final isExpanded = _expandedRecords.contains(recordKey);
    final details = isExpanded
        ? readableHealthDetails(record.details)
        : readableHealthIssueSummary(record.details);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedRecords.remove(recordKey);
            } else {
              _expandedRecords.add(recordKey);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExpanded
                  ? style.color.withValues(alpha: 0.32)
                  : _borderColor,
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
                  color: style.color.withValues(alpha: 0.14),
                ),
                child: Icon(style.icon, color: style.color, size: 22),
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
                        _buildStatusBadge(record.status, style),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _subTextColor,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Last check: ${formatDateTime(record.lastCheck)}',
                      style: TextStyle(color: _subTextColor, fontSize: 12.5),
                    ),
                    if ((record.lastStudentEmail ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Last student: ${record.lastStudentEmail}',
                          style: TextStyle(
                            color: _subTextColor,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    if (details.isNotEmpty)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            details,
                            style: TextStyle(
                              color: _subTextColor,
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        isExpanded
                            ? 'Click to hide full status'
                            : 'Click to view all component statuses',
                        style: TextStyle(
                          color: style.color.withValues(alpha: 0.85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, _HealthStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 13, color: style.color),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: style.color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthStyle {
  final IconData icon;
  final Color color;
  final bool isHealthy;

  const _HealthStyle(this.icon, this.color, this.isHealthy);
}

_HealthStyle _styleForStatus(String value) {
  final status = value.trim().toLowerCase();
  if (['healthy', 'ok', 'online', 'normal', 'working'].contains(status)) {
    return const _HealthStyle(Icons.check_circle, Color(0xFF2EE6C5), true);
  }
  if (status.contains('critical') ||
      status.contains('broken') ||
      status.contains('offline') ||
      status.contains('failed')) {
    return const _HealthStyle(Icons.error, Color(0xFFFF6B6B), false);
  }
  if (status.contains('minor') ||
      status.contains('warning') ||
      status.contains('degraded')) {
    return const _HealthStyle(Icons.warning_amber, Color(0xFFF7B84F), false);
  }
  return const _HealthStyle(Icons.help_outline, Color(0xFF4F8EF7), false);
}
