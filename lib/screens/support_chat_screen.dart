import 'dart:async';

import 'package:flutter/material.dart';

import '../models/support_chat_message.dart';
import '../models/support_conversation.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/message_state.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  Timer? _timer;
  List<SupportConversation> _conversations = const [];
  List<SupportChatMessage> _messages = const [];
  SupportConversation? _selected;
  String _statusFilter = 'active';
  bool _loadingList = true;
  bool _refreshingList = false;
  bool _loadingMessages = false;
  bool _sending = false;
  bool _updatingStatus = false;
  String? _listError;
  String? _messageError;

  static const _activeStatuses = {
    'open',
    'acknowledged',
    'in_progress',
    'waiting_for_student',
    'waiting_for_repair',
  };

  // ── Palette (matches StaffLoginScreen) ─────────────────────────────────────
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF13141A) : Colors.white;
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
  Color get _errorColor => const Color(0xFFFF6B6B);

  LinearGradient get _accentGradient => LinearGradient(
    colors: [_accentA, _accentB],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _refreshConversations();
    _timer = Timer.periodic(
      const Duration(seconds: 4),
          (_) => _refreshConversations(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Data (unchanged logic) ──────────────────────────────────────────────
  Future<void> _refreshConversations({bool silent = false}) async {
    if (_refreshingList) return;
    _refreshingList = true;
    if (!silent && mounted) {
      setState(() {
        _loadingList = true;
        _listError = null;
      });
    }

    try {
      final conversations =
      await StaffService.instance.listSupportConversations();
      SupportConversation? selected;
      final selectedId = _selected?.id;
      if (selectedId != null) {
        for (final item in conversations) {
          if (item.id == selectedId) {
            selected = item;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _selected = selected;
        _loadingList = false;
        _listError = null;
      });

      if (selected != null) {
        await _loadMessages(selected, silent: true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError = cleanError(error);
      });
    } finally {
      _refreshingList = false;
    }
  }

  Future<void> _selectConversation(SupportConversation conversation) async {
    setState(() {
      _selected = conversation;
      _messages = const [];
      _messageError = null;
    });
    await _loadMessages(conversation);
  }

  Future<void> _loadMessages(
      SupportConversation conversation, {
        bool silent = false,
      }) async {
    if (!silent && mounted) {
      setState(() {
        _loadingMessages = true;
        _messageError = null;
      });
    }

    try {
      final messages =
      await StaffService.instance.listSupportMessages(conversation.id);
      await StaffService.instance.markSupportRead(conversation.id);
      if (!mounted || _selected?.id != conversation.id) return;
      final oldLength = _messages.length;
      setState(() {
        _messages = messages;
        _loadingMessages = false;
        _messageError = null;
      });
      if (oldLength != messages.length || !silent) {
        _scrollAfterBuild();
      }
    } catch (error) {
      if (!mounted || _selected?.id != conversation.id) return;
      setState(() {
        _loadingMessages = false;
        _messageError = cleanError(error);
      });
    }
  }

  Future<void> _sendMessage() async {
    final conversation = _selected;
    final text = _messageController.text.trim();
    if (conversation == null || _sending || !conversation.canReply) return;
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final sent = await StaffService.instance.sendSupportMessage(
        conversationId: conversation.id,
        message: text,
      );
      _messageController.clear();
      if (!mounted) return;
      setState(() => _messages = [..._messages, sent]);
      _scrollAfterBuild();
      await _refreshConversations(silent: true);
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    final conversation = _selected;
    if (conversation == null || _updatingStatus) return;
    setState(() => _updatingStatus = true);
    try {
      await StaffService.instance.updateSupportStatus(
        conversationId: conversation.id,
        status: status,
      );
      await _refreshConversations(silent: true);
      _showMessage('Support status updated.');
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _markRepaired() async {
    final conversation = _selected;
    if (conversation == null || !conversation.hasLinkedFault) return;

    final key = GlobalKey<FormState>();
    String repairNotes = '';
    final notes = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Mark Linked PC Issue as Repaired',
              style: TextStyle(color: _textColor, fontSize: 17)),
          content: Form(
            key: key,
            child: TextFormField(
              minLines: 3,
              maxLines: 6,
              style: TextStyle(color: _textColor),
              cursorColor: _accentA,
              decoration: _fieldDecoration('Repair action / technician notes'),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Enter the repair action or notes.'
                  : null,
              onChanged: (value) => repairNotes = value,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(foregroundColor: _subTextColor),
              child: const Text('Cancel'),
            ),
            _GradientButton(
              label: 'Confirm Repair',
              gradient: _accentGradient,
              onPressed: () {
                if (key.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, repairNotes.trim());
                }
              },
            ),
          ],
        );
      },
    );
    if (notes == null || notes.isEmpty || conversation.faultReportId == null) {
      return;
    }

    try {
      await StaffService.instance.markRepaired(
        reportId: conversation.faultReportId!,
        notes: notes,
      );
      await _refreshConversations(silent: true);
      _showMessage('PC issue repaired. The linked request is resolved.');
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    }
  }

  List<SupportConversation> get _filteredConversations {
    final search = _searchController.text.trim().toLowerCase();
    return _conversations.where((item) {
      final statusMatches = switch (_statusFilter) {
        'active' => _activeStatuses.contains(item.status) && !item.repaired,
        'resolved' => item.repaired ||
            item.status == 'resolved' ||
            item.status == 'closed',
        _ => true,
      };
      if (!statusMatches) return false;
      if (search.isEmpty) return true;
      return [
        item.roomName,
        item.pcId,
        item.studentName,
        item.studentId,
        item.studentEmail,
        item.category,
        item.subject,
        item.issue,
        item.details,
        item.lastMessage ?? '',
      ].join(' ').toLowerCase().contains(search);
    }).toList()
      ..sort((a, b) {
        if (a.unreadCount != b.unreadCount) {
          return b.unreadCount.compareTo(a.unreadCount);
        }
        final aTime = a.lastMessageAt ?? a.updatedAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.updatedAt ?? b.createdAt;
        return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          aTime ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      });
  }

  // ── Input decoration (matches StaffLoginScreen) ─────────────────────────
  InputDecoration _fieldDecoration(String label,
      {IconData? icon, Widget? suffixIcon, String? hintText, bool dense = false}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      isDense: dense,
      labelStyle: TextStyle(color: _subTextColor, fontSize: 14),
      hintStyle: TextStyle(color: _subTextColor.withValues(alpha: 0.5), fontSize: 13),
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: _subTextColor.withValues(alpha: 0.45), size: 20),
      suffixIcon: suffixIcon,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _errorColor, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _errorColor, width: 1.5),
      ),
      errorStyle: TextStyle(color: _errorColor, fontSize: 12),
      contentPadding: EdgeInsets.symmetric(
          horizontal: 16, vertical: dense ? 12 : 18),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bgColor,
      child: Row(
        children: [
          SizedBox(
            width: 410,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        style: TextStyle(color: _textColor, fontSize: 14),
                        cursorColor: _accentA,
                        decoration: _fieldDecoration(
                          'Search support requests',
                          icon: Icons.search,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _buildStatusFilter(),
                    ],
                  ),
                ),
                Expanded(child: _buildConversationList()),
              ],
            ),
          ),
          Container(width: 1, color: _borderColor),
          Expanded(
            child: ColoredBox(
              color: _bgColor,
              child: _buildConversationDetail(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    const options = [
      ('active', 'Active'),
      ('resolved', 'Resolved'),
      ('all', 'All'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _statusFilter = option.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: _statusFilter == option.$1 ? _accentGradient : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    option.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _statusFilter == option.$1
                          ? const Color(0xFF080A0E)
                          : _subTextColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    if (_loadingList) {
      return Center(
        child: CircularProgressIndicator(color: _accentA, strokeWidth: 2.5),
      );
    }
    if (_listError != null) {
      return MessageState(
        icon: Icons.wifi_off,
        title: 'Could not load support requests',
        message: _listError!,
        onRetry: _refreshConversations,
      );
    }

    final items = _filteredConversations;
    if (items.isEmpty) {
      return const MessageState(
        icon: Icons.support_agent,
        title: 'No support conversations',
        message: 'Students can create a support request after logging in.',
      );
    }

    return RefreshIndicator(
      color: _accentA,
      backgroundColor: _cardColor,
      onRefresh: _refreshConversations,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = _selected?.id == item.id;
          return GestureDetector(
            onTap: () => _selectConversation(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? _accentA.withValues(alpha: _isDarkMode ? 0.1 : 0.08)
                    : _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? _accentA.withValues(alpha: 0.5)
                      : _borderColor,
                  width: selected ? 1.3 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryBadge(
                    icon: _categoryIcon(item.category),
                    accentA: _accentA,
                    accentB: _accentB,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item.roomName} - ${item.pcId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _subTextColor, fontSize: 12.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.studentName.isEmpty
                              ? item.studentEmail
                              : item.studentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _subTextColor, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  item.unreadCount > 0
                      ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: _accentGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${item.unreadCount}',
                      style: const TextStyle(
                        color: Color(0xFF080A0E),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                      : Icon(Icons.chevron_right,
                      color: _subTextColor.withValues(alpha: 0.5), size: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConversationDetail() {
    final conversation = _selected;
    if (conversation == null) {
      return const MessageState(
        icon: Icons.forum_outlined,
        title: 'Select a support request',
        message: 'Open a conversation to reply and update its status.',
      );
    }

    return Column(
      children: [
        _buildRequestHeader(conversation),
        if (_messageError != null) _buildErrorBanner(),
        Expanded(
          child: _loadingMessages
              ? Center(
            child: CircularProgressIndicator(
                color: _accentA, strokeWidth: 2.5),
          )
              : _messages.isEmpty
              ? Center(
            child: Text('No messages yet.',
                style: TextStyle(color: _subTextColor)),
          )
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(18),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              return _AdminMessageBubble(
                message: _messages[index],
                accentA: _accentA,
                accentB: _accentB,
                fieldColor: _fieldColor,
                textColor: _textColor,
                subTextColor: _subTextColor,
              );
            },
          ),
        ),
        _buildComposer(conversation),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _errorColor.withValues(alpha: _isDarkMode ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _errorColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: _errorColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_messageError!,
                style: TextStyle(color: _textColor, fontSize: 13.5)),
          ),
          GestureDetector(
            onTap: () => setState(() => _messageError = null),
            child: Text('Dismiss',
                style: TextStyle(
                    color: _accentB, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestHeader(SupportConversation conversation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CategoryBadge(
                icon: _categoryIcon(conversation.category),
                accentA: _accentA,
                accentB: _accentB,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.subject,
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_categoryLabel(conversation.category)} • '
                          '${conversation.roomName} - ${conversation.pcId}',
                      style: TextStyle(color: _subTextColor, fontSize: 13),
                    ),
                    Text(
                      '${conversation.studentName} '
                          '${conversation.studentId.isEmpty ? '' : '(${conversation.studentId})'}',
                      style: TextStyle(color: _subTextColor, fontSize: 13),
                    ),
                    if (conversation.hasLinkedFault)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Linked PC issue: ${conversation.issue} '
                              '(${conversation.severity.toUpperCase()})',
                          style: TextStyle(
                            color: _errorColor.withValues(alpha: 0.9),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: _statusOptions.contains(conversation.status)
                      ? conversation.status
                      : 'open',
                  dropdownColor: _cardColor,
                  style: TextStyle(color: _textColor, fontSize: 13.5),
                  icon: Icon(Icons.expand_more, color: _subTextColor, size: 18),
                  decoration:
                  _fieldDecoration('Support status', dense: true),
                  items: [
                    for (final value in _statusOptions)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_statusLabel(value)),
                      ),
                  ],
                  onChanged: _updatingStatus || conversation.repaired
                      ? null
                      : (value) {
                    if (value != null) _updateStatus(value);
                  },
                ),
              ),
              if (conversation.hasLinkedFault) ...[
                const SizedBox(width: 10),
                _GradientButton(
                  label: conversation.repaired ? 'Repaired' : 'Mark Repaired',
                  icon: Icons.build,
                  gradient: conversation.repaired
                      ? null
                      : _accentGradient,
                  solidColor:
                  conversation.repaired ? _fieldColor : null,
                  textColor: conversation.repaired
                      ? _subTextColor
                      : const Color(0xFF080A0E),
                  onPressed: conversation.repaired ? null : _markRepaired,
                ),
              ],
            ],
          ),
          if (conversation.details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _fieldColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                conversation.details,
                style: TextStyle(color: _textColor.withValues(alpha: 0.85), fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComposer(SupportConversation conversation) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: _cardColor,
          border: Border(top: BorderSide(color: _borderColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: conversation.canReply && !_sending,
                minLines: 1,
                maxLines: 5,
                maxLength: 4000,
                style: TextStyle(color: _textColor, fontSize: 14.5),
                cursorColor: _accentA,
                decoration: _fieldDecoration(
                  '',
                  hintText: conversation.canReply
                      ? 'Reply to the student...'
                      : 'This request is resolved or closed.',
                ).copyWith(counterText: '', labelText: null),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            _SendButton(
              enabled: conversation.canReply && !_sending,
              sending: _sending,
              gradient: _accentGradient,
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  void _scrollAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final color = isError ? _errorColor : _accentA;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _cardColor,
        behavior: SnackBarBehavior.floating,
        width: 400,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


const _statusOptions = [
  'open',
  'acknowledged',
  'in_progress',
  'waiting_for_student',
  'waiting_for_repair',
  'resolved',
  'closed',
];

String _statusLabel(String value) {
  return value
      .split('_')
      .map((word) => word.isEmpty
      ? ''
      : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _categoryLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'hardware':
      return 'Hardware';
    case 'peripheral':
      return 'Peripheral';
    case 'network':
      return 'Network';
    case 'software':
      return 'Software';
    case 'account':
      return 'Account or Login';
    case 'other':
      return 'Other';
    default:
      return 'General Assistance';
  }
}

IconData _categoryIcon(String value) {
  switch (value.trim().toLowerCase()) {
    case 'hardware':
      return Icons.memory;
    case 'peripheral':
      return Icons.keyboard;
    case 'network':
      return Icons.lan;
    case 'software':
      return Icons.apps;
    case 'account':
      return Icons.manage_accounts;
    case 'other':
      return Icons.help_outline;
    default:
      return Icons.support_agent;
  }
}

// ── Shared themed widgets ──────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final IconData icon;
  final Color accentA;
  final Color accentB;
  final double size;

  const _CategoryBadge({
    required this.icon,
    required this.accentA,
    required this.accentB,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [accentA.withValues(alpha: 0.15), accentB.withValues(alpha: 0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accentA.withValues(alpha: 0.35), width: 1.2),
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [accentA, accentB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Gradient? gradient;
  final Color? solidColor;
  final Color textColor;
  final VoidCallback? onPressed;

  const _GradientButton({
    required this.label,
    this.icon,
    this.gradient,
    this.solidColor,
    this.textColor = const Color(0xFF080A0E),
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: disabled ? null : gradient,
        color: disabled ? (solidColor ?? Colors.grey.withValues(alpha: 0.2)) : solidColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: textColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool sending;
  final Gradient gradient;
  final VoidCallback onPressed;

  const _SendButton({
    required this.enabled,
    required this.sending,
    required this.gradient,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: enabled ? gradient : null,
        color: enabled ? null : gradient.colors.first.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        boxShadow: enabled
            ? [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: Center(
            child: sending
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF080A0E)),
              ),
            )
                : const Icon(Icons.send_rounded, color: Color(0xFF080A0E), size: 20),
          ),
        ),
      ),
    );
  }
}

class _AdminMessageBubble extends StatelessWidget {
  final SupportChatMessage message;
  final Color accentA;
  final Color accentB;
  final Color fieldColor;
  final Color textColor;
  final Color subTextColor;

  const _AdminMessageBubble({
    required this.message,
    required this.accentA,
    required this.accentB,
    required this.fieldColor,
    required this.textColor,
    required this.subTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = message.isAdmin;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isMine
              ? LinearGradient(
            colors: [
              accentA.withValues(alpha: 0.18),
              accentB.withValues(alpha: 0.14),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isMine ? null : fieldColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMine ? accentA.withValues(alpha: 0.35) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMine ? 'You' : message.senderName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: isMine ? accentB : textColor,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              message.message,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeText(message.createdAt),
                  style: TextStyle(color: subTextColor, fontSize: 11),
                ),
                if (isMine) ...[
                  const SizedBox(width: 6),
                  Icon(
                    message.read ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.read ? accentA : subTextColor,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _timeText(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day} $hour:$minute';
  }
}
