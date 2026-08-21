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

  // ── Palette (matches the rest of the app) ───────────────────────────────
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
  Color get _okColor => const Color(0xFF22A06B);

  LinearGradient get _accentGradient => LinearGradient(
    colors: [_accentA, _accentB],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

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
      if (mounted) _showMessage(cleanError(error), isError: true);
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

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _topBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.arrow_back_rounded, color: _textColor),
          ),
          const SizedBox(width: 4),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_accentA.withValues(alpha: 0.15), _accentB.withValues(alpha: 0.12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: _accentA.withValues(alpha: 0.4), width: 1.2),
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [_accentA, _accentB],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 21),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chat with ITSO',
                style: TextStyle(color: _textColor, fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
              Text(
                'Laboratory ${widget.user.assignedRoomName ?? 'Unassigned'}',
                style: TextStyle(color: _subTextColor, fontSize: 11.5),
              ),
            ],
          ),
          const Spacer(),
          _iconTile(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh chat',
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
            color: _fieldColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: Icon(icon, color: _subTextColor, size: 19),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: _accentA, strokeWidth: 2.5),
      );
    }
    if (_error != null && _conversation == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: _errorColor),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: _textColor)),
            const SizedBox(height: 16),
            _gradientButton(label: 'Retry', icon: Icons.refresh_rounded, onPressed: () => _refresh()),
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
              style: TextStyle(color: _subTextColor),
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
    final color = closed ? Colors.blueGrey : _okColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDarkMode ? 0.12 : 0.08),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.25))),
      ),
      child: Row(
        children: [
          Icon(closed ? Icons.check_circle_outline : Icons.support_agent, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              closed
                  ? 'This request is ${conversation.status}. Sending a new message will reopen it.'
                  : 'ITSO support status: ${_statusLabel(conversation.status)}',
              style: TextStyle(color: _textColor, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(TeacherChatMessage message) {
    final mine = message.isTeacher;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: mine
              ? LinearGradient(
            colors: [
              _accentA.withValues(alpha: 0.18),
              _accentB.withValues(alpha: 0.14),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: mine ? null : _fieldColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: mine ? _accentA.withValues(alpha: 0.35) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mine ? 'Teacher' : 'ITSO · ${message.senderName}',
              style: TextStyle(
                color: mine ? _accentB : _textColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.message,
              style: TextStyle(color: _textColor, fontSize: 14, height: 1.3),
            ),
            const SizedBox(height: 5),
            Text(
              _time(message.createdAt),
              style: TextStyle(color: _subTextColor, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.all(14),
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
              enabled: !_sending,
              minLines: 1,
              maxLines: 4,
              maxLength: 4000,
              style: TextStyle(color: _textColor, fontSize: 14.5),
              cursorColor: _accentA,
              decoration: InputDecoration(
                hintText: 'Message ITSO about this laboratory...',
                hintStyle: TextStyle(color: _subTextColor.withValues(alpha: 0.6), fontSize: 13.5),
                counterText: '',
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
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 12),
          _SendButton(
            enabled: !_sending,
            sending: _sending,
            gradient: _accentGradient,
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    IconData? icon,
    required VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: disabled ? null : _accentGradient,
        color: disabled ? _accentA.withValues(alpha: 0.2) : null,
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
                  Icon(icon, size: 16, color: const Color(0xFF080A0E)),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF080A0E),
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) => status.replaceAll('_', ' ').toUpperCase();

  String _time(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _showMessage(String message, {bool isError = false}) {
    final accent = isError ? _errorColor : _accentA;
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
                  gradient: isError
                      ? null
                      : LinearGradient(colors: [_accentA, _accentB]),
                  color: isError ? _errorColor.withValues(alpha: 0.15) : null,
                ),
                child: Icon(
                  isError ? Icons.error_outline : Icons.check_rounded,
                  size: 17,
                  color: isError ? _errorColor : const Color(0xFF080A0E),
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
