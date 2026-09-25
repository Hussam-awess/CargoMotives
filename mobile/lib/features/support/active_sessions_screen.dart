import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/data/auth_repository.dart';

/// Settings > Active sessions (both roles): every device signed in to this
/// account, with a way to sign any other one out — a lost phone, or a
/// device the user doesn't recognize. The current device can't be signed
/// out from here (that's what Log out is for).
class ActiveSessionsScreen extends StatefulWidget {
  ActiveSessionsScreen({super.key, AuthRepository? authRepository})
    : authRepository = authRepository ?? AuthRepository();

  final AuthRepository authRepository;

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  List<ActiveSession>? _sessions;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isRevoking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final sessions = await widget.authRepository.sessions();
      if (mounted) setState(() => _sessions = sessions);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    setState(() => _isRevoking = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isRevoking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessions = _sessions ?? const <ActiveSession>[];
    final hasOthers = sessions.any((s) => !s.isCurrent);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.activeSessionsLabel)),
      body: _isLoading && _sessions == null
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.couldNotLoadSessions),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: Text(l10n.tryAgainLabel)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  for (final session in sessions)
                    _SessionTile(
                      session: session,
                      onSignOut: session.isCurrent || _isRevoking
                          ? null
                          : () => _run(
                              () => widget.authRepository.revokeSession(session.id),
                              l10n.signedOutDeviceMessage,
                            ),
                    ),
                  const SizedBox(height: 16),
                  if (hasOthers)
                    OutlinedButton(
                      onPressed: _isRevoking
                          ? null
                          : () => _run(widget.authRepository.revokeOtherSessions, l10n.signedOutOtherDevicesMessage),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.statusError,
                        side: BorderSide(color: AppColors.dangerBorder),
                      ),
                      child: Text(l10n.signOutOtherDevicesLabel),
                    )
                  else
                    Text(l10n.noOtherSessionsMessage, style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onSignOut});

  final ActiveSession session;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final format = DateFormat('d MMM yyyy, HH:mm');
    final subtitle = session.lastUsedAt != null
        ? l10n.lastActiveLabel(format.format(session.lastUsedAt!.toLocal()))
        : session.createdAt != null
        ? l10n.signedInLabel(format.format(session.createdAt!.toLocal()))
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            session.deviceName == 'Web browser' ? Icons.language : Icons.smartphone,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(session.deviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    if (session.isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.infoTint,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(l10n.thisDeviceLabel, style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (!session.isCurrent) TextButton(onPressed: onSignOut, child: Text(l10n.signOutLabel)),
        ],
      ),
    );
  }
}
