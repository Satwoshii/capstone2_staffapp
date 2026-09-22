import 'package:flutter/material.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';

class RoomInventoryDetailScreen extends StatefulWidget {
  final String roomName;
  final List<Map<String, dynamic>> inventory;
  final List<Map<String, dynamic>> compliance;
  final List<Map<String, dynamic>> requiredSoftware;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const RoomInventoryDetailScreen({
    super.key,
    required this.roomName,
    required this.inventory,
    required this.compliance,
    required this.requiredSoftware,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  State<RoomInventoryDetailScreen> createState() => _RoomInventoryDetailScreenState();
}

class _RoomInventoryDetailScreenState extends State<RoomInventoryDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchController = TextEditingController();
  bool _issuesOnly = false;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor => _isDarkMode ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
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
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _isCompliant(String status) =>
      status == 'installed' || status == 'manually_verified';

  void _showInventoryDetails(Map<String, dynamic> r) {
    final ramBytes = (r['ram_total_bytes'] as num?)?.toInt() ?? 0;
    final storageBytes = (r['total_storage_bytes'] as num?)?.toInt() ?? 0;
    final windows = '${r['windows_version'] ?? ''} ${r['windows_build'] ?? ''}'.trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.computer_rounded, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['pc_id'] ?? 'PC Details', style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(r['computer_name'] ?? '', style: TextStyle(color: _subTextColor, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailKv('CPU', r['cpu_name']),
                _detailKv('RAM', bytesToGb(ramBytes)),
                _detailKv('Storage', bytesToGb(storageBytes)),
                _detailKv('Windows', windows),
                const Divider(height: 24),
                _detailKv('MAC address', r['mac_address']),
                _detailKv('Local IP', r['local_ip']),
                _detailKv('System UUID', r['system_uuid']),
                _detailKv('BIOS serial', r['bios_serial_number']),
                _detailKv('Motherboard', '${r['motherboard_manufacturer'] ?? ''} ${r['motherboard_model'] ?? ''}'.trim()),
                _detailKv('Motherboard serial', r['motherboard_serial']),
                _detailKv('CPU cores / threads', '${r['cpu_cores'] ?? '?'} / ${r['cpu_threads'] ?? '?'}'),
                _detailKv('GPU', readableValue(r['gpu'])),
                _detailKv('Disks', readableValue(r['disks'])),
                _detailKv('Last inventory', r['last_inventory_at']),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE', style: TextStyle(color: _accentAForeground, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          ),
        ],
      ),
    );
  }

