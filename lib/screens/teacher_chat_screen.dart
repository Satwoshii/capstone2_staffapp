import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/teacher_chat.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';

class TeacherChatScreen extends StatefulWidget {
  final AppUser user;

  const TeacherChatScreen({super.key, required this.user});

  @override
  State<TeacherChatScreen> createState() => _TeacherChatScreenState();
}

class _TeacherChatScreenState extends State<TeacherChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _timer;
  TeacherChatConversation? _conversation;
  List<TeacherChatMessage> _messages = const [];
  String? _error;
  bool _loading = true;
  bool _refreshing = false;
  bool _sending = false;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _background =>
      _dark ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
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
      final data = await StaffService.instance.teacherChatOverview();
      if (!mounted) return;
      setState(() {
        _conversation = data.$1;
        _messages = data.$2;
        _error = null;
        _loading = false;
      });
      _scrollToBottom();
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

  Future<void> _send() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await StaffService.instance.sendTeacherChatMessage(message);
      if (!mounted) return;
      _messageController.clear();
      await _refresh(silent: true);
    } catch (error) {
      if (mounted) _showMessage(cleanError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
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
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _card,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat with ITSO', style: TextStyle(fontSize: 17)),
            Text(
              'Laboratory ${widget.user.assignedRoomName ?? 'Unassigned'}',
              style: TextStyle(color: _sub, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh chat',
            onPressed: () => _refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _conversation == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 52),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final conversation = _conversation;
    if (conversation == null) return const SizedBox.shrink();
    return Column(
      children: [
        _statusBanner(conversation),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    'Send a message to contact ITSO for this laboratory.',
                    style: TextStyle(color: _sub),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _messageBubble(_messages[index]),
                ),
        ),
        _composer(),
      ],
    );
  }

  Widget _statusBanner(TeacherChatConversation conversation) {
    final closed = conversation.isClosed;
    final color = closed ? Colors.blueGrey : const Color(0xFF22A06B);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(closed ? Icons.check_circle_outline : Icons.support_agent, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              closed
                  ? 'This request is ${conversation.status}. Sending a new message will reopen it.'
                  : 'ITSO support status: ${_statusLabel(conversation.status)}',
              style: TextStyle(color: _text, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(TeacherChatMessage message) {
    final mine = message.isTeacher;
    final color = mine ? const Color(0xFF4F8EF7) : const Color(0xFF2EE6C5);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? color.withValues(alpha: 0.18) : _card,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mine ? 'Teacher' : 'ITSO · ${message.senderName}',
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

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_sending,
              minLines: 1,
              maxLines: 4,
              maxLength: 4000,
              decoration: InputDecoration(
                hintText: 'Message ITSO about this laboratory...',
                counterText: '',
                filled: true,
                fillColor: _field,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
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

  String _statusLabel(String status) =>
      status.replaceAll('_', ' ').toUpperCase();

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
