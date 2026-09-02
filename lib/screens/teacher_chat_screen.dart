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
  Color get _accentA => const Color(0xFFFFD700);
  Color get _accentB => const Color(0xFF003366);
  Color get _accentColor => _dark ? _accentA : _accentB;
  Color get _accentAForeground => _dark ? _accentA : _accentB;
  Color get _errorColor => const Color(0xFFFF6B6B);
  Color get _online => const Color(0xFF22A06B);

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

  // ============================================================
  // BACKEND / LOGIC — UNCHANGED
  // ============================================================

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

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          _ambientBackground(),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(child: _body()),
                _composer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ambientBackground() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -180,
            right: -140,
            child: Container(
              width: 480,
              height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentB.withValues(alpha: _dark ? 0.14 : 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -180,
            bottom: -200,
            child: Container(
              width: 560,
              height: 560,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentA.withValues(alpha: _dark ? 0.10 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    final room = widget.user.assignedRoomName ?? 'Unassigned';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: _dark ? 0.96 : 0.98),
        border: Border(bottom: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _dark ? 0.16 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _iconTile(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back to dashboard',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 13),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _accentColor.withValues(alpha: 0.14),
                  border: Border.all(
                    color: _accentColor.withValues(alpha: 0.38),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: _accentAForeground,
                  size: 23,
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: _online,
                    shape: BoxShape.circle,
                    border: Border.all(color: _card, width: 2.2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ITSO Support',
                  style: TextStyle(
                    color: _text,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Laboratory $room · Support Conversation',
                  style: TextStyle(color: _sub, fontSize: 11.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _iconTile(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh conversation',
            onPressed: () => _refresh(),
          ),
        ],
      ),
    );
  }

  Widget _iconTile({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _field,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: Icon(icon, color: _sub, size: 19),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return _loadingState();
    }

    if (_error != null && _conversation == null) {
      return _errorState();
    }

    final conversation = _conversation;

    if (conversation == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _statusBanner(conversation),

        Expanded(
          child: _messages.isEmpty
              ? _emptyState()
              : _chatMessages(),
        ),
      ],
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _loadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading conversation...',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 34,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Unable to load chat',
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _sub,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => _refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: _dark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS BANNER
  // ============================================================

  Widget _statusBanner(TeacherChatConversation conversation) {
    final closed = conversation.isClosed;
    final color = closed
        ? const Color(0xFF64748B)
        : const Color(0xFF22A06B);

    final statusText = closed
        ? 'This support request is ${conversation.status}. Sending a message will reopen it.'
        : 'ITSO support is currently ${_statusLabel(conversation.status)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                closed
                    ? Icons.check_circle_outline_rounded
                    : Icons.support_agent_rounded,
                color: color,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  color: _text,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.forum_outlined,
                  color: _accentAForeground,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Start a conversation',
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Send a message to ITSO if you need assistance with this laboratory.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _sub,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CHAT MESSAGES
  // ============================================================

  Widget _chatMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _messageBubble(_messages[index]);
      },
    );
  }

  Widget _messageBubble(TeacherChatMessage message) {
    final mine = message.isTeacher;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment:
        mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 680,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) ...[
                _avatar(
                  icon: Icons.support_agent_rounded,
                  color: _accentColor,
                ),
                const SizedBox(width: 10),
              ],

              Flexible(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    15,
                    12,
                    15,
                    10,
                  ),
                  decoration: BoxDecoration(
                    color: mine
                        ? _accentColor
                        : _card,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(
                        mine ? 20 : 6,
                      ),
                      bottomRight: Radius.circular(
                        mine ? 6 : 20,
                      ),
                    ),
                    border: mine
                        ? null
                        : Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: _dark ? 0.14 : 0.04,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        mine
                            ? 'You'
                            : 'ITSO · ${message.senderName}',
                        style: TextStyle(
                          color: mine
                              ? (_dark ? Colors.black : Colors.white).withValues(alpha: 0.85)
                              : _accentAForeground,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        message.message,
                        style: TextStyle(
                          color: mine
                              ? (_dark ? Colors.black : Colors.white)
                              : _text,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _time(message.createdAt),
                          style: TextStyle(
                            color: mine
                                ? (_dark ? Colors.black54 : Colors.white70)
                                : _sub,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (mine) ...[
                const SizedBox(width: 10),
                _avatar(
                  icon: Icons.person_rounded,
                  color: _accentColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.20),
        ),
      ),
      child: Icon(
        icon,
        size: 19,
        color: color,
      ),
    );
  }

  // ============================================================
  // MESSAGE COMPOSER
  // ============================================================

  Widget _composer() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        border: Border(
          top: BorderSide(color: _border),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _field,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _border,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  enabled: !_sending,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  style: TextStyle(
                    color: _text,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText:
                    'Write a message to ITSO...',
                    hintStyle: TextStyle(
                      color: _sub,
                    ),
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding:
                    const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),

            const SizedBox(width: 12),

            SizedBox(
              width: 52,
              height: 52,
              child: FilledButton(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: _accentColor,
                  foregroundColor: _dark ? Colors.black : Colors.white,
                  disabledBackgroundColor:
                  _accentColor.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _sending
                    ? SizedBox(
                  width: 21,
                  height: 21,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _dark ? Colors.black : Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.send_rounded,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EXISTING HELPERS — UNCHANGED
  // ============================================================

  String _statusLabel(String status) =>
      status.replaceAll('_', ' ').toUpperCase();

  String _time(DateTime value) {
    final local = value.toLocal();
    final hour =
    local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute =
    local.minute.toString().padLeft(2, '0');

    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}