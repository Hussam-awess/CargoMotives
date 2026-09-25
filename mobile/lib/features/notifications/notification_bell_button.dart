import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'data/notification_repository.dart';
import 'notifications_screen.dart';

/// A bell icon with an unread-count badge (AppFlow §3.1/§2.1 — the
/// notification list lives behind this icon on each role's home tab,
/// Uber/Bolt-style, rather than a dedicated bottom-nav item).
///
/// Two modes:
/// - Self-contained (default, [externalUnreadCount] omitted): fetches its
///   own unread count in `initState` and re-fetches whenever
///   [NotificationsScreen] is popped — the original behavior, still right
///   for a screen that's the only bell in its shell.
/// - Shared ([externalUnreadCount] provided): renders off that
///   `ValueNotifier` instead of owning its own count, and calls [onRead]
///   (rather than a local re-fetch) after the notifications screen closes.
///   Fixes a real bug: a shell with more than one bell (Company's
///   Dashboard + Find Jobs tabs, both kept alive in an `IndexedStack`) used
///   to have each bell fetch its own count once and never again — reading
///   a notification on one never cleared the other's badge. The shell now
///   owns one repository + one count, passed to every bell it renders.
class NotificationBellButton extends StatefulWidget {
  NotificationBellButton({
    super.key,
    NotificationRepository? repository,
    this.onTapJob,
    this.onOpenSupport,
    this.onOpenFleet,
    this.externalUnreadCount,
    this.onRead,
  }) : repository = repository ?? NotificationRepository();

  final NotificationRepository repository;
  final void Function(int jobId)? onTapJob;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onOpenFleet;

  /// When provided, this bell renders the shared count instead of fetching
  /// its own — see the class docblock's "Shared" mode.
  final ValueNotifier<int>? externalUnreadCount;

  /// Called after the notifications screen closes, only in "Shared" mode —
  /// the owning shell re-fetches once and updates [externalUnreadCount],
  /// which every bell sharing it then reflects immediately.
  final VoidCallback? onRead;

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.externalUnreadCount == null) _refreshCount();
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
        builder: (_) => NotificationsScreen(
          repository: widget.repository,
          onTapJob: widget.onTapJob,
          onOpenSupport: widget.onOpenSupport,
          onOpenFleet: widget.onOpenFleet,
        ),
      ),
    );
    if (widget.externalUnreadCount != null) {
      widget.onRead?.call();
    } else {
      _refreshCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final external = widget.externalUnreadCount;

    if (external != null) {
      return ValueListenableBuilder<int>(
        valueListenable: external,
        builder: (context, count, _) => IconButton(
          tooltip: l10n.notificationsBellTooltip,
          onPressed: _open,
          icon: Badge(label: Text('$count'), isLabelVisible: count > 0, child: const Icon(Icons.notifications_outlined)),
        ),
      );
    }

    return IconButton(
      tooltip: l10n.notificationsBellTooltip,
      onPressed: _open,
      icon: Badge(label: Text('$_unreadCount'), isLabelVisible: _unreadCount > 0, child: const Icon(Icons.notifications_outlined)),
    );
  }
}
