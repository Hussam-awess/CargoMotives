import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../jobs/data/company_job_repository.dart';
import '../jobs/data/job_repository.dart' show Job;
import '../jobs/job_geo.dart';
import '../jobs/job_status.dart';
import '../jobs/messages_inbox_screen.dart';
import '../notifications/data/notification_repository.dart';
import '../notifications/notification_bell_button.dart';
import 'data/driver_repository.dart';
import 'data/truck_repository.dart';
import 'jobs/company_job_detail_screen.dart';

class _DashboardData {
  const _DashboardData({
    required this.activeJobs,
    required this.openBidsCount,
    required this.fleetSize,
    required this.activeDriverCount,
    required this.openLoads,
  });

  final List<Job> activeJobs;
  final int openBidsCount;
  final int fleetSize;
  final int activeDriverCount;
  final List<Job> openLoads;
}

/// Transporter Company's Home (mockup "Transporter home") — an Activity
/// summary (trips on the road, open bids, fleet size, active drivers),
/// quick actions into the other tabs, the current Active Job, and a
/// preview of open loads to bid on. Every figure comes from the
/// company's real jobs/fleet/roster — nothing here is a mockup
/// placeholder value.
class CompanyHomeTab extends StatefulWidget {
  CompanyHomeTab({
    super.key,
    required this.companyName,
    CompanyJobRepository? companyJobRepository,
    TruckRepository? truckRepository,
    DriverRepository? driverRepository,
    NotificationRepository? notificationRepository,
    required this.isOnHold,
    this.onFindJobs,
    this.onManageFleet,
    this.onEarnings,
    this.onAddTruck,
  }) : companyJobRepository = companyJobRepository ?? CompanyJobRepository(),
       truckRepository = truckRepository ?? TruckRepository(),
       driverRepository = driverRepository ?? DriverRepository(),
       notificationRepository = notificationRepository ?? NotificationRepository();

  /// The transporter_companies.company_name a company already gave during
  /// verification (CompanyHomeGate has it in hand — see CompanyHomeShell's
  /// docblock) — not User.company_name, which is a Customer-only field.
  final String companyName;
  final CompanyJobRepository companyJobRepository;
  final TruckRepository truckRepository;
  final DriverRepository driverRepository;
  final NotificationRepository notificationRepository;

  /// Owned by CompanyHomeShell (it already fetches this for the on-hold
  /// banner) — passed down rather than refetched here.
  final bool isOnHold;

  /// CompanyHomeShell owns cross-tab navigation (switching the bottom-nav
  /// IndexedStack) and the Jobs-board push — when unset (e.g. a standalone
  /// test), each action falls back to pushing its screen directly.
  final VoidCallback? onFindJobs;
  final VoidCallback? onManageFleet;
  final VoidCallback? onEarnings;
  final VoidCallback? onAddTruck;

  @override
  State<CompanyHomeTab> createState() => CompanyHomeTabState();
}

