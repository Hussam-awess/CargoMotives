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

  /// Lets a company held in pending/flagged_duplicate correct and resubmit
  /// without waiting on an Admin — the backend now allows this for any
  /// non-approved status (CompanyVerificationController::submit()). Pushed
  /// rather than swapped in like the null/rejected case: the waiting
  /// screen stays underneath so cancelling (back button) needs no special
  /// handling, and either way a refresh after popping picks up whatever
  /// the status actually is now.
  Future<void> _openEditSubmission(CompanyVerification verification) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanyVerificationScreen(
          repository: widget.repository,
          rejectedReason: verification.rejectedReason,
          onSubmitted: () => Navigator.of(context).pop(),
        ),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CompanyVerification?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final verification = snapshot.data;

        if (verification == null || verification.isRejected) {
          return CompanyVerificationScreen(
            repository: widget.repository,
            rejectedReason: verification?.rejectedReason,
            // Re-fetch rather than navigate: this gate is already the
            // '/company' route, so it has to re-read the status itself to
            // swap the form out for the pending-review screen.
            onSubmitted: _refresh,
          );
        }

        if (verification.isUnderReview) {
          return _PendingReviewScreen(
            verification: verification,
            onRefresh: _refresh,
            onEdit: () => _openEditSubmission(verification),
          );
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
/// this screen but nothing else is unlocked until it clears review. Refresh
/// is manual (a "Check again" button), not polling, since a submission held
/// for an Admin (rather than a fixable auto-check note) is a deliberately
/// unhurried, manual process, not something the TRD's WebSocket scoping
/// covers.
class _PendingReviewScreen extends StatelessWidget {
  const _PendingReviewScreen({
    required this.verification,
    required this.onRefresh,
    required this.onEdit,
  });

  final CompanyVerification verification;
  final VoidCallback onRefresh;

  /// Opens the verification form again so the company can correct whatever
  /// CompanyAutoVerifier flagged and resubmit — always offered here rather
  /// than only when autoCheckNotes is non-empty, since a submission held
  /// specifically for Admin's own duplicate review (flagged_duplicate) may
  /// still need a genuine correction (a mistyped registration number) that
  /// only the company itself can make.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasNotes = verification.autoCheckNotes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification pending'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(
              Icons.hourglass_top,
              size: 48,
              color: AppColors.statusIdle,
            ),
            const SizedBox(height: 16),
            Text(
              '${verification.companyName} is under review',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasNotes
                  ? 'A few things need fixing before this can be approved.'
                  : 'Your verification is under review. You\'ll get access to your dashboard as soon as it\'s approved.',
              textAlign: TextAlign.center,
            ),
            if (hasNotes) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.statusError.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.statusError.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final note in verification.autoCheckNotes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('•  $note'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onEdit,
              child: const Text('Edit and resubmit'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRefresh,
              child: const Text('Check again'),
            ),
          ],
        ),
      ),
    );
  }
}
