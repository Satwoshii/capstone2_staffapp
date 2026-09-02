import 'package:flutter/material.dart';

import '../models/pc_health_record.dart';
import '../utils/value_helpers.dart';

class RoomPcStatusScreen extends StatefulWidget {
  final String roomName;
  final List<PcHealthRecord> records;
  final VoidCallback? onBack;

  const RoomPcStatusScreen({
    super.key,
    required this.roomName,
    required this.records,
    this.onBack,
  });

  @override
  State<RoomPcStatusScreen> createState() => _RoomPcStatusScreenState();
}

class _RoomPcStatusScreenState extends State<RoomPcStatusScreen> {
  final _searchController = TextEditingController();
  bool _issuesOnly = false;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _textColor),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.roomName,
              style: TextStyle(
                color: _textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${widget.records.length} workstation${widget.records.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: _subTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: _borderColor),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: _buildToolbar(),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final search = _searchController.text.trim().toLowerCase();
                
                final filteredRecords = widget.records.where((record) {
                  final style = _styleForStatus(record.status);
                  if (_issuesOnly && style.isHealthy) return false;
                  if (search.isEmpty) return true;
                  return [
                    record.pcId,
                    record.status,
                    record.lastDisplayName ?? '',
                    readableHealthDetails(record.details),
                  ].join(' ').toLowerCase().contains(search);
                }).toList();

                if (filteredRecords.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.monitor_heart_outlined,
                            size: 64,
                            color: _subTextColor.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _issuesOnly ? 'No matching issues' : 'No workstations found',
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search or filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _subTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final width = constraints.maxWidth;
                // Responsive grid: 5 columns on wide screens, down to 1 on mobile
                final int crossAxisCount = width > 1500 ? 5 : (width > 1200 ? 4 : (width > 900 ? 3 : (width > 600 ? 2 : 1)));
                const double spacing = 16.0;
                final double itemWidth = (width - 48 - (crossAxisCount - 1) * spacing) / crossAxisCount;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: filteredRecords.map((record) {
                      return SizedBox(
                        width: itemWidth,
                        height: 310, // Fixed height for a uniform "card" look
                        child: _buildPcRecord(record),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
              labelText: 'Search PC, status, or display name',
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
        _buildIssuesOnlyToggle(),
      ],
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

  Widget _buildPcRecord(PcHealthRecord record) {
    final style = _styleForStatus(record.status);
    final summary = readableHealthIssueSummary(record.details);

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: style.isHealthy ? _borderColor : style.color.withValues(alpha: 0.25),
          width: style.isHealthy ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.25 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showRecordDetails(record, style),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        style.color.withValues(alpha: 0.18),
                        style.color.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(style.icon, color: style.color, size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  record.pcId,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  formatDateTime(record.lastCheck),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _subTextColor.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusBadge(record.status, style),
                const SizedBox(height: 16),
                if ((record.lastDisplayName ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'User: ${record.lastDisplayName}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textColor.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (summary.isNotEmpty)
                  Text.rich(
                    _buildHealthSpan(
                      summary,
                      TextStyle(
                        color: style.isHealthy
                            ? _subTextColor.withValues(alpha: 0.8)
                            : style.color.withValues(alpha: 0.8),
                        fontSize: 12.5,
                        fontWeight: style.isHealthy ? FontWeight.w500 : FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'VIEW DETAILS',
                      style: TextStyle(
                        color: style.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: style.color,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRecordDetails(PcHealthRecord record, _HealthStyle style) {
    final details = readableHealthDetails(record.details);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
            child: Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                style.color.withValues(alpha: 0.15),
                                style.color.withValues(alpha: 0.05),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(style.icon, color: style.color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.pcId,
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatDateTime(record.lastCheck),
                                style: TextStyle(
                                  color: _subTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: _subTextColor, size: 20),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildStatusBadge(record.status, style),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: _borderColor),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((record.lastDisplayName ?? '').isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: _fieldColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline_rounded, size: 15, color: _subTextColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Last user: ${record.lastDisplayName}',
                                    style: TextStyle(
                                      color: _textColor.withValues(alpha: 0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          Text(
                            'Full Status',
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text.rich(
                            _buildHealthSpan(
                              details.isNotEmpty ? details : 'No additional details available.',
                              TextStyle(
                                color: _subTextColor,
                                fontSize: 13.5,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, _HealthStyle style) {
    final color = style.isHealthy ? const Color(0xFF4CAF50) : style.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
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

  TextSpan _buildHealthSpan(String text, TextStyle baseStyle) {
    final lines = text.split('\n');
    return TextSpan(
      style: baseStyle,
      children: lines.asMap().entries.map((entry) {
        final line = entry.value;
        final isLast = entry.key == lines.length - 1;

        List<InlineSpan> spans = [];
        if (line.startsWith('Issues:')) {
          spans.add(TextSpan(
            text: 'Issues: ',
            style: baseStyle.copyWith(fontWeight: FontWeight.w900),
          ));
          spans.add(TextSpan(text: line.substring(8)));
        } else if (line.startsWith('Severity:')) {
          spans.add(TextSpan(
            text: 'Severity: ',
            style: baseStyle.copyWith(fontWeight: FontWeight.w900),
          ));
          spans.add(TextSpan(text: line.substring(10)));
        } else if (line.startsWith('Status:')) {
          spans.add(TextSpan(
            text: 'Status: ',
            style: baseStyle.copyWith(fontWeight: FontWeight.w900),
          ));
          spans.add(TextSpan(text: line.substring(8)));
        } else {
          spans.add(TextSpan(text: line));
        }

        if (!isLast) {
          spans.add(const TextSpan(text: '\n'));
        }
        return TextSpan(children: spans);
      }).toList(),
    );
  }
}

class _HealthStyle {
  final IconData icon;
  final Color color;
  final bool isHealthy;

  const _HealthStyle(this.icon, this.color, this.isHealthy);
}