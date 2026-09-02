import 'dart:async';

import 'package:flutter/material.dart';

import '../models/teacher_chat.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/message_state.dart';

class AdminTeacherChatScreen extends StatefulWidget {
  const AdminTeacherChatScreen({super.key});

  @override
  State<AdminTeacherChatScreen> createState() =>
      _AdminTeacherChatScreenState();
}

class _AdminTeacherChatScreenState extends State<AdminTeacherChatScreen> {
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  Timer? _timer;
  List<TeacherChatConversation> _conversations = const [];
  List<TeacherChatMessage> _messages = const [];
  TeacherChatConversation? _selected;
  String _statusFilter = 'active';
  bool _loadingList = true;
  bool _refreshingList = false;
  bool _loadingMessages = false;
  bool _sending = false;
  bool _updatingStatus = false;
  String? _listError;
  String? _messageError;

  // ── Palette (matches SupportChatScreen) ─────────────────────────────────────
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF13141A) : Colors.white;
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
  Color get _errorColor => const Color(0xFFFF6B6B);
  Color get _accentColor => _isDarkMode ? _accentA : _accentB;

  @override
  void initState() {
    super.initState();
    _refreshConversations();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
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
      final conversations = await StaffService.instance.listAdminTeacherChats();
      TeacherChatConversation? selected;
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
        _selected = selected ?? (conversations.isNotEmpty ? conversations.first : null);
        _loadingList = false;
        _listError = null;
      });

      if (_selected != null) {
        await _loadMessages(_selected!, silent: true);
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

  Future<void> _selectConversation(TeacherChatConversation conversation) async {
    setState(() {
      _selected = conversation;
      _messages = const [];
      _messageError = null;
    });
    await _loadMessages(conversation);
  }

  Future<void> _loadMessages(
      TeacherChatConversation conversation, {
        bool silent = false,
      }) async {
    if (!silent && mounted) {
      setState(() {
        _loadingMessages = true;
        _messageError = null;
      });
    }

    try {
      final messages = await StaffService.instance
          .listAdminTeacherChatMessages(conversation.id);
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
      if (mounted && !silent) {
        setState(() {
          _loadingMessages = false;
          _messageError = cleanError(error);
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final conversation = _selected;
    final text = _messageController.text.trim();
    if (conversation == null || _sending || conversation.isClosed) return;
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await StaffService.instance.sendAdminTeacherChatMessage(
        conversationId: conversation.id,
        message: text,
      );
      _messageController.clear();
      if (!mounted) return;
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
      await StaffService.instance.updateAdminTeacherChatStatus(
        conversationId: conversation.id,
        status: status,
      );
      await _refreshConversations(silent: true);
      _showMessage('Chat status updated.');
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  List<TeacherChatConversation> get _filteredConversations {
    final query = _searchController.text.trim().toLowerCase();
    return _conversations.where((item) {
      final statusMatches = switch (_statusFilter) {
        'active' => !item.isClosed,
        'resolved' => item.isClosed,
        _ => true,
      };
      if (!statusMatches) return false;
      if (query.isEmpty) return true;
      return [
        item.roomName,
        item.teacherName,
        item.teacherEmail,
        item.lastMessage ?? '',
      ].join(' ').toLowerCase().contains(query);
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
        borderSide: BorderSide(color: _accentAForeground, width: 1.5),
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
                        cursorColor: _accentAForeground,
                        decoration: _fieldDecoration(
                          'Search teacher chats',
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
            child: Container(
              margin: EdgeInsets.all(_isDarkMode ? 0 : 24),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.transparent : _cardColor,
                borderRadius: BorderRadius.circular(_isDarkMode ? 0 : 24),
                border: _isDarkMode ? null : Border.all(color: _borderColor),
                boxShadow: [
                  if (!_isDarkMode)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
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
                    color: _statusFilter == option.$1 ? _accentColor : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    option.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _statusFilter == option.$1
                          ? (_isDarkMode ? Colors.black : Colors.white)
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
        child: CircularProgressIndicator(color: _accentAForeground, strokeWidth: 2.5),
      );
    }
    if (_listError != null) {
      return MessageState(
        icon: Icons.wifi_off,
        title: 'Could not load teacher chats',
        message: _listError!,
        onRetry: _refreshConversations,
      );
    }

    final items = _filteredConversations;
    if (items.isEmpty) {
      return const MessageState(
        icon: Icons.forum_outlined,
        title: 'No teacher conversations',
        message: 'A chat appears when a teacher starts a conversation.',
      );
    }

    return RefreshIndicator(
      color: _accentAForeground,
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
                    ? _accentAForeground.withValues(alpha: _isDarkMode ? 0.1 : 0.08)
                    : _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? _accentAForeground.withValues(alpha: 0.5)
                      : _borderColor,
                  width: selected ? 1.3 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryBadge(
                    icon: Icons.school_rounded,
                    accentA: _accentA,
                    accentB: _accentB,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laboratory ${item.roomName}',
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
                          item.lastMessage ?? item.teacherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _subTextColor, fontSize: 12.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.teacherName,
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
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${item.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
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
        title: 'Select a conversation',
        message: 'Open a chat to reply and update its status.',
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
                color: _accentAForeground, strokeWidth: 2.5),
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
                accentAForeground: _accentAForeground,
                accentBForeground: _accentBForeground,
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
                    color: _accentBForeground, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestHeader(TeacherChatConversation conversation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CategoryBadge(
            icon: Icons.meeting_room_rounded,
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
                  'Laboratory ${conversation.roomName}',
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${conversation.teacherName} · ${conversation.teacherEmail}',
                  style: TextStyle(color: _subTextColor, fontSize: 13),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              value: conversation.status,
              dropdownColor: _cardColor,
              style: TextStyle(color: _textColor, fontSize: 13.5),
              icon: Icon(Icons.expand_more, color: _subTextColor, size: 18),
              decoration: _fieldDecoration('Status', dense: true),
              items: const [
                DropdownMenuItem(value: 'open', child: Text('Open')),
                DropdownMenuItem(value: 'acknowledged', child: Text('Acknowledged')),
                DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'closed', child: Text('Closed')),
              ],
              onChanged: _updatingStatus
                  ? null
                  : (value) {
                if (value != null) _updateStatus(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(TeacherChatConversation conversation) {
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
                enabled: !conversation.isClosed && !_sending,
                minLines: 1,
                maxLines: 5,
                maxLength: 4000,
                style: TextStyle(color: _textColor, fontSize: 14.5),
                cursorColor: _accentAForeground,
                decoration: _fieldDecoration(
                  '',
                  hintText: conversation.isClosed
                      ? 'Reopen this conversation before replying.'
                      : 'Reply to the teacher...',
                ).copyWith(counterText: '', labelText: null),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            _SendButton(
              enabled: !conversation.isClosed && !_sending,
              sending: _sending,
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
    final accent = isError ? _errorColor : _accentAForeground;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isError ? _errorColor.withValues(alpha: 0.15) : _accentColor,
                ),
                child: Icon(
                  isError ? Icons.error_outline : Icons.check_rounded,
                  size: 17,
                  color: isError ? _errorColor : (_isDarkMode ? Colors.black : Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: _cardColor,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          duration: Duration(seconds: isError ? 4 : 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: accent.withValues(alpha: 0.35)),
          ),
        ),
      );
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDarkMode ? accentA : accentB;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDarkMode ? accentA.withValues(alpha: 0.12) : accentB.withValues(alpha: 0.08),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Icon(
        icon,
        color: accentColor,
        size: size * 0.5,
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool sending;
  final VoidCallback onPressed;

  const _SendButton({
    required this.enabled,
    required this.sending,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = enabled 
        ? (isDarkMode ? const Color(0xFFFFD700) : const Color(0xFF003366))
        : (isDarkMode ? const Color(0xFFFFD700) : const Color(0xFF003366)).withValues(alpha: 0.2);
    final iconColor = enabled
        ? (isDarkMode ? Colors.black : Colors.white)
        : Colors.white;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: enabled
            ? [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
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
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            )
                : Icon(Icons.send_rounded, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}

class _AdminMessageBubble extends StatelessWidget {
  final TeacherChatMessage message;
  final Color accentA;
  final Color accentB;
  final Color accentAForeground;
  final Color accentBForeground;
  final Color fieldColor;
  final Color textColor;
  final Color subTextColor;

  const _AdminMessageBubble({
    required this.message,
    required this.accentA,
    required this.accentB,
    required this.accentAForeground,
    required this.accentBForeground,
    required this.fieldColor,
    required this.textColor,
    required this.subTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = message.isAdmin;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final bubbleColor = isMine 
        ? (isDarkMode ? accentA : accentB) 
        : fieldColor;
        
    final bubbleTextColor = isMine 
        ? (isDarkMode ? Colors.black : Colors.white) 
        : textColor;
        
    final bubbleSubTextColor = isMine 
        ? (isDarkMode ? Colors.black.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.7)) 
        : subTextColor;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMine ? 20 : 6),
            bottomRight: Radius.circular(isMine ? 6 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.15 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMine ? 'You' : 'Teacher',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: isMine 
                    ? (isDarkMode ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9)) 
                    : accentAForeground,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              message.message,
              style: TextStyle(
                color: bubbleTextColor,
                fontSize: 14.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeText(message.createdAt),
                  style: TextStyle(color: bubbleSubTextColor, fontSize: 10.5),
                ),
                if (isMine) ...[
                  const SizedBox(width: 6),
                  Icon(
                    message.read ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isDarkMode ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.6),
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
