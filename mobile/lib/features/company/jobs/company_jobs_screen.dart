import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../jobs/data/company_job_repository.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/notification_bell_button.dart';
import '../../support/support_thread_screen.dart';
import '../data/featured_repository.dart';
import '../featured/featured_screen.dart';
import '../fleet/fleet_screen.dart';
import 'company_job_detail_screen.dart';
import 'job_list_view.dart';

/// Company Jobs (UI/UX Brief §3): Open / My Bids / Active as top-level
/// tabs within the Jobs bottom-nav item — same "tabs, not separate
/// bottom-nav entries" pattern as FleetScreen's Trucks/Drivers split.
/// Featured companies additionally see a route-filter toggle on Open
/// (AppFlow §2.7) — fetched once so a non-Featured company never sees a
/// control that would silently do nothing for them. Also this role's
/// "home screen" for the notification bell icon (AppFlow §3.1's wording,
/// extended here to Company Home too — the trigger map has plenty of
/// company-directed events and no separate home-screen wording for this
/// role, so the same pattern applies).
class CompanyJobsScreen extends StatefulWidget {
  CompanyJobsScreen({
    super.key,
    CompanyJobRepository? repository,
    CompanyFeaturedRepository? featuredRepository,
    NotificationRepository? notificationRepository,
    this.unreadCountNotifier,
    this.onNotificationRead,
  }) : repository = repository ?? CompanyJobRepository(),
       featuredRepository = featuredRepository ?? CompanyFeaturedRepository(),
       notificationRepository =
           notificationRepository ?? NotificationRepository();

  final CompanyJobRepository repository;
  final CompanyFeaturedRepository featuredRepository;
  final NotificationRepository notificationRepository;

  /// See NotificationBellButton's own docblock — when provided
  /// (CompanyHomeShell owns both), this tab's bell shares the Dashboard
  /// tab's own unread count instead of fetching an independent one that
  /// never syncs with it.
  final ValueNotifier<int>? unreadCountNotifier;
  final VoidCallback? onNotificationRead;

  @override
  State<CompanyJobsScreen> createState() => _CompanyJobsScreenState();
}

class _CompanyJobsScreenState extends State<CompanyJobsScreen> {
  CompanyFeaturedStatus? _featuredStatus;
  bool _usePreferredRoutes = false;

  bool get _isFeatured => _featuredStatus?.isFeatured ?? false;

  @override
  void initState() {
    super.initState();
    _checkFeaturedStatus();
  }

  Future<void> _checkFeaturedStatus() async {
    try {
      final status = await widget.featuredRepository.status();
      if (mounted) setState(() => _featuredStatus = status);
    } catch (_) {
      // A non-Featured company (or a failed check) just doesn't see the
      // toggle/banner below — these are convenience features, not core
      // functionality.
    }
  }

  Future<void> _openCustomizeRoutes() async {
    final status = _featuredStatus;
    if (status == null) return;

    if (!status.isFeatured) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CompanyFeaturedScreen(repository: widget.featuredRepository),
        ),
      );
      _checkFeaturedStatus();
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PreferredRoutesScreen(
          repository: widget.featuredRepository,
          initialRoutes: status.preferredRoutes,
          initialHomeRegion: status.homeRegion,
        ),
      ),
    );
    if (saved == true) _checkFeaturedStatus();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      // Keyed on _isFeatured so the controller is rebuilt fresh (rather
      // than asserting on a length mismatch) the moment the Featured
      // check resolves true and the 4th tab appears.
      key: ValueKey(_isFeatured),
      length: _isFeatured ? 4 : 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jobs'),
          actions: [
            NotificationBellButton(
              repository: widget.notificationRepository,
              onTapJob: (jobId) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CompanyJobDetailScreen(jobId: jobId),
                ),
              ),
              onOpenSupport: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => SupportThreadScreen())),
              onOpenFleet: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => FleetScreen())),
              externalUnreadCount: widget.unreadCountNotifier,
              onRead: widget.onNotificationRead,
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Open'),
              const Tab(text: 'My Bids'),
              const Tab(text: 'Active'),
              if (_isFeatured) const Tab(text: 'Return Loads'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                if (_featuredStatus != null)
                  _CustomizeRoutesBanner(
                    status: _featuredStatus!,
                    onTap: _openCustomizeRoutes,
                  ),
                if (_isFeatured)
                  SwitchListTile(
                    title: const Text('My preferred routes only'),
                    value: _usePreferredRoutes,
                    onChanged: (value) =>
                        setState(() => _usePreferredRoutes = value),
                  ),
                Expanded(
                  child: JobListView(
                    key: ValueKey(_usePreferredRoutes),
                    loader: () => widget.repository.open(
                      usePreferredRoutes: _usePreferredRoutes,
                    ),
                    emptyMessage: _usePreferredRoutes
                        ? 'No open jobs on your preferred routes right now.'
                        : 'No open jobs right now.',
                    showCustomerTrustSignal: _isFeatured,
                  ),
                ),
              ],
            ),
            JobListView(
              loader: widget.repository.myBids,
              emptyMessage: "You haven't placed any bids yet.",
            ),
            JobListView(
              loader: widget.repository.active,
              emptyMessage: 'No active jobs yet.',
            ),
            if (_isFeatured)
              JobListView(
                loader: widget.repository.returnLoads,
                emptyMessage: 'No return loads near your current jobs yet.',
              ),
          ],
        ),
      ),
    );
  }
}

/// A prominent call-to-action above the Open Jobs feed — the same
/// preferred-routes filter (AppFlow §2.7) already lived one tap deep in
/// Settings/Featured, easy to miss; this puts "customize your route to
/// see jobs heading your way" where a company actually looks first. Shown
/// to every company, Featured or not: a non-Featured company sees an
/// upsell into Featured instead of the routes editor, so the feature stays
/// discoverable even before it's unlocked.
class _CustomizeRoutesBanner extends StatelessWidget {
  const _CustomizeRoutesBanner({required this.status, required this.onTap});

  final CompanyFeaturedStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final routeCount = status.preferredRoutes.length;
    final title = !status.isFeatured
        ? 'Go Plus to customize your routes'
        : routeCount == 0
        ? 'Customize your routes'
        : 'Showing jobs on $routeCount saved route${routeCount == 1 ? '' : 's'}';
    final subtitle = !status.isFeatured
        ? 'See jobs heading your way, without digging through every open job.'
        : routeCount == 0
        ? 'Save the lanes you run to see jobs heading your way first.'
        : 'Tap to edit your saved routes and home region.';

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.infoTint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.route_outlined, color: AppColors.ctaBluePressed),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
