import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import 'data/job_repository.dart';
import 'data/message_repository.dart';
import 'messages_screen.dart';

/// One conversation row — a job that has (or can have) a message thread,
/// paired with its latest real message if any exist yet. Composed entirely
/// from real endpoints already in use elsewhere (the job list/detail +
/// MessagesScreen's own per-job endpoint) — there is no dedicated "inbox"
/// endpoint on the backend, so this screen builds one client-side rather
/// than fabricating conversation data.
class _Conversation {
  const _Conversation({required this.job, required this.counterparty, required this.lastMessage});

  final Job job;
  final String counterparty;
  final ChatMessage? lastMessage;
}

/// A top-level Messages inbox (mockup: "Messages") listing every job that
/// has a real counterparty to talk to, most-recently-active first. Shared
/// between Customer and Company — only [fetchJobs]/[counterpartyLabel]
/// (and, for Company, [enrichJob] to pick up the customer's name, which
/// only comes back on a single-job fetch) differ per role.
class MessagesInboxScreen extends StatefulWidget {
  MessagesInboxScreen({
    super.key,
    required this.fetchJobs,
    required this.counterpartyLabel,
    this.enrichJob,
    MessageRepository? messageRepository,
  }) : messageRepository = messageRepository ?? MessageRepository();

  final Future<List<Job>> Function() fetchJobs;
  final String Function(Job job) counterpartyLabel;
  final Future<Job> Function(int jobId)? enrichJob;
  final MessageRepository messageRepository;

  @override
  State<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends State<MessagesInboxScreen> {
  List<_Conversation> _conversations = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final jobs = await widget.fetchJobs();
      final withCounterparty = jobs.where((j) => j.status != 'open' && j.status != 'cancelled').toList();

      final conversations = await Future.wait(
        withCounterparty.map((job) async {
          final enriched = widget.enrichJob == null ? job : await widget.enrichJob!(job.id);
          final messages = await widget.messageRepository.forJob(job.id);
          return _Conversation(
            job: enriched,
            counterparty: widget.counterpartyLabel(enriched),
            lastMessage: messages.isEmpty ? null : messages.last,
          );
        }),
      );

      conversations.sort((a, b) {
        final aTime = a.lastMessage?.createdAt ?? a.job.preferredPickupWindowStart;
        final bTime = b.lastMessage?.createdAt ?? b.job.preferredPickupWindowStart;
        return bTime.compareTo(aTime);
      });

      if (!mounted) return;
      setState(() => _conversations = conversations);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load your messages.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _open(_Conversation conversation) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessagesScreen(jobId: conversation.job.id)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _conversations.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 100),
                        Center(child: Text('No conversations yet.')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _conversations.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.background),
                      itemBuilder: (context, index) =>
                          _ConversationTile(conversation: _conversations[index], onTap: () => _open(_conversations[index])),
                    ),
            ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final _Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = conversation.lastMessage;
    final isUnread = last != null && !last.isMine && last.readAt == null;
    final initial = conversation.counterparty.trim().isEmpty ? '?' : conversation.counterparty.trim()[0].toUpperCase();

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: AppColors.infoTint, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.ctaBlue),
        ),
      ),
      title: Text(
        conversation.counterparty,
        style: TextStyle(fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500, color: AppColors.textPrimary),
      ),
      subtitle: Text(
        last == null ? 'No messages yet — say hello' : last.body,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: isUnread ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: isUnread ? FontWeight.w600 : null),
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (last != null)
            Text(
              DateFormat('MMM d').format(last.createdAt.toLocal()),
              style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
            ),
          if (isUnread) ...[
            const SizedBox(height: 6),
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ctaBlue),
            ),
          ],
        ],
      ),
    );
  }
}
