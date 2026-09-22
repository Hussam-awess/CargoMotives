import 'package:flutter/material.dart';

import '../../core/auth/session_store.dart';
import '../../core/push/push_notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/data/auth_repository.dart';
import '../jobs/data/company_job_repository.dart';
import '../jobs/messages_inbox_screen.dart';
import '../profiles/customer_profile_screen.dart';
import 'company_home_tab.dart';
import 'company_profile_tab.dart';
import 'data/company_repository.dart';
import 'data/driver_repository.dart';
import 'data/featured_repository.dart';
import 'data/truck_repository.dart';
import 'fleet/add_truck_screen.dart';
import 'fleet/fleet_screen.dart';
import 'jobs/company_jobs_screen.dart';

/// Company Home (mockup footer): Dashboard / Find Jobs / Messages /
/// Profile — 4 persistent bottom-nav tabs, matching the mockup's actual
/// footer (Phase 10.14 — previously this shell had Jobs/Fleet/Earnings/
/// Profile). Earnings is gone entirely: the platform no longer takes a
/// commission (Phase 10.13), so there's no balance left to track. Fleet
/// management stays fully reachable — Dashboard's own "Manage fleet"
/// quick-action still opens it — it just isn't a top-level tab anymore.
///
/// Repositories are accepted (not just constructed internally) so this
/// whole shell — including the Jobs tab's network calls — is testable
/// with fakes, the same pattern as every other screen since Phase 1.
class CompanyHomeShell extends StatefulWidget {
  CompanyHomeShell({
    super.key,
    required this.companyName,
    TruckRepository? truckRepository,
    DriverRepository? driverRepository,
    CompanyRepository? companyRepository,
    CompanyJobRepository? companyJobRepository,
    CompanyFeaturedRepository? featuredRepository,
    AuthRepository? authRepository,
    SessionStore? sessionStore,
  }) : truckRepository = truckRepository ?? TruckRepository(),
       driverRepository = driverRepository ?? DriverRepository(),
       companyRepository = companyRepository ?? CompanyRepository(),
       companyJobRepository = companyJobRepository ?? CompanyJobRepository(),
       featuredRepository = featuredRepository ?? CompanyFeaturedRepository(),
       authRepository = authRepository ?? AuthRepository(),
       sessionStore = sessionStore ?? SessionStore();

  /// Already known by the time CompanyHomeGate reaches the approved branch
  /// (it's how that branch was chosen) — passed straight through rather
  /// than refetched here.
  final String companyName;
  final TruckRepository truckRepository;
  final DriverRepository driverRepository;
  final CompanyRepository companyRepository;
  final CompanyJobRepository companyJobRepository;
  final CompanyFeaturedRepository featuredRepository;
  final AuthRepository authRepository;
  final SessionStore sessionStore;

  @override
  State<CompanyHomeShell> createState() => _CompanyHomeShellState();
}

class _CompanyHomeShellState extends State<CompanyHomeShell> {
  int _index = 0;
  final _homeTabKey = GlobalKey<CompanyHomeTabState>();

  @override
  void initState() {
    super.initState();
    // Reaching this shell means a session exists, fresh or resumed,
    // either way the right moment to (re)register this device's FCM
    // token. Deferred to after the first frame — see CustomerHomeShell's
    // docblock for why requesting notification permission directly in
    // initState is a real, confirmed failure mode on Android.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService().registerDeviceToken();
    });
  }

  Future<void> _openAddTruck() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTruckScreen(repository: widget.truckRepository),
      ),
    );
    _homeTabKey.currentState?.refresh();
  }

  Future<void> _openFleet() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FleetScreen(
          truckRepository: widget.truckRepository,
          driverRepository: widget.driverRepository,
        ),
      ),
    );
    _homeTabKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = [
      CompanyHomeTab(
        key: _homeTabKey,
        companyName: widget.companyName,
        companyJobRepository: widget.companyJobRepository,
        truckRepository: widget.truckRepository,
        driverRepository: widget.driverRepository,
        featuredRepository: widget.featuredRepository,
        onFindJobs: () => setState(() => _index = 1),
        onManageFleet: _openFleet,
        onAddTruck: _openAddTruck,
      ),
      CompanyJobsScreen(
        repository: widget.companyJobRepository,
        featuredRepository: widget.featuredRepository,
      ),
      MessagesInboxScreen(
        fetchJobs: widget.companyJobRepository.active,
        enrichJob: widget.companyJobRepository.show,
        counterpartyLabel: (job) =>
            job.customerCompanyName ?? job.customerName ?? 'Customer',
        onOpenCounterpartyProfile: (context, job) => job.customerId != null
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CustomerProfileScreen(customerId: job.customerId!),
                ),
              )
            : null,
      ),
      CompanyProfileTab(
        companyRepository: widget.companyRepository,
        authRepository: widget.authRepository,
        sessionStore: widget.sessionStore,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              label: l10n.navDashboard,
            ),
            NavigationDestination(
              icon: const Icon(Icons.work_outline),
              label: l10n.navFindJobs,
            ),
            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline),
              label: l10n.navMessages,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              label: l10n.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}