  void _showComplianceDetails(String pcId, List<Map<String, dynamic>> records) {
    final issuesCount = records.where((r) => !_isCompliant((r['status'] ?? 'unknown').toString())).length;
    final isHealthy = issuesCount == 0;
    final color = isHealthy ? const Color(0xFF4CAF50) : const Color(0xFFF7B84F);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(isHealthy ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Compliance: $pcId', style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(isHealthy ? 'All software compliant' : '$issuesCount issue${issuesCount == 1 ? '' : 's'} found',
                      style: TextStyle(color: isHealthy ? _subTextColor : color, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: records.map((r) => _SoftwareComplianceItem(
                row: r,
                isCompliant: _isCompliant((r['status'] ?? 'unknown').toString()),
                textColor: _textColor,
                subTextColor: _subTextColor,
                borderColor: _borderColor,
                buttonBg: _buttonBg,
                buttonFg: _buttonFg,
                onVerify: () async {
                  try {
                    await StaffService.instance.manuallyVerifySoftware(
                      workstationId: (r['workstation_id'] ?? '').toString(),
                      requiredSoftwareId: (r['required_software_id'] as num).toInt(),
                      notes: 'Verified manually during ITSO maintenance.',
                    );
                    if (context.mounted) Navigator.pop(context);
                    widget.onRefresh();
                  } catch (error) {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(cleanError(error))));
                  }
                },
              )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE', style: TextStyle(color: _accentAForeground, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          ),
        ],
      ),
    );
  }

  void _showRequirementDetails(Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.apps_rounded, color: Colors.indigo, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['software_name'] ?? 'Requirement', style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('Requirement rules', style: TextStyle(color: _subTextColor, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailKv('Software Name', r['software_name']),
                _detailKv('Min Version', r['minimum_version'] ?? 'Any version'),
                _detailKv('Publisher', r['publisher'] ?? 'Any publisher'),
                _detailKv('Match Pattern', r['match_pattern'] ?? 'Exact name'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE', style: TextStyle(color: _accentAForeground, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteRequirement(Map<String, dynamic> r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Delete Requirement', style: TextStyle(color: _textColor)),
        content: Text('Are you sure you want to remove this software requirement?', style: TextStyle(color: _textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: _subTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await StaffService.instance.deleteRequiredSoftware((r['id'] as num).toInt());
        widget.onRefresh();
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error))));
      }
    }
  }

  String bytesToGb(int bytes) => bytes <= 0 ? 'Unknown' : '${(bytes / 1073741824).toStringAsFixed(1)} GB';

  Widget _detailKv(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 150, child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _subTextColor))),
        Expanded(child: Text((value ?? 'Not available').toString(), style: TextStyle(fontSize: 13, color: _textColor, fontWeight: FontWeight.w500))),
      ],
    ),
  );

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
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.roomName,
              style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              '${widget.inventory.length} workstation${widget.inventory.length == 1 ? '' : 's'}',
              style: TextStyle(color: _subTextColor, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _accentAForeground,
          unselectedLabelColor: _subTextColor,
          indicatorColor: _accentAForeground,
          tabs: const [
            Tab(text: 'Specifications'),
            Tab(text: 'Compliance'),
            Tab(text: 'Requirements'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: _buildToolbar(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildInventoryTab(),
                _buildComplianceTab(),
                _buildRequiredTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
              labelText: _tabs.index == 2 ? 'Search software name' : 'Search PC ID or computer name',
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
        if (_tabs.index == 1) ...[
          const SizedBox(width: 12),
          _buildIssuesOnlyToggle(),
        ],
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
          color: _issuesOnly ? activeColor.withValues(alpha: 0.15) : _fieldColor,
          border: Border.all(
            color: _issuesOnly ? activeColor.withValues(alpha: 0.5) : _borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: _issuesOnly ? activeColor : _subTextColor),
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

  Widget _buildInventoryTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered = widget.inventory.where((r) {
          if (query.isEmpty) return true;
          final haystack = [r['pc_id'], r['computer_name'], r['cpu_name']]
              .map((v) => (v ?? '').toString().toLowerCase())
              .join(' ');
          return haystack.contains(query);
        }).toList();

        if (filtered.isEmpty) return _buildEmptyState('No workstations found matching search');

        return RefreshIndicator(
          onRefresh: () async => widget.onRefresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                children: filtered.map((r) => _InventoryPcCard(
                  row: r,
                  cardColor: _cardColor,
                  fieldColor: _fieldColor,
                  borderColor: _borderColor,
                  textColor: _textColor,
                  subTextColor: _subTextColor,
                  onTap: () => _showInventoryDetails(r),
                )).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComplianceTab() {
     return LayoutBuilder(
      builder: (context, constraints) {
        final query = _searchController.text.trim().toLowerCase();
        
        final Map<String, List<Map<String, dynamic>>> pcGroups = {};
        for (var r in widget.compliance) {
          final pcId = (r['pc_id'] ?? 'Unknown').toString();
          pcGroups.putIfAbsent(pcId, () => []).add(r);
        }

        final filteredPcIds = pcGroups.keys.where((pcId) {
          final records = pcGroups[pcId]!;
          if (_issuesOnly) {
            final hasIssue = records.any((r) => !_isCompliant((r['status'] ?? 'unknown').toString()));
            if (!hasIssue) return false;
          }
          if (query.isNotEmpty) {
            final matchesPcId = pcId.toLowerCase().contains(query);
            final matchesAnySoftware = records.any((r) {
               final softwareName = (r['software_name'] ?? '').toString().toLowerCase();
               final detectedName = (r['detected_name'] ?? '').toString().toLowerCase();
               return softwareName.contains(query) || detectedName.contains(query);
            });
            return matchesPcId || matchesAnySoftware;
          }
          return true;
        }).toList()..sort();

        if (filteredPcIds.isEmpty) return _buildEmptyState('No compliance records match your filters');

        return RefreshIndicator(
          onRefresh: () async => widget.onRefresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                children: filteredPcIds.map((pcId) {
                  final records = pcGroups[pcId]!;
                  return _PcComplianceGroupCard(
                    pcId: pcId,
                    records: records,
                    cardColor: _cardColor,
                    fieldColor: _fieldColor,
                    borderColor: _borderColor,
                    textColor: _textColor,
                    subTextColor: _subTextColor,
                    onTap: () => _showComplianceDetails(pcId, records),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequiredTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered = widget.requiredSoftware.where((r) {
          if (query.isEmpty) return true;
          return (r['software_name'] ?? '').toString().toLowerCase().contains(query);
        }).toList();

        if (filtered.isEmpty) return _buildEmptyState('No required software configured');

        return RefreshIndicator(
          onRefresh: () async => widget.onRefresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                children: filtered.map((r) => _RequiredSoftwareCard(
                  row: r,
                  cardColor: _cardColor,
                  fieldColor: _fieldColor,
                  borderColor: _borderColor,
                  textColor: _textColor,
                  subTextColor: _subTextColor,
                  onTap: () => _showRequirementDetails(r),
                  onDelete: () => _handleDeleteRequirement(r),
                )).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: _subTextColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: _subTextColor)),
        ],
      ),
    );
  }
}

class _InventoryPcCard extends StatelessWidget {
  const _InventoryPcCard({required this.row, required this.cardColor, required this.fieldColor, required this.borderColor, required this.textColor, required this.subTextColor, required this.onTap});
  final Map<String, dynamic> row;
  final Color cardColor;
  final Color fieldColor;
  final Color borderColor;
  final Color textColor;
  final Color subTextColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: 210,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.computer_rounded, color: Colors.blue, size: 28),
                ),
                const SizedBox(height: 16),
                Text(row['pc_id'] ?? 'Unknown', style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
                Text(row['computer_name'] ?? '', style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('VIEW SPECS', style: TextStyle(color: Colors.blue.shade600, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.blue.shade600),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PcComplianceGroupCard extends StatelessWidget {
  const _PcComplianceGroupCard({
    required this.pcId,
    required this.records,
    required this.cardColor,
    required this.fieldColor,
    required this.borderColor,
    required this.textColor,
    required this.subTextColor,
    required this.onTap,
  });

  final String pcId;
  final List<Map<String, dynamic>> records;
  final Color cardColor;
  final Color fieldColor;
  final Color borderColor;
  final Color textColor;
  final Color subTextColor;
  final VoidCallback onTap;

  bool _isCompliant(String status) =>
      status == 'installed' || status == 'manually_verified';

  @override
  Widget build(BuildContext context) {
    final issuesCount = records.where((r) => !_isCompliant((r['status'] ?? 'unknown').toString())).length;
    final isHealthy = issuesCount == 0;
    final color = isHealthy ? const Color(0xFF4CAF50) : const Color(0xFFF7B84F);

    return Container(
      width: 380,
      height: 210,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isHealthy ? borderColor : color.withValues(alpha: 0.3),
          width: isHealthy ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isHealthy ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(pcId, style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
                Text(
                  isHealthy ? 'Compliant' : '$issuesCount Issue${issuesCount == 1 ? '' : 's'} found',
                  style: TextStyle(
                    color: isHealthy ? subTextColor : color,
                    fontSize: 12,
                    fontWeight: isHealthy ? FontWeight.w500 : FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('CHECK STATUS', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: color),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequiredSoftwareCard extends StatelessWidget {
  const _RequiredSoftwareCard({
    required this.row,
    required this.cardColor,
    required this.fieldColor,
    required this.borderColor,
    required this.textColor,
    required this.subTextColor,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> row;
  final Color cardColor;
  final Color fieldColor;
  final Color borderColor;
  final Color textColor;
  final Color subTextColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 380,
          height: 210,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.apps_rounded, color: Colors.indigo, size: 28),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      row['software_name'] ?? 'Unknown',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Requirement rule',
                      style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'VIEW DETAILS',
                          style: TextStyle(color: Colors.indigo.shade600, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.indigo.shade600),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 22),
            onPressed: onDelete,
            tooltip: 'Remove requirement',
          ),
        ),
      ],
    );
  }
}

class _SoftwareComplianceItem extends StatelessWidget {
  const _SoftwareComplianceItem({
    required this.row,
    required this.isCompliant,
    required this.textColor,
    required this.subTextColor,
    required this.borderColor,
    required this.buttonBg,
    required this.buttonFg,
    required this.onVerify,
  });

  final Map<String, dynamic> row;
  final bool isCompliant;
  final Color textColor;
  final Color subTextColor;
  final Color borderColor;
  final Color buttonBg;
  final Color buttonFg;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final status = (row['status'] ?? 'unknown').toString().toUpperCase().replaceAll('_', ' ');
    final color = isCompliant ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B);
    final detected = row['detected_name'] == null
        ? 'Not detected'
        : '${row['detected_name']} ${row['detected_version'] ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCompliant ? borderColor : color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isCompliant ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                  color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row['software_name'] ?? 'Unknown',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _kv('Detected', detected),
          _kv('Publisher (Rule)', row['publisher']),
          _kv('Min version (Rule)', row['minimum_version']),
          _kv('Match pattern', row['match_pattern']),
          if (!isCompliant) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onVerify,
                style: FilledButton.styleFrom(
                  backgroundColor: buttonBg,
                  foregroundColor: buttonFg,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Mark as Verified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: subTextColor))),
        Expanded(child: Text((value ?? 'Any').toString(), style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500))),
      ],
    ),
  );
}
