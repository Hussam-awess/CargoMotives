import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'data/notification_repository.dart';

/// The bell icon's destination (AppFlow §3.1) — a plain list, refreshed on
/// open/pull-to-refresh (TRD §4: notifications are explicitly not a
/// WebSocket use case). [onTapJob], when a notification carries a
/// related_job_id, is left to the caller: Customer and Company each push a
/// different job-detail screen, and this screen has no reason to know
/// which — see CustomerJobsTab/CompanyJobsScreen for how each wires it.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.repository,
    this.onTapJob,
  });

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
        actions: [
          TextButton(onPressed: _markAllRead, child: Text(l10n.markAllRead)),
        ],
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
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
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
                  Icon(
                    Icons.notifications_none,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.noNotificationsYet, textAlign: TextAlign.center),
                ],
              ),
            );
          }

          final now = DateTime.now();
          final today = <AppNotification>[];
          final earlier = <AppNotification>[];
          for (final n in notifications) {
            final local = n.createdAt.toLocal();
            (local.year == now.year &&
                        local.month == now.month &&
                        local.day == now.day
                    ? today
                    : earlier)
                .add(n);
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              children: [
                if (today.isNotEmpty) ...[
                  const _DateHeader('Today'),
                  for (final n in today)
                    _NotificationRow(notification: n, onTap: () => _onTap(n)),
                ],
                if (earlier.isNotEmpty) ...[
                  const _DateHeader('Earlier'),
                  for (final n in earlier)
                    _NotificationRow(notification: n, onTap: () => _onTap(n)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, tinted) = _iconFor(notification.type);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: notification.isUnread
              ? AppColors.infoTint
              : Colors.transparent,
          border: Border(top: BorderSide(color: AppColors.background)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tinted ? AppColors.infoTint : AppColors.background,
                border: tinted
                    ? Border.all(color: const Color(0xFFD6EBFF))
                    : null,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 16,
                color: tinted ? AppColors.ctaBlue : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _relativeTime(notification.createdAt),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (notification.isUnread)
              Container(
                margin: const EdgeInsets.only(top: 5, left: 6),
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.ctaBlue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  (IconData, bool) _iconFor(String type) => switch (type) {
    'new_message' => (Icons.chat_bubble_outline, true),
    'support_message' => (Icons.support_agent, true),
    'gps_signal_lost' => (Icons.location_off_outlined, true),
    'job_status_changed' => (Icons.local_shipping_outlined, true),
    'new_bid' || 'bid_placed' => (Icons.gavel_outlined, false),
    'bid_accepted' => (Icons.check_circle_outline, false),
    'bid_not_selected' ||
    'bid_rejected' ||
    'bid_withdrawn' => (Icons.cancel_outlined, false),
    'proof_of_delivery_submitted' ||
    'delivery_confirmed' => (Icons.inventory_2_outlined, false),
    'company_approved' || 'truck_approved' => (Icons.verified_outlined, false),
    'company_rejected' ||
    'truck_rejected' ||
    'company_flagged_duplicate' => (Icons.report_gmailerrorred_outlined, false),
    _ => (Icons.notifications_none, false),
  };

  String _relativeTime(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat('HH:mm').format(local);
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'Yesterday, ${DateFormat('HH:mm').format(local)}';
    }
    return DateFormat('d MMM, HH:mm').format(local);
  }
}
