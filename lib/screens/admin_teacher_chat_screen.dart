import 'dart:async';

import 'package:flutter/material.dart';

import '../models/teacher_chat.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';

class AdminTeacherChatScreen extends StatefulWidget {
  const AdminTeacherChatScreen({super.key});

  @override
  State<AdminTeacherChatScreen> createState() =>
      _AdminTeacherChatScreenState();
}

class _AdminTeacherChatScreenState extends State<AdminTeacherChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _timer;
  List<TeacherChatConversation> _conversations = const [];
  List<TeacherChatMessage> _messages = const [];
  TeacherChatConversation? _selected;
  String? _error;
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingMessages = false;
  bool _sending = false;
  bool _updatingStatus = false;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _card => _dark ? const Color(0xFF13141A) : Colors.white;
  Color get _field =>
      _dark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _text => _dark ? Colors.white : const Color(0xFF1A1C1E);
  Color get _sub => _dark ? Colors.white54 : Colors.black54;
  Color get _border =>
      _dark ? Colors.white.withValues(alpha: 0.08) : Colors.black12;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final conversations = await StaffService.instance.listAdminTeacherChats();
      if (!mounted) return;
      TeacherChatConversation? selected;
      final selectedId = _selected?.id;
      if (selectedId != null) {
        for (final conversation in conversations) {
          if (conversation.id == selectedId) {
            selected = conversation;
            break;
          }
        }
      }
      selected ??= conversations.isEmpty ? null : conversations.first;
      setState(() {
        _conversations = conversations;
        _selected = selected;
        _error = null;
        _loading = false;
        if (selected == null) _messages = const [];
      });
      if (selected != null) await _loadMessages(selected, silent: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = cleanError(error);
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _select(TeacherChatConversation conversation) async {
    setState(() {
      _selected = conversation;
      _messages = const [];
    });
    await _loadMessages(conversation);
  }

  Future<void> _loadMessages(
    TeacherChatConversation conversation, {
    bool silent = false,
  }) async {
    if (_loadingMessages) return;
    _loadingMessages = true;
    if (!silent && mounted) setState(() {});
    try {
      final messages = await StaffService.instance
          .listAdminTeacherChatMessages(conversation.id);
      if (!mounted || _selected?.id != conversation.id) return;
      setState(() => _messages = messages);
      _scrollToBottom();
    } catch (error) {
      if (mounted && !silent) _showMessage(cleanError(error));
    } finally {
      _loadingMessages = false;
      if (mounted && !silent) setState(() {});
    }
  }

  Future<void> _send() async {
    final selected = _selected;
    final message = _messageController.text.trim();
    if (selected == null || selected.isClosed || message.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await StaffService.instance.sendAdminTeacherChatMessage(
        conversationId: selected.id,
        message: message,
      );
      if (!mounted) return;
      _messageController.clear();
      await _refresh(silent: true);
    } catch (error) {
      if (mounted) _showMessage(cleanError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    final selected = _selected;
    if (selected == null || _updatingStatus || selected.status == status) return;
    setState(() => _updatingStatus = true);
    try {
      await StaffService.instance.updateAdminTeacherChatStatus(
        conversationId: selected.id,
        status: status,
      );
      await _refresh(silent: true);
      if (mounted) _showMessage('Teacher chat status updated.');
    } catch (error) {
      if (mounted) _showMessage(cleanError(error));
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _conversations.isEmpty) {
      return _stateMessage(
        Icons.cloud_off_rounded,
        'Could not load Teacher chat',
        _error!,
        retry: true,
      );
    }
    if (_conversations.isEmpty) {
      return _stateMessage(
        Icons.forum_outlined,
        'No Teacher conversations yet',
        'A room conversation appears after a Teacher opens Chat with ITSO.',
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          SizedBox(width: 330, child: _conversationList()),
          const SizedBox(width: 14),
          Expanded(child: _chatPanel()),
        ],
      ),
    );
  }

  Widget _conversationList() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'LABORATORY TEACHERS',
                    style: TextStyle(
                      color: _sub,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => _refresh(),
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _border),
          Expanded(
            child: ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final conversation = _conversations[index];
                final selected = conversation.id == _selected?.id;
                return InkWell(
                  onTap: () => _select(conversation),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    color: selected
                        ? const Color(0xFF2EE6C5).withValues(alpha: 0.10)
                        : null,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              const Color(0xFF4F8EF7).withValues(alpha: 0.15),
                          child: const Icon(Icons.school_rounded),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Room ${conversation.roomName}',
                                style: TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                conversation.lastMessage ?? conversation.teacherName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: _sub, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        if (conversation.unreadCount > 0)
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: const Color(0xFFE53935),
                            child: Text(
                              '${conversation.unreadCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatPanel() {
    final conversation = _selected;
    if (conversation == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          _chatHeader(conversation),
          Divider(height: 1, color: _border),
          Expanded(
            child: _loadingMessages && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet.',
                          style: TextStyle(color: _sub),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(18),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) =>
                            _messageBubble(_messages[index]),
                      ),
          ),
          _composer(conversation),
        ],
      ),
    );
  }

  Widget _chatHeader(TeacherChatConversation conversation) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.meeting_room_rounded, color: Color(0xFF4F8EF7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laboratory ${conversation.roomName}',
                  style: TextStyle(color: _text, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${conversation.teacherName} · ${conversation.teacherEmail}',
                  style: TextStyle(color: _sub, fontSize: 11.5),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              value: conversation.status,
              decoration: const InputDecoration(
                labelText: 'Status',
                isDense: true,
                border: OutlineInputBorder(),
              ),
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
                      if (value != null) _changeStatus(value);
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(TeacherChatMessage message) {
    final mine = message.isAdmin;
    final color = mine ? const Color(0xFF2EE6C5) : const Color(0xFF4F8EF7);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: mine ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mine ? 'ITSO · ${message.senderName}' : 'Teacher',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(message.message, style: TextStyle(color: _text, height: 1.3)),
            const SizedBox(height: 4),
            Text(_time(message.createdAt), style: TextStyle(color: _sub, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _composer(TeacherChatConversation conversation) {
    final closed = conversation.isClosed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: _border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !closed && !_sending,
              minLines: 1,
              maxLines: 4,
              maxLength: 4000,
              decoration: InputDecoration(
                hintText: closed
                    ? 'Reopen this conversation before replying.'
                    : 'Reply to the Teacher...',
                counterText: '',
                filled: true,
                fillColor: _field,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: closed || _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Widget _stateMessage(
    IconData icon,
    String title,
    String message, {
    bool retry = false,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: _sub),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: _sub)),
          if (retry) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
