import 'package:flutter/material.dart';

import '../../core/auth/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../auth/data/auth_repository.dart';
import '../jobs/data/company_job_repository.dart';
import 'company_home_shell.dart';
import 'company_verification_screen.dart';
import 'data/company_repository.dart';
import 'data/driver_repository.dart';
import 'data/featured_repository.dart';
import 'data/truck_repository.dart';

/// The single entry point for every Transporter Company session (both the
/// Splash screen's "resume session" path and the OTP screen's "just
/// verified" path land here) — fetches the company's current verification
/// status and shows exactly one of: the verification form (none submitted,
/// or rejected), a pending-review screen, or Company Home. Keeping this
/// branching in one place means Splash and OTP don't need to duplicate it.
///
/// Every repository CompanyHomeShell (and its Fleet tab) eventually needs
/// is accepted here too and forwarded straight through — not because this
/// widget uses them itself, but so a test exercising the full "approved"
/// path can inject fakes end-to-end instead of falling through to real
/// network calls three widgets deep.
class CompanyHomeGate extends StatefulWidget {
  CompanyHomeGate({
    super.key,
    CompanyRepository? repository,
    TruckRepository? truckRepository,
    DriverRepository? driverRepository,
    CompanyJobRepository? companyJobRepository,
    CompanyFeaturedRepository? featuredRepository,
    AuthRepository? authRepository,
    SessionStore? sessionStore,
  }) : repository = repository ?? CompanyRepository(),
       truckRepository = truckRepository ?? TruckRepository(),
       driverRepository = driverRepository ?? DriverRepository(),
       companyJobRepository = companyJobRepository ?? CompanyJobRepository(),
       featuredRepository = featuredRepository ?? CompanyFeaturedRepository(),
       authRepository = authRepository ?? AuthRepository(),
       sessionStore = sessionStore ?? SessionStore();

  final CompanyRepository repository;
  final TruckRepository truckRepository;
  final DriverRepository driverRepository;
  final CompanyJobRepository companyJobRepository;
  final CompanyFeaturedRepository featuredRepository;
  final AuthRepository authRepository;
  final SessionStore sessionStore;

  @override
  State<CompanyHomeGate> createState() => _CompanyHomeGateState();
}

class _CompanyHomeGateState extends State<CompanyHomeGate> {
  late Future<CompanyVerification?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getStatus();
  }

  void _refresh() {
    // Block body, not `=> setState(() => _future = ...)`: that arrow form
    // makes the closure's return value the assignment's value (the Future
    // itself), and Flutter explicitly asserts against setState() callbacks
    // that return a Future — a real, if easy-to-miss, gotcha found by the
    // widget test that actually taps "Check again" rather than just
    // asserting on first-render state.
    setState(() {
      _future = widget.repository.getStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CompanyVerification?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load your verification status.'),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _refresh, child: const Text('Try again')),
                  ],
                ),
              ),
            ),
          );
        }

        final verification = snapshot.data;

        if (verification == null || verification.isRejected) {
          return CompanyVerificationScreen(repository: widget.repository, rejectedReason: verification?.rejectedReason);
        }

        if (verification.isUnderReview) {
          return _PendingReviewScreen(verification: verification, onRefresh: _refresh);
        }

        return CompanyHomeShell(
          companyName: verification.companyName,
          truckRepository: widget.truckRepository,
          driverRepository: widget.driverRepository,
          companyRepository: widget.repository,
          companyJobRepository: widget.companyJobRepository,
          featuredRepository: widget.featuredRepository,
          authRepository: widget.authRepository,
          sessionStore: widget.sessionStore,
        );
      },
    );
  }
}

/// "Pending Verification (browse-only)" per AppFlow §1 — a company can see
/// this screen but nothing else is unlocked until Admin approves. Refresh
/// is manual (a "Check again" button), not polling: Admin review is a
/// deliberately unhurried, manual process, not something the TRD's
/// WebSocket scoping covers.
class _PendingReviewScreen extends StatelessWidget {
  const _PendingReviewScreen({required this.verification, required this.onRefresh});

  final CompanyVerification verification;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification pending'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_top, size: 48, color: AppColors.statusIdle),
            const SizedBox(height: 16),
            Text('${verification.companyName} is under review', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Your verification is under review. You\'ll get access to your dashboard as soon as it\'s approved.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onRefresh, child: const Text('Check again')),
          ],
        ),
      ),
    );
  }
}
