import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'data/notification_repository.dart';

/// The bell icon's destination (AppFlow §3.1) — a plain list, refreshed on
/// open/pull-to-refresh (TRD §4: notifications are explicitly not a
/// WebSocket use case). [onTapJob], when a notification carries a
/// related_job_id, is left to the caller: Customer and Company each push a
/// different job-detail screen, and this screen has no reason to know
/// which — see CustomerJobsTab/CompanyJobsScreen for how each wires it.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.repository, this.onTapJob});

  final NotificationRepository repository;
  final void Function(int jobId)? onTapJob;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  void _refresh() {
    // A block body, not an arrow (`() => _future = ...`) — an arrow
    // closure's value IS the assignment's value (a Future here), and
    // Flutter's setState() explicitly rejects a callback that returns one.
    setState(() {
      _future = widget.repository.list();
    });
  }

  Future<void> _markAllRead() async {
    await widget.repository.markAllRead();
    _refresh();
  }

  Future<void> _onTap(AppNotification notification) async {
    if (notification.isUnread) {
      await widget.repository.markRead(notification.id);
    }
    if (notification.relatedJobId != null) {
      widget.onTapJob?.call(notification.relatedJobId!);
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [TextButton(onPressed: _markAllRead, child: Text(l10n.markAllRead))],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load notifications.'),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _refresh, child: const Text('Try again')),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.notifications_none, size: 48, color: Color(0xFF9E9E9E)),
                  const SizedBox(height: 16),
                  Text(l10n.noNotificationsYet, textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = notifications[index];

                return ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 10,
                    color: notification.isUnread ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  ),
                  title: Text(notification.title, style: TextStyle(fontWeight: notification.isUnread ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(notification.body),
                  onTap: () => _onTap(notification),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
