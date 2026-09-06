import 'package:flutter/material.dart';

import '../../core/auth/session_store.dart';
import '../../shared/widgets/coming_soon_screen.dart';
import '../auth/data/auth_repository.dart';
import '../jobs/data/company_job_repository.dart';
import 'company_profile_tab.dart';
import 'data/company_repository.dart';
import 'data/driver_repository.dart';
import 'data/truck_repository.dart';
import 'fleet/fleet_screen.dart';
import 'jobs/company_jobs_screen.dart';

/// Company Home (UI/UX Brief §3): Jobs / Fleet / Earnings / Profile — 4
/// bottom-nav items, matching the brief's "3-4 items, not 6" rule. Jobs
/// and Fleet have real functionality as of Phase 4; Earnings (Phase 7)
/// remains a placeholder until that phase lands.
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
    AuthRepository? authRepository,
    SessionStore? sessionStore,
  }) : truckRepository = truckRepository ?? TruckRepository(),
       driverRepository = driverRepository ?? DriverRepository(),
       companyRepository = companyRepository ?? CompanyRepository(),
       companyJobRepository = companyJobRepository ?? CompanyJobRepository(),
       authRepository = authRepository ?? AuthRepository(),
       sessionStore = sessionStore ?? SessionStore();

  final TruckRepository truckRepository;
  final DriverRepository driverRepository;
  final CompanyRepository companyRepository;
  final CompanyJobRepository companyJobRepository;
  final AuthRepository authRepository;
  final SessionStore sessionStore;

  @override
  State<CompanyHomeShell> createState() => _CompanyHomeShellState();
}

class _CompanyHomeShellState extends State<CompanyHomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      CompanyJobsScreen(repository: widget.companyJobRepository),
      FleetScreen(
        truckRepository: widget.truckRepository,
        driverRepository: widget.driverRepository,
      ),
      const ComingSoonScreen(
        title: 'Earnings',
        subtitle: 'Commission balance and payments land in Phase 7.',
      ),
      CompanyProfileTab(
        companyRepository: widget.companyRepository,
        authRepository: widget.authRepository,
        sessionStore: widget.sessionStore,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.work_outline), label: 'Jobs'),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Fleet',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
