import 'package:flutter/material.dart';

import '../../core/auth/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/data/auth_repository.dart';
import '../jobs/data/company_job_repository.dart';
import 'company_profile_tab.dart';
import 'data/commission_repository.dart';
import 'data/company_repository.dart';
import 'data/driver_repository.dart';
import 'data/featured_repository.dart';
import 'data/truck_repository.dart';
import 'earnings/earnings_screen.dart';
import 'fleet/fleet_screen.dart';
import 'jobs/company_jobs_screen.dart';

/// Company Home (UI/UX Brief §3): Jobs / Fleet / Earnings / Profile — 4
/// bottom-nav items, matching the brief's "3-4 items, not 6" rule. All
/// four have real functionality as of Phase 7.
///
/// Repositories are accepted (not just constructed internally) so this
/// whole shell — including the Fleet/Jobs tabs' network calls — is
/// testable with fakes, the same pattern as every other screen since
/// Phase 1.
class CompanyHomeShell extends StatefulWidget {
  CompanyHomeShell({
    super.key,
    TruckRepository? truckRepository,
    DriverRepository? driverRepository,
    CompanyRepository? companyRepository,
    CompanyJobRepository? companyJobRepository,
    CommissionRepository? commissionRepository,
    CompanyFeaturedRepository? featuredRepository,
    AuthRepository? authRepository,
    SessionStore? sessionStore,
  }) : truckRepository = truckRepository ?? TruckRepository(),
       driverRepository = driverRepository ?? DriverRepository(),
       companyRepository = companyRepository ?? CompanyRepository(),
       companyJobRepository = companyJobRepository ?? CompanyJobRepository(),
       commissionRepository = commissionRepository ?? CommissionRepository(),
       featuredRepository = featuredRepository ?? CompanyFeaturedRepository(),
       authRepository = authRepository ?? AuthRepository(),
       sessionStore = sessionStore ?? SessionStore();

  final TruckRepository truckRepository;
  final DriverRepository driverRepository;
  final CompanyRepository companyRepository;
  final CompanyJobRepository companyJobRepository;
  final CommissionRepository commissionRepository;
  final CompanyFeaturedRepository featuredRepository;
  final AuthRepository authRepository;
  final SessionStore sessionStore;

  @override
  State<CompanyHomeShell> createState() => _CompanyHomeShellState();
}

class _CompanyHomeShellState extends State<CompanyHomeShell> {
  int _index = 0;
  bool _isOnHold = false;

  @override
  void initState() {
    super.initState();
    _checkHoldStatus();
  }

  Future<void> _checkHoldStatus() async {
    try {
      final summary = await widget.commissionRepository.summary();
      if (mounted) setState(() => _isOnHold = summary.isOnHold);
    } catch (_) {
      // Silently skip the banner on failure — this is a proactive nicety
      // (AppFlow §2.1: "Status banners only when relevant"), not something
      // that should ever block Company Home from rendering; bidding is
      // still correctly blocked server-side regardless (BidController).
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = [
      CompanyJobsScreen(repository: widget.companyJobRepository, featuredRepository: widget.featuredRepository),
      FleetScreen(
        truckRepository: widget.truckRepository,
        driverRepository: widget.driverRepository,
      ),
      EarningsScreen(repository: widget.commissionRepository),
      CompanyProfileTab(
        companyRepository: widget.companyRepository,
        authRepository: widget.authRepository,
        sessionStore: widget.sessionStore,
      ),
    ];

    return Scaffold(
      body: Column(
        children: [
          if (_isOnHold)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.statusError,
              child: const Text(
                'Account on hold — pay your commission balance to resume bidding.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(child: IndexedStack(index: _index, children: tabs)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.work_outline), label: l10n.navJobs),
          NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            label: l10n.navFleet,
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: l10n.navEarnings,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
