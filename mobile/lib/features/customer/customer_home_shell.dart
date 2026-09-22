import 'package:flutter/material.dart';

import '../../core/push/push_notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../jobs/data/job_repository.dart';
import '../jobs/messages_inbox_screen.dart';
import '../profiles/transporter_profile_screen.dart';
import 'customer_jobs_tab.dart';
import 'customer_profile_tab.dart';
import 'shipments/customer_shipments_screen.dart';

/// Customer Home (mockup footer): Home / Shipments / Messages / Profile —
/// 4 persistent bottom-nav tabs, matching the mockup's actual footer
/// (Phase 10.14 — previously this shell had Jobs/Post/Profile, with
/// "Post" as a one-shot nav slot and no way to reach Shipments or
/// Messages except a secondary "See all" link). Posting a job is now
/// purely a quick-action from the Home tab's own Activity card
/// (CustomerJobsTab already owns that navigation when no onPostJob is
/// given), not a bottom-nav destination.
class CustomerHomeShell extends StatefulWidget {
  const CustomerHomeShell({super.key});

  @override
  State<CustomerHomeShell> createState() => _CustomerHomeShellState();
}

class _CustomerHomeShellState extends State<CustomerHomeShell> {
  int _index = 0;
  final _repository = JobRepository();

  @override
  void initState() {
    super.initState();
    // Reaching this shell at all means a session exists (Splash routes
    // here only after confirming one), whether from a fresh login or a
    // resumed session — either way is the right moment to (re)register
    // this device's FCM token. Deferred to after the first frame (not
    // called directly here): requesting the POST_NOTIFICATIONS permission
    // while this widget is still mid-route-transition/build can make
    // Android silently deny it without ever showing the system dialog —
    // a real, confirmed failure mode, not a hypothetical one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService().registerDeviceToken();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final tabs = [
      CustomerJobsTab(repository: _repository),
      CustomerShipmentsScreen(repository: _repository),
      MessagesInboxScreen(
        fetchJobs: _repository.list,
        counterpartyLabel: (job) => job.assignedCompanyName ?? 'Transporter',
        counterpartySubtitle: (job) => job.assignedDriverName != null
            ? 'Driver: ${job.assignedDriverName}'
            : null,
        onOpenCounterpartyProfile: (context, job) =>
            job.assignedCompanyId != null
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TransporterProfileScreen(
                    companyId: job.assignedCompanyId!,
                  ),
                ),
              )
            : null,
      ),
      CustomerProfileTab(),
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
              icon: const Icon(Icons.home_outlined),
              label: l10n.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.local_shipping_outlined),
              label: l10n.navShipments,
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