class CompanyHomeTabState extends State<CompanyHomeTab> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait([
      widget.companyJobRepository.active(),
      widget.companyJobRepository.myBids(),
      widget.truckRepository.list(),
      widget.driverRepository.list(),
      widget.companyJobRepository.open(),
    ]);

    final activeJobs = results[0] as List<Job>;
    final myBids = results[1] as List<Job>;
    final trucks = results[2] as List;
    final drivers = results[3] as List;
    final openLoads = results[4] as List<Job>;

    return _DashboardData(
      activeJobs: activeJobs,
      openBidsCount: myBids.where((j) => j.status == 'open').length,
      fleetSize: trucks.length,
      activeDriverCount: drivers.whereType<Driver>().where((d) => d.isActive).length,
      openLoads: openLoads.take(3).toList(),
    );
  }

  void refresh() {
    setState(() {
      _future = _load();
    });
  }

  void _openJob(int jobId) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompanyJobDetailScreen(jobId: jobId))).then((_) => refresh());
  }

  void _openMessages() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagesInboxScreen(
          fetchJobs: widget.companyJobRepository.active,
          enrichJob: widget.companyJobRepository.show,
          counterpartyLabel: (job) => job.customerCompanyName ?? job.customerName ?? 'Customer',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load your dashboard.'),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: refresh, child: const Text('Try again')),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async => refresh(),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _Header(
                    companyLabel: widget.companyName,
                    isOnHold: widget.isOnHold,
                    notificationRepository: widget.notificationRepository,
                    onTapJob: _openJob,
                    onMessages: _openMessages,
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ActivityCard(data: data, onEarnings: widget.onEarnings),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionButton(label: 'Find jobs', filled: true, onTap: widget.onFindJobs ?? () {}),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(label: 'Manage fleet', filled: false, onTap: widget.onManageFleet ?? () {}),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionButton(label: 'Earnings', filled: false, onTap: widget.onEarnings ?? () {}),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(label: 'Add truck', filled: false, icon: Icons.add, onTap: widget.onAddTruck ?? () {}),
                        ),
                      ],
                    ),
                  ),
                  _SectionHeader(
                    title: 'Active Job',
                    actionLabel: data.activeJobs.isEmpty ? null : 'Open',
                    onTap: data.activeJobs.isEmpty ? null : () => _openJob(data.activeJobs.first.id),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ActiveJobCard(job: data.activeJobs.isEmpty ? null : data.activeJobs.first, onTap: _openJob),
                  ),
                  _SectionHeader(title: 'Matching Loads', actionLabel: 'See all', onTap: widget.onFindJobs),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _MatchingLoads(loads: data.openLoads, onTap: _openJob),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.companyLabel,
    required this.isOnHold,
    required this.notificationRepository,
    required this.onTapJob,
    required this.onMessages,
  });

  final String companyLabel;
  final bool isOnHold;
  final NotificationRepository notificationRepository;
  final void Function(int jobId) onTapJob;
  final VoidCallback onMessages;

  @override
  Widget build(BuildContext context) {
    final initials = companyLabel.trim().isEmpty
        ? '?'
        : companyLabel.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.lightBlue),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Barlow Condensed',
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: isOnHold ? AppColors.statusError : AppColors.statusLive),
                    ),
                    const SizedBox(width: 5),
                    Text(isOnHold ? 'On hold' : 'Accepting loads', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onMessages,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 19, color: AppColors.primary),
            ),
          ),
          NotificationBellButton(repository: notificationRepository, onTapJob: onTapJob),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.data, required this.onEarnings});

  final _DashboardData data;
  final VoidCallback? onEarnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Activity', style: TextStyle(fontSize: 12.5, color: AppColors.lightBlue, letterSpacing: 0.4)),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${data.activeJobs.length}',
                            style: const TextStyle(
                              fontFamily: 'Barlow Condensed',
                              fontSize: 34,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Text('trip(s) on the road', style: TextStyle(fontSize: 13, color: AppColors.lightBlue)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: onEarnings,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Earnings', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Container(
              padding: const EdgeInsets.only(top: 13),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.13))),
              ),
              child: Row(
                children: [
                  _Stat(label: 'Open bids', value: data.openBidsCount),
                  const SizedBox(width: 22),
                  _Stat(label: 'Fleet size', value: data.fleetSize),
                  const SizedBox(width: 22),
                  _Stat(label: 'Active drivers', value: data.activeDriverCount),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.lightBlue)),
        Text(
          '$value',
          style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.filled, required this.onTap, this.icon});

  final String label;
  final bool filled;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
      child: icon == null
          ? Text(label)
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16), const SizedBox(width: 7), Text(label)]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionLabel, required this.onTap});

  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onTap,
              child: Text(
                actionLabel!,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ctaBlue),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({required this.job, required this.onTap});

  final Job? job;
  final void Function(int jobId) onTap;

  @override
  Widget build(BuildContext context) {
    final job = this.job;
    if (job == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text('No active job right now.', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return InkWell(
      onTap: () => onTap(job.id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE4E5E8)),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x0D1D2D3D), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CM-${job.id.toString().padLeft(4, '0')}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: AppColors.textSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.infoTint, borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ctaBlue),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        jobStatusLabel(job.status),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ctaBluePressed),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${job.pickupAddress} → ${job.dropoffAddress}',
              style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
            Text(
              [
                if (job.assignedDriverName != null) job.assignedDriverName!,
                if (job.assignedTruckRegistration != null) job.assignedTruckRegistration!,
              ].join(' · '),
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchingLoads extends StatelessWidget {
  const _MatchingLoads({required this.loads, required this.onTap});

  final List<Job> loads;
  final void Function(int jobId) onTap;

  @override
  Widget build(BuildContext context) {
    if (loads.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text('No open loads right now.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return Column(
      children: [
        for (final job in loads) ...[_LoadCard(job: job, onTap: () => onTap(job.id)), const SizedBox(height: 10)],
      ],
    );
  }
}

class _LoadCard extends StatelessWidget {
  const _LoadCard({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = (job.pickupLat != null && job.pickupLng != null && job.dropoffLat != null && job.dropoffLng != null)
        ? kmBetween(job.pickupLat!, job.pickupLng!, job.dropoffLat!, job.dropoffLng!)
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE4E5E8)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${job.pickupAddress} → ${job.dropoffAddress}',
              style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
            Text(
              '${job.containerType}${job.approxWeightTons != null ? ' · ${job.approxWeightTons!.toStringAsFixed(0)} t' : ''}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (distance != null) _Tag(text: '${distance.toStringAsFixed(0)} km'),
                if (distance != null) const SizedBox(width: 6),
                _Tag(text: '${job.bidsCount ?? 0} bids'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.textLabel)),
    );
  }
}
