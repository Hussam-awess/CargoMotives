import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'data/notification_repository.dart';
import 'notifications_screen.dart';

/// A bell icon with an unread-count badge (AppFlow §3.1/§2.1 — the
/// notification list lives behind this icon on each role's home tab,
/// Uber/Bolt-style, rather than a dedicated bottom-nav item). Self-
/// contained like LanguageMenuButton: it fetches its own unread count in
/// initState and re-fetches whenever NotificationsScreen is popped, so a
/// parent AppBar only ever needs `actions: [NotificationBellButton(...)]`.
class NotificationBellButton extends StatefulWidget {
  NotificationBellButton({super.key, NotificationRepository? repository, this.onTapJob})
    : repository = repository ?? NotificationRepository();

  final NotificationRepository repository;
  final void Function(int jobId)? onTapJob;

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    try {
      final count = await widget.repository.unreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // Silently skip the badge on failure — this is a proactive nicety,
      // same reasoning as CompanyHomeShell's on-hold banner (AppFlow
      // §2.1: never block the home screen over it).
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(repository: widget.repository, onTapJob: widget.onTapJob),
      ),
    );
    _refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      tooltip: l10n.notificationsBellTooltip,
      onPressed: _open,
      icon: Badge(
        label: Text('$_unreadCount'),
        isLabelVisible: _unreadCount > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
