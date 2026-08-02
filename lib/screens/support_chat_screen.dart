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
    if (conversation == null || _sending || text.isEmpty) return;
    if (!conversation.canReply) {
      _showMessage('This issue is resolved. The conversation is read-only.');
      return;
    }

    setState(() => _sending = true);
    try {
      await StaffService.instance.sendSupportMessage(
        conversationId: conversation.id,
        message: text,
      );
      _messageController.clear();
      await _loadMessages(conversation, silent: true);
      await _refreshConversations(silent: true);
    } catch (error) {
      _showMessage(cleanError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _updateStatus(String value) async {
    final conversation = _selected;
    if (conversation == null || _updatingStatus) return;

    setState(() => _updatingStatus = true);
    try {
      await StaffService.instance.updateSupportStatus(
        conversationId: conversation.id,
        status: value,
      );
      await _refreshConversations(silent: true);
      _showMessage('Support status updated.');
    } catch (error) {
      _showMessage(cleanError(error));
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _markRepaired() async {
    final conversation = _selected;
    if (conversation == null || conversation.repaired) return;

    final controller = TextEditingController();
    final key = GlobalKey<FormState>();
    final notes = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mark Issue Repaired'),
          content: Form(
            key: key,
            child: SizedBox(
              width: 480,
              child: TextFormField(
                controller: controller,
                minLines: 3,
                maxLines: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Repair action / technician notes',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the repair action or notes.'
                    : null,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (key.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              child: const Text('Confirm Repair'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (notes == null || notes.isEmpty) return;

    try {
      await StaffService.instance.markRepaired(
        reportId: conversation.faultReportId,
        notes: notes,
      );
      await _refreshConversations(silent: true);
      _showMessage('Issue marked as repaired. The chat is now read-only.');
    } catch (error) {
      _showMessage(cleanError(error));
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 390,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search support requests',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'active', label: Text('Active')),
                        ButtonSegment(value: 'resolved', label: Text('Resolved')),
                        ButtonSegment(value: 'all', label: Text('All')),
                      ],
                      selected: {_statusFilter},
                      onSelectionChanged: (value) {
                        setState(() => _statusFilter = value.first);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildConversationList()),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _buildConversationDetail()),
      ],
    );
  }

  Widget _buildConversationList() {
    if (_loadingList) {
      return const Center(child: CircularProgressIndicator());
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
        message: 'Chats appear only after a Student PC reports an issue.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshConversations,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = _selected?.id == item.id;
          return Card(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: ListTile(
              selected: selected,
              onTap: () => _selectConversation(item),
              leading: CircleAvatar(
                backgroundColor: _severityColor(item.severity).withOpacity(.14),
                child: Icon(
                  Icons.report_problem,
                  color: _severityColor(item.severity),
                ),
              ),
              title: Text('${item.roomName} - ${item.pcId}'),
              subtitle: Text(
                '${item.issue}\n'
                '${item.studentName.isEmpty ? item.studentEmail : item.studentName}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              trailing: item.unreadCount > 0
                  ? Badge(label: Text('${item.unreadCount}'))
                  : const Icon(Icons.chevron_right),
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
        message: 'Open a conversation to reply and manage its issue.',
      );
    }

    return Column(
      children: [
        _buildIssueHeader(conversation),
        if (_messageError != null)
          MaterialBanner(
            content: Text(_messageError!),
            actions: [
              TextButton(
                onPressed: () => setState(() => _messageError = null),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        Expanded(
          child: _loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text('No messages yet.'))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(18),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _AdminMessageBubble(message: _messages[index]);
                      },
                    ),
        ),
        _buildComposer(conversation),
      ],
    );
  }

  Widget _buildIssueHeader(SupportConversation conversation) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.report_problem,
                  color: _severityColor(conversation.severity),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${conversation.roomName} - ${conversation.pcId}: '
                        '${conversation.issue}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${conversation.studentName} '
                        '${conversation.studentId.isEmpty ? '' : '(${conversation.studentId})'}',
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: conversation.canReply
                      ? DropdownButtonFormField<String>(
                          value: _statusOptions.contains(conversation.status)
                              ? conversation.status
                              : 'open',
                          decoration: const InputDecoration(
                            labelText: 'Support status',
                            isDense: true,
                          ),
                          items: [
                            for (final value in _statusOptions)
                              DropdownMenuItem(
                                value: value,
                                child: Text(_statusLabel(value)),
                              ),
                          ],
                          onChanged: _updatingStatus
                              ? null
                              : (value) {
                                  if (value != null) _updateStatus(value);
                                },
                        )
                      : InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Support status',
                            isDense: true,
                          ),
                          child: Text(
                            conversation.repaired
                                ? 'Resolved'
                                : _statusLabel(conversation.status),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: conversation.repaired ? null : _markRepaired,
                  icon: const Icon(Icons.build),
                  label: Text(conversation.repaired ? 'Repaired' : 'Mark Repaired'),
                ),
              ],
            ),
            if (conversation.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(conversation.details),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(SupportConversation conversation) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                decoration: InputDecoration(
                  hintText: conversation.canReply
                      ? 'Reply to the student...'
                      : 'This issue is resolved. The chat is read-only.',
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              tooltip: 'Send reply',
              onPressed: conversation.canReply && !_sending
                  ? _sendMessage
                  : null,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

const _statusOptions = [
  'open',
  'acknowledged',
  'in_progress',
  'waiting_for_student',
  'waiting_for_repair',
];

String _statusLabel(String value) {
  return value
      .split('_')
      .map((word) => word.isEmpty
          ? ''
          : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

Color _severityColor(String value) {
  switch (value.trim().toLowerCase()) {
    case 'critical':
    case 'high':
      return Colors.red;
    case 'minor':
    case 'low':
      return Colors.amber.shade800;
    default:
      return Colors.orange;
  }
}

class _AdminMessageBubble extends StatelessWidget {
  final SupportChatMessage message;

  const _AdminMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.isAdmin;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mine ? 'Admin' : message.senderName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            SelectableText(message.message),
            const SizedBox(height: 6),
            Text(
              _formatTime(message.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.month}/${local.day}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
