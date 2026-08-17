import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/fault_report.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/message_state.dart';

class RepairManagementScreen extends StatefulWidget {
  final AppUser user;

  const RepairManagementScreen({super.key, required this.user});

  @override
  State<RepairManagementScreen> createState() => _RepairManagementScreenState();
}

class _RepairManagementScreenState extends State<RepairManagementScreen> {
  final _searchController = TextEditingController();
  final _updating = <String>{};
  Future<List<FaultReport>>? _future;
  Timer? _timer;
  bool _showRepaired = false;

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
  Color get _repairedColor => const Color(0xFF2EE6C5);

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
      _future = StaffService.instance.listFaultReports();
    });
  }

  Future<void> _markRepaired(FaultReport report) async {
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (saving || !(formKey.currentState?.validate() ?? false)) return;
              setDialogState(() => saving = true);
              setState(() => _updating.add(report.id));
              try {
                await StaffService.instance.markRepaired(
                  reportId: report.id,
                  notes: notesController.text,
                );
                if (!dialogContext.mounted || !mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Repair submitted for Teacher approval.'),
                  ),
                );
                _refresh();
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() => saving = false);
                }
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(cleanError(error))),
                  );
                }
              } finally {
                if (mounted) setState(() => _updating.remove(report.id));
              }
            }

            return Dialog(
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: _borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  _accentA.withValues(alpha: 0.18),
                                  _accentB.withValues(alpha: 0.14),
                                ],
                              ),
                            ),
                            child: Icon(Icons.build_rounded, color: _accentA, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Submit Repair for Teacher Approval',
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${report.roomName} · ${report.pcId}',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.issue,
                        style: TextStyle(color: _subTextColor, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: notesController,
                        enabled: !saving,
                        maxLines: 4,
                        style: TextStyle(color: _textColor, fontSize: 14),
                        cursorColor: _accentA,
                        decoration: InputDecoration(
                          labelText: 'Technician Notes / Action Taken',
                          alignLabelWithHint: true,
                          labelStyle: TextStyle(color: _subTextColor, fontSize: 13.5),
                          prefixIcon: Icon(Icons.description_outlined,
                              color: _subTextColor, size: 20),
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
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter the repair action or notes.'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: saving ? null : () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(foregroundColor: _subTextColor),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          _buildGradientButton(
                            label: saving ? 'Saving…' : 'Submit Repair',
                            icon: Icons.check_rounded,
                            loading: saving,
                            onPressed: saving ? null : save,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    notesController.dispose();
  }

  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: loading
            ? null
            : LinearGradient(colors: [_accentA, _accentB]),
        color: loading ? _accentA.withValues(alpha: 0.25) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF080A0E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        icon: loading
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF080A0E)),
          ),
        )
            : Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
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
          child: FutureBuilder<List<FaultReport>>(
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
                  title: 'Could not load repairs',
                  message: cleanError(snapshot.error!),
                  onRetry: _refresh,
                );
              }

              final search = _searchController.text.trim().toLowerCase();
              final reports = (snapshot.data ?? const <FaultReport>[])
                  .where((report) {
                if (!_showRepaired && report.repaired) return false;
                if (search.isEmpty) return true;
                return [
                  report.roomName,
                  report.pcId,
                  report.issue,
                  report.details,
                  report.studentEmail ?? '',
                  report.severity,
                ].join(' ').toLowerCase().contains(search);
              }).toList()
                ..sort((a, b) {
                  if (a.repaired != b.repaired) return a.repaired ? 1 : -1;
                  final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });

              if (reports.isEmpty) {
                return const MessageState(
                  icon: Icons.build_circle_outlined,
                  title: 'No matching repair reports',
                  message: 'Open fault reports from Student PCs will appear here.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                color: _accentA,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final updating = _updating.contains(report.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildReportCard(report, updating),
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
              labelText: 'Search room, PC, issue, or student',
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
        _buildIncludeRepairedToggle(),
        const SizedBox(width: 10),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildIncludeRepairedToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showRepaired = !_showRepaired),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _showRepaired ? null : _fieldColor,
          gradient: _showRepaired
              ? LinearGradient(
            colors: [
              _accentA.withValues(alpha: 0.2),
              _accentB.withValues(alpha: 0.16),
            ],
          )
              : null,
          border: Border.all(
            color: _showRepaired ? _accentA.withValues(alpha: 0.5) : _borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 18,
              color: _showRepaired ? _accentA : _subTextColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Include repaired',
              style: TextStyle(
                fontSize: 13,
                fontWeight: _showRepaired ? FontWeight.w600 : FontWeight.w400,
                color: _showRepaired ? _textColor : _subTextColor,
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

  // ── Report card ──────────────────────────────────────────────────────────
  Widget _buildReportCard(FaultReport report, bool updating) {
    final color = report.repaired ? _repairedColor : _severityColor(report.severity);
    final lines = <String>[
      report.issue,
      if (report.details.isNotEmpty) report.details,
      'Severity: ${report.severity.toUpperCase()}',
      if ((report.studentEmail ?? '').isNotEmpty) 'Student: ${report.studentEmail}',
      'Reported: ${formatDateTime(report.createdAt)}',
      if (report.repaired) 'Repaired: ${formatDateTime(report.repairedAt)}',
      'Workflow: ${report.workflowStatus.replaceAll('_', ' ').toUpperCase()}',
      if ((report.technicianNotes ?? '').isNotEmpty)
        'Action: ${report.technicianNotes}',
    ];

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
              color: color.withValues(alpha: 0.14),
            ),
            child: Icon(
              report.repaired ? Icons.check_circle_rounded : Icons.build_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.roomName} · ${report.pcId}',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lines.join('\n'),
                  style: TextStyle(color: _subTextColor, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _reportAction(report, updating),
        ],
      ),
    );
  }

  Widget _buildRepairedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _repairedColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _repairedColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: _repairedColor),
          const SizedBox(width: 5),
          Text(
            'Repaired',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _repairedColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportAction(FaultReport report, bool updating) {
    if (report.repaired || report.workflowStatus == 'resolved') {
      return _buildRepairedBadge();
    }
    if (report.workflowStatus == 'awaiting_teacher_approval') {
      return _workflowBadge(
        'Awaiting Teacher',
        const Color(0xFF4F8EF7),
        Icons.school_rounded,
      );
    }
    if (report.workflowStatus == 'reported') {
      return _workflowBadge(
        'Teacher Review',
        const Color(0xFFF7B84F),
        Icons.rate_review_rounded,
      );
    }
    return _buildGradientButton(
      label: 'Submit Repair',
      icon: Icons.build_rounded,
      loading: updating,
      onPressed: updating ? null : () => _markRepaired(report),
    );
  }

  Widget _workflowBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color _severityColor(String value) {
  switch (value.trim().toLowerCase()) {
    case 'critical':
    case 'high':
      return const Color(0xFFFF6B6B);
    case 'low':
    case 'minor':
      return const Color(0xFFF7B84F);
    default:
      return const Color(0xFFFF9F5A);
  }
}
