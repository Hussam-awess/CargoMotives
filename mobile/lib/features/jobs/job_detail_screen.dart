import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_exception.dart';
import '../../core/realtime/job_bid_channel.dart';
import '../../core/realtime/job_location_channel.dart';
import '../../core/theme/app_theme.dart';
import 'booking_confirmation_screen.dart';
import 'data/bid_repository.dart';
import 'data/job_repository.dart';
import 'gps_status_card.dart';
import 'job_geo.dart';
import 'job_status.dart';
import 'live_gps_tracking_screen.dart';
import 'messages_screen.dart';

/// Job Detail (Customer) — AppFlow §3.3/§3.4: the job summary, its bid
/// list (Featured pinned first, live-updated per TRD §4 while this screen
/// is open), Accept Bid, and (Phase 6) a live GPS status card once a
/// truck's assigned. Restyled to the mockup's "Shipment Details" screen —
/// the timeline shown is derived live from the job's current status, not
/// a fabricated event log (this app has no per-event history endpoint).
class JobDetailScreen extends StatefulWidget {
  JobDetailScreen({
    super.key,
    required this.jobId,
    JobRepository? jobRepository,
    BidRepository? bidRepository,
    JobBidChannel? bidChannel,
    JobLocationChannel? locationChannel,
  }) : jobRepository = jobRepository ?? JobRepository(),
       bidRepository = bidRepository ?? BidRepository(),
       bidChannel = bidChannel ?? JobBidChannel(jobId: jobId),
       locationChannel = locationChannel ?? JobLocationChannel(jobId: jobId);

  final int jobId;
  final JobRepository jobRepository;
  final BidRepository bidRepository;
  final JobBidChannel bidChannel;
  final JobLocationChannel locationChannel;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job? _job;
  List<Bid> _bids = [];
  bool _isLoading = true;
  String? _loadError;
  bool _isConfirmingDelivery = false;
  bool _isReportingProblem = false;
  GpsLocation? _liveLocation;

  @override
  void initState() {
    super.initState();
    _load();
    widget.bidChannel
      ..onBidPlaced = _handleLiveBid
      ..connect();
    widget.locationChannel
      ..onLocationUpdated = _handleLiveLocation
      ..connect();
  }

  @override
  void dispose() {
    widget.bidChannel.dispose();
    widget.locationChannel.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final job = await widget.jobRepository.show(widget.jobId);
      final bids = await widget.bidRepository.forJob(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = job;
        _bids = bids;
        // A fresh REST fetch is the source of truth for where things
        // stand right now — a stale live update from before this reload
        // (or from a job that's no longer trackable) must not linger.
        _liveLocation = job.lastKnownLocation;
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load this job.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleLiveBid(Map<String, dynamic> bidJson) {
    if (!mounted) return;
    final bid = Bid.fromJson(bidJson);
    setState(() {
      // Replace if we already have it (e.g. our own optimistic refresh
      // beat the socket), otherwise prepend — Featured/priority bids still
      // get re-sorted to the top below.
      _bids = [bid, ..._bids.where((b) => b.id != bid.id)]..sort((a, b) => (b.isPriority ? 1 : 0) - (a.isPriority ? 1 : 0));
    });
  }

  void _handleLiveLocation(Map<String, dynamic> locationJson) {
    if (!mounted) return;
    setState(() => _liveLocation = GpsLocation.fromJson(locationJson));
  }

  Future<void> _accept(Bid bid) async {
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(job: _job!, bid: bid, bidRepository: widget.bidRepository),
      ),
    );
    if (confirmed == true) await _load();
  }

  Future<void> _confirmDelivery() async {
    setState(() => _isConfirmingDelivery = true);
    try {
      await widget.jobRepository.confirmDelivery(widget.jobId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isConfirmingDelivery = false);
    }
  }

