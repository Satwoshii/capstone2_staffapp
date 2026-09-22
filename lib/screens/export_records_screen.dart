import 'package:flutter/material.dart';

import '../services/staff_service.dart';
import '../utils/value_helpers.dart';

class ExportRecordsScreen extends StatefulWidget {
  const ExportRecordsScreen({super.key});

  @override
  State<ExportRecordsScreen> createState() => _ExportRecordsScreenState();
}

class _ExportRecordsScreenState extends State<ExportRecordsScreen> {
  String _type = 'reports';
  String _format = 'csv';
  DateTime? _from;
  DateTime? _to;
  final _room = TextEditingController();
  bool _busy = false;

  static const _labels = {
    'reports': 'Reports',
    'repairs': 'Repairs',
    'audit_logs': 'Audit logs',
    'login_records': 'Login records',
    'maintenance_records': 'Maintenance records',
  };

  static const _typeIcons = {
    'reports': Icons.description_outlined,
    'repairs': Icons.build_outlined,
    'audit_logs': Icons.fact_check_outlined,
    'login_records': Icons.login_outlined,
    'maintenance_records': Icons.handyman_outlined,
  };

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _cardColor => _isDarkMode ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor => _isDarkMode ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _accentA => const Color(0xFFFFD700);
  Color get _accentB => const Color(0xFF003366);
  Color get _accentAForeground => _isDarkMode ? _accentA : _accentB;
  Color get _textColor => _isDarkMode ? Colors.white : const Color(0xFF1A1C1E);
  Color get _subTextColor => _isDarkMode ? Colors.white54 : Colors.black45;
  Color get _borderColor => _isDarkMode
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.09);
  Color get _buttonBg => _isDarkMode ? _accentA : _accentB;
  Color get _buttonFg => _isDarkMode ? Colors.black : Colors.white;

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  Future<void> _pick(bool from) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _accentAForeground,
              primary: _accentAForeground,
              onPrimary: _buttonFg,
              surface: _cardColor,
              onSurface: _textColor,
              brightness: _isDarkMode ? Brightness.dark : Brightness.light,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: _cardColor,
              headerBackgroundColor: _accentAForeground,
              headerForegroundColor: _buttonFg,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              dayStyle: const TextStyle(fontWeight: FontWeight.w600),
              yearStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _accentAForeground,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (selected != null) {
      setState(() => from
          ? _from = selected
          : _to = selected.add(const Duration(hours: 23, minutes: 59, seconds: 59)));
    }
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await StaffService.instance.exportRecords(
        type: _type,
        format: _format,
        dateFrom: _from,
        dateTo: _to,
        roomName: _room.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export saved to ${file.path}')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hasDateRange = _from != null || _to != null;

    // CENTERED AND FIXED WIDTH WRAPPER
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900), // <--- FIXED WIDTH HERE
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // ---- Simple Header ----
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: _accentAForeground, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Record Export',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Authorized personnel only. All exports are logged to the audit system.',
                    style: TextStyle(color: _subTextColor, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            // ---- Main Card ----
            Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Section 1: Data Type ---
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('WHAT TO EXPORT', Icons.dataset_outlined),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _labels.entries.map((e) {
                            final selected = e.key == _type;
                            return ChoiceChip(
                              label: Text(e.value),
                              avatar: Icon(
                                _typeIcons[e.key],
                                size: 16,
                                color: selected ? _accentAForeground : _subTextColor,
                              ),
                              selected: selected,
                              showCheckmark: false,
                              backgroundColor: _fieldColor,
                              selectedColor: _accentAForeground.withValues(alpha: 0.1),
                              side: BorderSide(
                                color: selected ? _accentAForeground.withValues(alpha: 0.4) : _borderColor,
                              ),
                              labelStyle: TextStyle(
                                color: selected ? _textColor : _subTextColor,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 12,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              onSelected: _busy ? null : (_) => setState(() => _type = e.key),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SegmentedButton<String>(
                                style: SegmentedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  selectedBackgroundColor: _accentAForeground.withValues(alpha: 0.1),
                                  selectedForegroundColor: _textColor,
                                  side: BorderSide(color: _borderColor),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: 'csv',
                                    label: Text('CSV'),
                                    icon: Icon(Icons.table_chart_outlined, size: 18),
                                  ),
                                  ButtonSegment(
                                    value: 'pdf',
                                    label: Text('PDF'),
                                    icon: Icon(Icons.picture_as_pdf_outlined, size: 18),
                                  ),
                                ],
                                selected: {_format},
                                onSelectionChanged: _busy ? null : (v) => setState(() => _format = v.first),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: _borderColor),

                  // --- Section 2: Filters ---
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('FILTERS', Icons.filter_list_rounded),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _room,
                          enabled: !_busy,
                          style: TextStyle(color: _textColor, fontSize: 14),
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Room Name',
                            hintText: 'Optional filter',
                            prefixIcon: Icon(Icons.meeting_room_outlined, size: 20, color: _subTextColor),
                            filled: true,
                            fillColor: _fieldColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _borderColor)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDateBtn('From Date', _from, true),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDateBtn('To Date', _to, false),
                            ),
                          ],
                        ),
                        if (hasDateRange) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => setState(() { _from = null; _to = null; }),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Clear date range', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(foregroundColor: _subTextColor, visualDensity: VisualDensity.compact),
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: _subTextColor),
                              const SizedBox(width: 6),
                              Text(
                                'No date range selected (Exporting all)',
                                style: TextStyle(color: _subTextColor, fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // --- Section 3: Action ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _accentAForeground.withValues(alpha: 0.05),
                      border: Border(top: BorderSide(color: _borderColor)),
                    ),
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _export,
                      style: FilledButton.styleFrom(
                        backgroundColor: _buttonBg,
                        foregroundColor: _buttonFg,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: _busy
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _buttonFg))
                          : const Icon(Icons.download_rounded),
                      label: Text(
                        _busy ? 'EXPORTING...' : 'EXPORT ${_format.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _accentAForeground),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: _textColor,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDateBtn(String label, DateTime? date, bool from) {
    return OutlinedButton(
      onPressed: _busy ? null : () => _pick(from),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: _borderColor),
        backgroundColor: _fieldColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        date == null ? label : _fmtDate(date),
        style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
