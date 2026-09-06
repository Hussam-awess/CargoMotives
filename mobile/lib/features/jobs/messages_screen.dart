import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'data/message_repository.dart';

/// A job's message thread (AppFlow: "Messages opens with the company" /
/// "a Messages button") — plain REST + refresh-on-open, no live updates
/// (TRD §4 scopes WebSockets to exactly live bids and live GPS; this
/// isn't either). Shared between Customer and Company since both hit the
/// same endpoint for the same job.
class MessagesScreen extends StatefulWidget {
  MessagesScreen({super.key, required this.jobId, MessageRepository? repository}) : repository = repository ?? MessageRepository();

  final int jobId;
  final MessageRepository repository;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _bodyController = TextEditingController();
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final messages = await widget.repository.forJob(widget.jobId);
      if (mounted) setState(() => _messages = messages);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load messages.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _send() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final message = await widget.repository.send(widget.jobId, body);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
        _bodyController.clear();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send that message. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text(_loadError!), const SizedBox(height: 12), OutlinedButton(onPressed: _load, child: const Text('Try again'))],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _messages.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(24),
                            children: const [SizedBox(height: 80), Center(child: Text('No messages yet. Say hello!'))],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) => _MessageBubble(message: _messages[index]),
                          ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bodyController,
                      decoration: const InputDecoration(hintText: 'Type a message…'),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: message.isMine ? AppColors.accent : const Color(0xFFF0F1F3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(message.body, style: TextStyle(color: message.isMine ? Colors.white : Colors.black87)),
      ),
    );
  }
}