  Future<void> _reportProblem() async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _ReportProblemDialog());
    if (reason == null) return;

    setState(() => _isReportingProblem = true);
    try {
      await widget.jobRepository.reportProblem(widget.jobId, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reported. Our team will review this delivery.')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isReportingProblem = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipment Details'),
        actions: [
          if (_job?.assignedCompanyName != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Messages',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessagesScreen(jobId: widget.jobId))),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _JobSummaryCard(job: _job!, liveLocation: _liveLocation),
                  if (_job!.isAssignable) ...[
                    const SizedBox(height: 16),
                    GpsStatusCard(trackingActive: _job!.gpsTrackingActive, signalStatus: _job!.gpsSignalStatus, location: _liveLocation),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveGpsTrackingScreen(job: _job!))),
                      icon: const Icon(Icons.near_me_outlined, size: 16),
                      label: const Text('Open live tracking'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const _SectionLabel('Timeline'),
                  const SizedBox(height: 4),
                  _StatusTimeline(status: _job!.status),
                  if (_job!.assignedDriverName != null) ...[
                    const SizedBox(height: 20),
                    const _SectionLabel('Transporter'),
                    const SizedBox(height: 4),
                    _TransporterCard(
                      job: _job!,
                      onChat: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessagesScreen(jobId: widget.jobId))),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const _SectionLabel('Cargo'),
                  const SizedBox(height: 4),
                  _CargoDetailsCard(job: _job!),
                  if (_job!.proofOfDelivery != null) ...[
                    const SizedBox(height: 16),
                    _ProofOfDeliveryCard(
                      proofOfDelivery: _job!.proofOfDelivery!,
                      canConfirm: _job!.isAwaitingDeliveryConfirmation,
                      isConfirming: _isConfirmingDelivery,
                      isReportingProblem: _isReportingProblem,
                      onConfirm: _confirmDelivery,
                      onReportProblem: _reportProblem,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('Bids (${_bids.length})', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (_bids.isEmpty) const Text('No bids yet.', style: TextStyle(color: AppColors.textSecondary)),
                  for (final bid in _bids) ...[
                    _BidCard(bid: bid, canAccept: _job!.isOpen, onAccept: () => _accept(bid)),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textLabel, letterSpacing: 0.7),
    );
  }
}

class _JobSummaryCard extends StatelessWidget {
  const _JobSummaryCard({required this.job, required this.liveLocation});

  final Job job;
  final GpsLocation? liveLocation;

  @override
  Widget build(BuildContext context) {
    final distance = (job.pickupLat != null && job.pickupLng != null && job.dropoffLat != null && job.dropoffLng != null)
        ? kmBetween(job.pickupLat!, job.pickupLng!, job.dropoffLat!, job.dropoffLng!)
        : null;
    final remaining = (liveLocation != null && job.dropoffLat != null && job.dropoffLng != null)
        ? kmBetween(liveLocation!.lat, liveLocation!.lng, job.dropoffLat!, job.dropoffLng!)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CM-${job.id.toString().padLeft(4, '0')}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.lightBlue),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.lightBlue),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      jobStatusLabel(job.status),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${job.pickupAddress} → ${job.dropoffAddress}',
            style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          if (distance != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                padding: const EdgeInsets.only(top: 13),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.13))),
                ),
                child: Row(
                  children: [
                    _SummaryStat(label: 'Distance', value: '${distance.toStringAsFixed(0)} km'),
                    if (remaining != null) ...[
                      const SizedBox(width: 20),
                      _SummaryStat(label: 'Remaining', value: '${remaining.toStringAsFixed(0)} km'),
                    ],
                    if (job.agreedPrice != null) ...[
                      const SizedBox(width: 20),
                      _SummaryStat(label: 'Price', value: '${job.currency} ${job.agreedPrice!.toStringAsFixed(0)}'),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.lightBlue)),
        Text(
          value,
          style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ],
    );
  }
}

const _timelineStages = ['open', 'assigned', 'picked_up', 'delivered', 'completed'];
const _timelineLabels = ['Shipment posted', 'Transporter assigned', 'Cargo picked up', 'Delivered', 'Completed'];

