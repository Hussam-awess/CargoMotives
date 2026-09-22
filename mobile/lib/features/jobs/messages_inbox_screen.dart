import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../support/data/support_message_repository.dart';
import '../support/support_thread_screen.dart';
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
  const _Conversation({
    required this.job,
    required this.counterparty,
    this.counterpartySubtitle,
    required this.counterpartyIsFeatured,
    required this.lastMessage,
  });

  final Job job;
  final String counterparty;
  final String? counterpartySubtitle;

  /// Whether the *other* participant in this thread is on Plus (Phase
  /// 3c) — derived from any message they've already sent (their
  /// sender_is_featured), so this needs no extra fetch beyond the
  /// per-job message list already loaded to find [lastMessage]. Stays
  /// false for a thread with no messages yet — nobody's spoken, so
  /// there's nothing to derive it from.
  final bool counterpartyIsFeatured;
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
    this.counterpartySubtitle,
    this.enrichJob,
    this.onOpenCounterpartyProfile,
    MessageRepository? messageRepository,
    SupportMessageRepository? supportMessageRepository,
  }) : messageRepository = messageRepository ?? MessageRepository(),
       supportMessageRepository =
           supportMessageRepository ?? SupportMessageRepository();

  final Future<List<Job>> Function() fetchJobs;
  final String Function(Job job) counterpartyLabel;

  /// A smaller second line for a thread's header once opened — the
  /// customer side uses this for the assigned driver's name, since
  /// messaging itself is with the company (see MessagesScreen's own
  /// docblock for why). Null (the company side's default) shows no
  /// subtitle at all.
  final String? Function(Job job)? counterpartySubtitle;
  final Future<Job> Function(int jobId)? enrichJob;

  /// Opens the counterparty's public profile for a given job (Phase:
  /// public profiles) — null when this role has no counterparty id to
  /// resolve for that job, in which case the thread header falls back to a
  /// plain "Messages" title.
  final VoidCallback? Function(BuildContext context, Job job)?
  onOpenCounterpartyProfile;
  final MessageRepository messageRepository;
  final SupportMessageRepository supportMessageRepository;

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
      final withCounterparty = jobs
          .where((j) => j.status != 'open' && j.status != 'cancelled')
          .toList();

      final conversations = await Future.wait(
        withCounterparty.map((job) async {
          final enriched = widget.enrichJob == null
              ? job
              : await widget.enrichJob!(job.id);
          final messages = await widget.messageRepository.forJob(job.id);
          final fromCounterparty = messages.where((m) => !m.isMine);
          return _Conversation(
            job: enriched,
            counterparty: widget.counterpartyLabel(enriched),
            counterpartySubtitle: widget.counterpartySubtitle?.call(enriched),
            counterpartyIsFeatured: fromCounterparty.isEmpty
                ? false
                : fromCounterparty.last.senderIsFeatured,
            lastMessage: messages.isEmpty ? null : messages.last,
          );
        }),
      );

      conversations.sort((a, b) {
        final aTime =
            a.lastMessage?.createdAt ?? a.job.preferredPickupWindowStart;
        final bTime =
            b.lastMessage?.createdAt ?? b.job.preferredPickupWindowStart;
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          jobId: conversation.job.id,
          counterpartyName: conversation.counterparty,
          counterpartySubtitle: conversation.counterpartySubtitle,
          onOpenCounterpartyProfile: widget.onOpenCounterpartyProfile?.call(
            context,
            conversation.job,
          ),
          repository: widget.messageRepository,
        ),
      ),
    );
    if (mounted) _load();
  }

  void _openSupport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SupportThreadScreen(repository: widget.supportMessageRepository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Column(
        children: [
          _SupportRow(onTap: _openSupport),
          Divider(height: 1, color: AppColors.background),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _conversations.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(24),
                            children: const [
                              SizedBox(height: 60),
                              Center(child: Text('No conversations yet.')),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _conversations.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: AppColors.background),
                            itemBuilder: (context, index) => _ConversationTile(
                              conversation: _conversations[index],
                              onTap: () => _open(_conversations[index]),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.brandChip,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.support_agent, color: Colors.white, size: 20),
      ),
      title: const Text(
        'Cargo Motives Support',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: const Text('Get help from our team'),
      trailing: Icon(Icons.chevron_right, color: AppColors.textTertiary),
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
    final initial = conversation.counterparty.trim().isEmpty
        ? '?'
        : conversation.counterparty.trim()[0].toUpperCase();

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.infoTint,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: 'Barlow Condensed',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ctaBlue,
          ),
        ),
      ),
      title: Text(
        conversation.counterparty,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
          color: conversation.counterpartyIsFeatured
              ? AppColors.accent
              : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        last == null ? 'No messages yet — say hello' : last.body,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isUnread ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: isUnread ? FontWeight.w600 : null,
        ),
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (last != null)
            Text(
              DateFormat('MMM d').format(last.createdAt.toLocal()),
              style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
            ),
          if (isUnread) ...[
            const SizedBox(height: 6),
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.ctaBlue,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