/// A live status ladder, not a fabricated event history — this app has no
/// per-event audit trail exposed to Customers, only the job's current
/// status, so each stage is shown as done/current/upcoming relative to
/// that one value.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final String status;

  int get _stageIndex {
    if (status == 'cancelled') return -1;
    final effective = status == 'en_route_pickup' ? 'assigned' : (status == 'in_transit' ? 'picked_up' : status);
    final index = _timelineStages.indexOf(effective);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return const Text('This shipment was cancelled.', style: TextStyle(color: AppColors.textSecondary));
    }

    final current = _stageIndex;

    return Column(
      children: [
        for (var i = 0; i < _timelineStages.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 11,
                  child: Column(
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= current ? AppColors.ctaBlue : Colors.white,
                          border: i <= current ? null : Border.all(color: const Color(0xFFD4D4D7), width: 2),
                          boxShadow: i == current ? const [BoxShadow(color: Color(0xFFDCE9F7), blurRadius: 0, spreadRadius: 4)] : null,
                        ),
                      ),
                      if (i != _timelineStages.length - 1)
                        Expanded(child: Container(width: 1.5, color: i < current ? AppColors.ctaBlue : const Color(0xFFE4E5E8))),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i == _timelineStages.length - 1 ? 0 : 18),
                    child: Text(
                      _timelineLabels[i],
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: i <= current ? AppColors.textPrimary : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TransporterCard extends StatelessWidget {
  const _TransporterCard({required this.job, required this.onChat});

  final Job job;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: const Icon(Icons.local_shipping_outlined, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.assignedDriverName ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                  [
                    if (job.assignedCompanyName != null) job.assignedCompanyName!,
                    if (job.assignedTruckRegistration != null) job.assignedTruckRegistration!,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onChat,
            borderRadius: BorderRadius.circular(7),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _CargoDetailsCard extends StatelessWidget {
  const _CargoDetailsCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Type', '${job.containerType} · ${job.containerSize}'),
      if (job.approxWeightTons != null) ('Weight', '${job.approxWeightTons!.toStringAsFixed(0)} tons'),
      if (job.cargoDescription != null && job.cargoDescription!.isNotEmpty) ('Description', job.cargoDescription!),
      ('Pickup window', DateFormat('d MMM, HH:mm').format(job.preferredPickupWindowStart)),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: i == rows.length - 1
                  ? null
                  : const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.background)),
                    ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(rows[i].$1, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
                  Flexible(
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// UI/UX Brief §5.1: company name + verification checkmark, truck count,
/// rating — the trust line — plus a calm GPS status dot/label, price large
/// and clear, a simple Accept button. Featured/priority bids get a small
/// text label, not a heavy visual treatment (per the brief's "GPS is a
/// badge, not a gate" / "one clean design system" direction).
class _BidCard extends StatelessWidget {
  const _BidCard({required this.bid, required this.canAccept, required this.onAccept});

  final Bid bid;
  final bool canAccept;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final company = bid.company;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bid.isPriority) ...[
            const Text(
              'FEATURED',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: company.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      if (company.verified)
                        const TextSpan(
                          text: '  ✓',
                          style: TextStyle(color: AppColors.statusLive),
                        ),
                    ],
                  ),
                ),
              ),
              Text(
                'TZS ${bid.price.toStringAsFixed(0)}',
                style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${company.truckCount} verified trucks', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: company.gpsAvailable ? AppColors.statusLive : AppColors.statusIdle,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                company.gpsAvailable ? 'Live GPS Available' : 'GPS Tracking Not Available',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                company.rating != null ? '⭐ ${company.rating!.toStringAsFixed(1)}' : 'New',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (bid.note != null && bid.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(bid.note!, style: const TextStyle(fontSize: 13)),
          ],
          if (canAccept && bid.status == 'pending') ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
              child: const Text('Accept'),
            ),
          ] else if (bid.status != 'pending')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(bid.status, style: const TextStyle(color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }
}

/// AppFlow §3.5: the driver's submitted proof — photos, optional recipient
/// name/notes — plus Confirm Receipt while the job is still 'delivered'
/// (not yet 'completed'), or its alternative, Report a Problem (raises a
/// Dispute, JobController::reportProblem()). Once confirmed, this just
/// shows the same information read-only (confirmedByCustomerAt is set).
class _ProofOfDeliveryCard extends StatelessWidget {
  const _ProofOfDeliveryCard({
    required this.proofOfDelivery,
    required this.canConfirm,
    required this.isConfirming,
    required this.isReportingProblem,
    required this.onConfirm,
    required this.onReportProblem,
  });

  final ProofOfDelivery proofOfDelivery;
  final bool canConfirm;
  final bool isConfirming;
  final bool isReportingProblem;
  final VoidCallback onConfirm;
  final VoidCallback onReportProblem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Proof of delivery'),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: proofOfDelivery.photoUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  proofOfDelivery.photoUrls[index],
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 100,
                    height: 100,
                    color: AppColors.background,
                    child: const Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),
          ),
          if (proofOfDelivery.recipientName != null) ...[const SizedBox(height: 12), Text('Received by: ${proofOfDelivery.recipientName}')],
          if (proofOfDelivery.notes != null && proofOfDelivery.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(proofOfDelivery.notes!),
          ],
          if (canConfirm) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isConfirming ? null : onConfirm,
                    child: isConfirming
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm Receipt'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isReportingProblem ? null : onReportProblem,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusError,
                      side: const BorderSide(color: Color(0xFFE8CFC8)),
                    ),
                    child: isReportingProblem
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Report issue'),
                  ),
                ),
              ],
            ),
          ] else if (proofOfDelivery.confirmedByCustomerAt != null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Confirmed',
                style: TextStyle(color: AppColors.statusLive, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportProblemDialog extends StatefulWidget {
  const _ReportProblemDialog();

  @override
  State<_ReportProblemDialog> createState() => _ReportProblemDialogState();
}

class _ReportProblemDialogState extends State<_ReportProblemDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.length < 10) {
      setState(() => _error = 'Please describe the issue in at least 10 characters.');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report an issue'),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        autofocus: true,
        decoration: InputDecoration(hintText: 'What went wrong with this delivery?', errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Submit')),
      ],
    );
  }
}
